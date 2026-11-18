#!/usr/bin/env python3
"""Drain Edge's DMI stdout FIFO via OpenOCD's Tcl socket; never halt the core."""
import argparse
import socket
import sys
import time

# One Tcl transaction batches all bytes currently available. Reads pop once in RTL.
DRAIN = '''set s [riscv dmi_read 0x74]; set text "";
if {$s & 4} {riscv dmi_write 0x74 4};
for {set i 0} {$i < (($s >> 8) & 255)} {incr i} {
 set d [riscv dmi_read 0x75];
 if {!($d & 256)} {break};
 append text [format %02x [expr {$d & 255}]];
}; format "%08x:%s" $s $text'''

def rpc(sock, command):
    sock.sendall(command.encode('ascii') + b'\x1a')
    result = bytearray()
    while not result.endswith(b'\x1a'):
        chunk = sock.recv(4096)
        if not chunk:
            raise RuntimeError('OpenOCD disconnected')
        result.extend(chunk)
    return result[:-1].decode('ascii').strip()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--host', default='127.0.0.1')
    p.add_argument('--port', type=int, default=6666)
    p.add_argument('--interval', type=float, default=0.02)
    p.add_argument('--once', action='store_true', help='Drain one snapshot and exit')
    a = p.parse_args()
    if a.interval < 0:
        p.error('--interval must be nonnegative')
    with socket.create_connection((a.host, a.port), timeout=10) as sock:
        while True:
            result = rpc(sock, DRAIN)
            try:
                status_text, payload = result.split(':', 1)
                status = int(status_text, 16)
                data = bytes.fromhex(payload)
            except ValueError as exc:
                raise RuntimeError(f'Unexpected OpenOCD console response: {result}') from exc
            if status >> 16 == 0:
                raise RuntimeError('Console unavailable: select the Edge target and activate its DM')
            if status & 4:
                print('Edge stdout overflow: new characters were dropped', file=sys.stderr)
            sys.stdout.buffer.write(data)
            sys.stdout.buffer.flush()
            if a.once:
                break
            if not data:
                time.sleep(a.interval)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (OSError, RuntimeError) as exc:
        print(f'console: {exc}', file=sys.stderr)
        sys.exit(1)
