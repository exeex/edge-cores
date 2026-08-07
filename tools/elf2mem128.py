#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path

PT_LOAD = 1

def parse_int(text):
    return int(text, 0)

def read_elf_load_segments(path):
    data = Path(path).read_bytes()
    if data[:4] != b"\x7fELF":
        raise SystemExit(f"{path}: not an ELF file")

    elf_class = data[4]
    endian = data[5]
    if endian == 1:
        pfx = "<"
    elif endian == 2:
        pfx = ">"
    else:
        raise SystemExit("unsupported ELF endian")

    if elf_class == 2:
        ehdr_fmt = pfx + "16sHHIQQQIHHHHHH"
        phdr_fmt = pfx + "IIQQQQQQ"
        (_, _, _, _, _, e_phoff, _, _, _, e_phentsize, e_phnum, _, _, _) = struct.unpack_from(ehdr_fmt, data, 0)
    elif elf_class == 1:
        ehdr_fmt = pfx + "16sHHIIIIIHHHHHH"
        phdr_fmt = pfx + "IIIIIIII"
        (_, _, _, _, _, e_phoff, _, _, _, e_phentsize, e_phnum, _, _, _) = struct.unpack_from(ehdr_fmt, data, 0)
    else:
        raise SystemExit("unsupported ELF class")

    for idx in range(e_phnum):
        off = e_phoff + idx * e_phentsize
        if elf_class == 2:
            p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = struct.unpack_from(phdr_fmt, data, off)
        else:
            p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_flags, p_align = struct.unpack_from(phdr_fmt, data, off)
        if p_type != PT_LOAD or p_memsz == 0:
            continue
        yield {
            "addr": p_paddr if p_paddr != 0 else p_vaddr,
            "data": data[p_offset:p_offset + p_filesz],
            "memsz": p_memsz,
        }

def main():
    ap = argparse.ArgumentParser(description="Convert ELF PT_LOAD segments into StarEdge 128-bit SRAM image.")
    ap.add_argument("elf")
    ap.add_argument("-o", "--output", default="payload.memh")
    ap.add_argument("--base", type=parse_int, default=0, help="physical base address represented by image row 0")
    ap.add_argument("--size", type=parse_int, default=16 * 1024 * 1024, help="image address window size")
    ap.add_argument("--words-file", default=None, help="optional file to write the required +mem128_words value")
    ap.add_argument("--mem64-output", default=None, help="optional 64-bit little-endian data-side image")
    ap.add_argument("--mem64-words-file", default=None, help="optional file to write 64-bit image word count")
    args = ap.parse_args()

    image = bytearray(args.size)
    max_written = 0
    loaded = 0

    for seg in read_elf_load_segments(args.elf):
        start = seg["addr"] - args.base
        end = start + seg["memsz"]
        if start < 0 or end > args.size:
            raise SystemExit(f"PT_LOAD segment 0x{seg['addr']:x}..0x{seg['addr'] + seg['memsz']:x} outside image window")
        image[start:start + len(seg["data"])] = seg["data"]
        max_written = max(max_written, end)
        loaded += 1

    if loaded == 0:
        raise SystemExit("ELF contains no PT_LOAD segments")

    words = (max_written + 15) // 16
    with open(args.output, "w") as fh:
        for idx in range(words):
            chunk = image[idx * 16:(idx + 1) * 16]
            fh.write("".join(f"{byte:02x}" for byte in reversed(chunk)))
            fh.write("\n")

    if args.words_file:
        Path(args.words_file).write_text(f"{words}\n")

    if args.mem64_output:
        mem64_words = (max_written + 7) // 8
        with open(args.mem64_output, "w") as fh:
            for idx in range(mem64_words):
                chunk = image[idx * 8:(idx + 1) * 8]
                fh.write("".join(f"{byte:02x}" for byte in reversed(chunk)))
                fh.write("\n")
        if args.mem64_words_file:
            Path(args.mem64_words_file).write_text(f"{mem64_words}\n")
        print(f"wrote {args.mem64_output}: {mem64_words} 64-bit words")

    print(f"wrote {args.output}: {words} 128-bit words")
    print(f"run with: +mem128={args.output} +mem128_words={words}")

if __name__ == "__main__":
    main()
