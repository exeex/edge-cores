#!/usr/bin/env python3
"""Build the demo, or own a simulator/OpenOCD/console session until Ctrl-C."""
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'build/jtag-hello'
TESTS = HERE
SIM = OUT / 'sim/Vjtag_tb'
CONTROL = OUT / 'control.sock'


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, str(HERE / 'build_sim.py'),
                    '--build-dir', str(OUT / 'sim')], check=True)
    clang = os.environ.get('CLANG') or '/opt/homebrew/opt/llvm/bin/clang'
    if not Path(clang).is_file():
        clang = shutil.which(clang) or shutil.which('clang')
    if not clang:
        raise RuntimeError('Install RISC-V-capable clang/LLD or set CLANG')
    subprocess.run([
        clang, '--target=riscv32-unknown-elf', '-march=rv32im_zicsr',
        '-mabi=ilp32', '-g', '-gdwarf-4', '-O0', '-ffreestanding',
        '-fno-stack-protector', '-fno-pic', '-msmall-data-limit=0',
        '-nostdlib', '-fuse-ld=lld', '-Wl,--no-relax',
        '-Wl,-T,' + str(HERE / 'link.ld'), str(HERE / 'start.S'),
        str(HERE / 'main.c'), '-o', str(OUT / 'hello.elf'),
    ], check=True)
    print('Built ' + str(OUT / 'hello.elf'), flush=True)


def serve():
    if not SIM.is_file():
        raise RuntimeError('Missing JTAG simulator: ' + str(SIM))
    # Refuse occupied ports rather than connecting to someone else's target.
    for port in (9824, 3333, 6666):
        with socket.socket() as probe:
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind(('127.0.0.1', port))
    OUT.mkdir(parents=True, exist_ok=True)
    children = []
    control = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    peer = None
    def stop(_signum, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, stop)
    print('EDGE_JTAG_STARTING', flush=True)
    try:
        CONTROL.unlink(missing_ok=True)
        control.bind(str(CONTROL))
        CONTROL.chmod(0o600)
        control.listen(1)
        control.settimeout(0.2)
        with (OUT / 'simulator.log').open('w') as simlog, (OUT / 'openocd.log').open('w') as ocdlog:
            sim = subprocess.Popen([str(SIM), '9824'], stdout=simlog, stderr=subprocess.STDOUT)
            children.append(sim)
            wait_log(OUT / 'simulator.log', 'REMOTE_BITBANG_PORT=', sim)
            ocd = subprocess.Popen([
                shutil.which('openocd') or '/opt/homebrew/bin/openocd',
                '-c', 'telnet_port disabled', '-f', str(TESTS / 'openocd.cfg'),
                '-c', 'echo EDGE_OPENOCD_READY',
            ], stdout=ocdlog, stderr=subprocess.STDOUT)
            children.append(ocd)
            wait_log(OUT / 'openocd.log', 'EDGE_OPENOCD_READY', ocd)
            console = subprocess.Popen([sys.executable, str(TESTS / 'console.py')])
            children.append(console)
            print('EDGE_JTAG_READY', flush=True)
            print('Target stdout appears here. Stopping debug also stops these servers.', flush=True)
            while True:
                if any(child.poll() is not None for child in children):
                    raise RuntimeError('A debug service exited; inspect build/jtag-hello/*.log')
                try:
                    peer, _ = control.accept()
                except socket.timeout:
                    continue
                peer.settimeout(2)
                try:
                    request = peer.recv(16)
                except socket.timeout:
                    request = b''
                if request == b'stop\n':
                    break
                peer.close()
                peer = None
    finally:
        for child in reversed(children):
            if child.poll() is None:
                child.terminate()
        for child in reversed(children):
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        control.close()
        CONTROL.unlink(missing_ok=True)
        if peer is not None:
            try:
                peer.sendall(b'stopped\n')
            except OSError:
                pass
            peer.close()
        print('EDGE_JTAG_STOPPED', flush=True)


def stop_services():
    # Ask this workspace's supervisor to reap its own children, not arbitrary PIDs.
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(15)
        try:
            client.connect(str(CONTROL))
        except (FileNotFoundError, ConnectionRefusedError):
            print('No managed JTAG session is running.', flush=True)
            return
        client.sendall(b'stop\n')
        response = client.makefile('rb').readline()
        if response != b'stopped\n':
            raise RuntimeError('JTAG supervisor disconnected before confirming cleanup')
    print('Stopped Verilator, OpenOCD and console reader.', flush=True)


def wait_log(path, marker, child):
    deadline = time.monotonic() + 20
    while marker not in path.read_text():
        if child.poll() is not None or time.monotonic() >= deadline:
            raise RuntimeError('Service failed to start:\n' + path.read_text())
        time.sleep(0.05)


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['build']:
            build()
        elif sys.argv[1:] == ['serve']:
            serve()
        elif sys.argv[1:] == ['stop']:
            stop_services()
        else:
            raise RuntimeError('Usage: debug.py build | serve | stop')
    except KeyboardInterrupt:
        pass
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
