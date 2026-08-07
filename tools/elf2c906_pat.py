#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path

PT_LOAD = 1

def segments(path):
    data = Path(path).read_bytes()
    if data[:4] != b"\x7fELF" or data[4] != 2:
        raise SystemExit(f"{path}: expected ELF64")
    pfx = "<" if data[5] == 1 else ">"
    hdr = struct.unpack_from(pfx + "16sHHIQQQIHHHHHH", data)
    phoff, entsize, count = hdr[5], hdr[9], hdr[10]
    for idx in range(count):
        fields = struct.unpack_from(pfx + "IIQQQQQQ", data, phoff + idx * entsize)
        p_type, _, offset, vaddr, _, filesz, memsz, _ = fields
        if p_type == PT_LOAD and memsz:
            yield vaddr, data[offset:offset + filesz] + bytes(memsz - filesz)

def write_pat(path, image):
    with open(path, "w") as output:
        for pos in range(0, len(image), 4):
            output.write("".join(f"{byte:02x}" for byte in image[pos:pos + 4].ljust(4, b"\0")) + "\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("elf")
    parser.add_argument("--inst-output", default="inst.pat")
    parser.add_argument("--data-output", default="data.pat")
    args = parser.parse_args()
    images = [bytearray(0x40000), bytearray(0x40000)]
    used = [0, 0]
    for address, payload in segments(args.elf):
        slot = 0 if address < 0x40000 else 1
        base = slot * 0x40000
        start, end = address - base, address - base + len(payload)
        if start < 0 or end > 0x40000:
            raise SystemExit(f"segment 0x{address:x} outside C906 memory windows")
        images[slot][start:end] = payload
        used[slot] = max(used[slot], end)
    write_pat(args.inst_output, images[0][:max(4, (used[0] + 3) & ~3)])
    write_pat(args.data_output, images[1][:max(4, (used[1] + 3) & ~3)])

if __name__ == "__main__":
    main()
