#!/usr/bin/env python3
"""Exercise the real cppdbg -> GDB -> OpenOCD -> JTAG RTL path and cleanup."""
from pathlib import Path
import socket
import os
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / 'build/jtag-hello'
DEBUG = [sys.executable, str(HERE / 'debug.py')]


def session(check_debugger):
    log_path = OUT / ('session.log' if check_debugger else 'restart.log')
    with log_path.open('w') as log:
        server = subprocess.Popen(DEBUG + ['serve'], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 30
            while 'EDGE_JTAG_READY' not in log_path.read_text():
                if server.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError(log_path.read_text())
                time.sleep(0.05)
            if check_debugger:
                with (OUT / 'dap-check.log').open('w') as daplog:
                    subprocess.run([sys.executable, str(HERE / 'check_dap.py')], cwd=ROOT,
                                   stdout=daplog, stderr=subprocess.STDOUT, check=True, timeout=180)
                deadline = time.monotonic() + 10
                while 'Hello world from Edge32!\n' not in log_path.read_text():
                    if time.monotonic() > deadline:
                        raise RuntimeError('Missing JTAG console greeting')
                    time.sleep(0.05)
        finally:
            try:
                if server.poll() is None:
                    subprocess.run(DEBUG + ['stop'], cwd=ROOT, check=True, timeout=20)
            finally:
                if server.poll() is None:
                    server.terminate()
                server.wait(timeout=10)
        if server.returncode != 0:
            raise RuntimeError(log_path.read_text())
    if (OUT / 'control.sock').exists():
        raise RuntimeError('Supervisor socket was not removed')
    for port in (9824, 3333, 6666):
        with socket.socket() as probe:
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind(('127.0.0.1', port))


if __name__ == '__main__':
    subprocess.run(DEBUG + ['build'], cwd=ROOT, check=True)
    compiler = os.environ.get('CLANG') or shutil.which('clang')
    if 'CLANG' not in os.environ and Path('/opt/homebrew/opt/llvm/bin/clang').is_file():
        compiler = '/opt/homebrew/opt/llvm/bin/clang'
    subprocess.run([compiler, '--target=riscv32-unknown-elf', '-march=rv32im',
                    '-mabi=ilp32', '-g', '-nostdlib', '-fuse-ld=lld', '-Wl,--no-relax',
                    '-Wl,-T,' + str(HERE / 'tests/jtag_boot.ld'),
                    str(HERE / 'tests/jtag_boot.S'), '-o', str(OUT / 'jtag_boot.elf')], check=True)
    subprocess.run([sys.executable, str(HERE / 'tests/check_transport.py'),
                    '--sim', str(OUT / 'sim/Vjtag_tb'), '--build-dir', str(OUT)],
                   cwd=ROOT, check=True, timeout=180)
    session(True)
    subprocess.run(DEBUG + ['stop'], cwd=ROOT, check=True)  # idempotent cleanup
    session(False)
    (OUT / 'test.report').write_text('JTAG HELLO PASS: transport, coherence, reset, DAP, GDB, console, cleanup, restart\n')
    print((OUT / 'test.report').read_text(), end='')
