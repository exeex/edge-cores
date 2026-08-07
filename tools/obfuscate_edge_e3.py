#!/usr/bin/env python3
"""Build a single-file, symbol-obfuscated edge-e3 RTL release."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_$]*")
TOKEN_RE = re.compile(
    r"(?P<block>/\*.*?\*/)|(?P<line>//[^\r\n]*)|"
    r'(?P<string>"(?:\\.|[^"\\])*")|(?P<escaped>\\\S+)|'
    r"(?P<number>(?:\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d[\d_]*)?|"
    r"\d*[\d_]*'[sS]?[bBoOdDhH][0-9a-fA-FxXzZ?_]+))|"
    r"(?P<system>\$[A-Za-z_][A-Za-z0-9_$]*)|(?P<ident>[A-Za-z_][A-Za-z0-9_$]*)|"
    r"(?P<other>.)",
    re.DOTALL,
)

RESERVED = set(
    """
    accept_on alias always always_comb always_ff always_latch and assert assign
    assume automatic before begin bind bins binsof bit break buf bufif0 bufif1
    byte case casex casez cell chandle checker class clocking cmos config const
    constraint context continue cover covergroup coverpoint cross deassign
    default defparam design disable dist do edge else end endcase endchecker endclass
    endclocking endconfig endfunction endgenerate endgroup endinterface endmodule
    endpackage endprimitive endprogram endproperty endspecify endsequence endtable
    endtask enum event eventually expect export extends extern final first_match
    for force foreach forever fork forkjoin function generate genvar global highz0
    highz1 if iff ifnone ignore_bins illegal_bins implements implies import incdir
    include initial inout input inside instance int integer interconnect interface
    intersect join join_any join_none large let liblist library local localparam
    logic longint macromodule matches medium modport module nand negedge nettype
    new nexttime nmos none nor noshowcancelled not notif0 notif1 null or output
    package packed parameter pmos posedge primitive priority program property
    protected pull0 pull1 pulldown pullup pure rand randc randcase randsequence
    rcmos real realtime ref reg reject_on release repeat restrict return rnmos
    rpmos rtran rtranif0 rtranif1 s scalared sequence shortint shortreal signed
    small solve specify specparam static string strong strong0 strong1 struct
    super supply0 supply1 table tagged task this throughout time timeprecision
    timeunit tran tranif0 tranif1 tri tri0 tri1 triand trior trireg type typedef
    union unique unique0 unsigned until until_with untyped use us uwire var
    vectored virtual void wait wait_order wand weak weak0 weak1 while wildcard
    wire with within wor xnor xor fs ps ns ms
    begin_keywords celldefine default_nettype define else elsif end_keywords
    endcelldefine endif ifdef ifndef line nounconnected_drive pragma protect
    resetall timescale unconnected_drive undef undefineall
    """.split()
)

# These files are implementation models or hard-macro boundaries. They are not
# read into the semantic JSON and are emitted separately for downstream mixing.
DEFAULT_SRAM_PATTERNS = (
    r"(?:^|/)fpga_ram\.v$",
    r"(?:^|/).*spsram.*\.v$",
    r"(?:^|/).*_(?:data|tag|dirty)_array(?:_yosys)?\.v$",
)
PRAGMA_COMMENT_RE = re.compile(r"synopsys|synthesis|verilator|pragma", re.I)
JSON_SYMBOL_TYPES = {
    "BEGIN", "CELL", "FUNC", "GENFOR", "MODULE", "TASK", "VAR", "VARREF",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("src/edge-e3"))
    parser.add_argument("--output", type=Path, default=Path("src/edge-e3enc"))
    parser.add_argument(
        "--filelist", type=Path,
        default=Path("src/edge-e3/edge_core/filelists/edge_core_top_verilator_prod.fl"),
    )
    parser.add_argument(
        "--soc", type=Path, default=Path("src/soc/logical/common/edge_soc_top.v")
    )
    parser.add_argument("--soc-core-module", default="edge_core_debug")
    parser.add_argument("--top", default="edge_core_top")
    parser.add_argument("--salt", default="edge-e3-public")
    parser.add_argument("--sram-pattern", action="append", default=[])
    parser.add_argument("--keep", action="append", default=[])
    parser.add_argument("--keep-comments", action="store_true")
    parser.add_argument("--mapping-output", type=Path)
    parser.add_argument("--verilator", default="verilator")
    return parser.parse_args()


def hash_symbol(name: str, salt: str) -> str:
    value = f"edge-e3-obfuscate\0{salt}\0symbol\0{name}".encode()
    return "x" + hashlib.sha256(value).hexdigest()[:16]


def clean_for_parse(text: str) -> str:
    def blank(match: re.Match[str]) -> str:
        return "\n" * match.group(0).count("\n") + " "

    return re.sub(
        r"/\*.*?\*/|//[^\r\n]*|\"(?:\\.|[^\"\\])*\"",
        blank,
        text,
        flags=re.DOTALL,
    )


def redact_comments(text: str) -> str:
    def redact(match: re.Match[str]) -> str:
        value = match.group(0)
        if PRAGMA_COMMENT_RE.search(value):
            return value
        return "\n" * value.count("\n")

    return re.sub(r"/\*.*?\*/|//[^\r\n]*", redact, text, flags=re.DOTALL)


def find_balanced_statement(code: str, start: int) -> str:
    round_depth = square_depth = curly_depth = 0
    for pos in range(start, len(code)):
        char = code[pos]
        if char == "(":
            round_depth += 1
        elif char == ")":
            round_depth -= 1
        elif char == "[":
            square_depth += 1
        elif char == "]":
            square_depth -= 1
        elif char == "{":
            curly_depth += 1
        elif char == "}":
            curly_depth -= 1
        elif char == ";" and round_depth == square_depth == curly_depth == 0:
            return code[start:pos + 1]
    raise ValueError("unterminated Verilog statement")


def module_headers(text: str, selected: str | None = None) -> list[tuple[str, str]]:
    code = clean_for_parse(text)
    result: list[tuple[str, str]] = []
    for match in re.finditer(r"\bmodule\s+([A-Za-z_][A-Za-z0-9_$]*)", code):
        name = match.group(1)
        if selected is None or name == selected:
            result.append((name, find_balanced_statement(code, match.start())))
    return result


def header_symbols(text: str, selected: str | None = None) -> set[str]:
    symbols: set[str] = set()
    for name, header in module_headers(text, selected):
        symbols.add(name)
        symbols.update(IDENT_RE.findall(header))
    return symbols - RESERVED


def soc_boundary_symbols(text: str, core_module: str) -> set[str]:
    """Keep the module and left-hand named parameter/port labels used by SoC."""
    code = clean_for_parse(text)
    match = re.search(rf"\b{re.escape(core_module)}\b", code)
    if not match:
        raise ValueError(f"SoC does not instantiate {core_module}")
    statement = find_balanced_statement(code, match.start())
    labels = set(re.findall(r"\.\s*([A-Za-z_][A-Za-z0-9_$]*)\s*\(", statement))
    if not labels:
        raise ValueError(f"no named connections found for SoC instance of {core_module}")
    return {core_module} | labels


def internal_and_external_macros(texts: list[str]) -> tuple[set[str], set[str]]:
    defined: set[str] = set()
    referenced: set[str] = set()
    for text in texts:
        code = clean_for_parse(text)
        defined.update(re.findall(r"(?m)^\s*`define\s+([A-Za-z_]\w*)", code))
        referenced.update(
            re.findall(r"(?m)^\s*`(?:ifdef|ifndef|elsif)\s+([A-Za-z_]\w*)", code)
        )
    return defined, referenced - defined


def expand_filelist(path: Path, source_root: Path) -> list[Path]:
    result: list[Path] = []
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line or line.startswith(("+", "-y")):
            continue
        if line.startswith("-f"):
            nested = line[2:].strip()
            nested_path = Path(nested)
            if not nested_path.is_absolute():
                nested_path = source_root / nested_path
            result.extend(expand_filelist(nested_path.resolve(), source_root))
            continue
        candidate = Path(line)
        if not candidate.is_absolute():
            candidate = source_root / candidate
        candidate = candidate.resolve()
        if candidate.suffix.lower() in {".v", ".sv"}:
            result.append(candidate)
    return result


def is_sram(path: Path, source_root: Path, patterns: list[re.Pattern[str]]) -> bool:
    relative = path.relative_to(source_root).as_posix()
    return any(pattern.search(relative) for pattern in patterns)


def make_blackbox_stub(text: str) -> str:
    """Make a parser-only stub, retaining header and non-ANSI declarations."""
    headers = module_headers(text)
    if len(headers) != 1:
        raise ValueError("SRAM source must contain exactly one module")
    _, header = headers[0]
    if re.search(r"\b(?:input|output|inout)\b", header):
        return header + "\nendmodule\n"
    code = clean_for_parse(text)
    header_end = code.find(header) + len(header)
    declarations: list[str] = []
    for match in re.finditer(
        r"(?ms)^\s*(?:parameter|localparam|input|output|inout)\b.*?;", code[header_end:]
    ):
        declarations.append(match.group(0).strip())
    return header + "\n" + "\n".join(declarations) + "\nendmodule\n"


def write_plain_filelist(path: Path, files: list[Path]) -> None:
    path.write_text("".join(str(item) + "\n" for item in files))


def run_json(
    verilator: str, top: str, rtl_files: list[Path], sram_files: list[Path], temp: Path
) -> tuple[Path, int]:
    stub = temp / "sram_blackboxes.v"
    stub.write_text("\n".join(make_blackbox_stub(path.read_text()) for path in sram_files))
    parse_filelist = temp / "edge_e3_nosram.fl"
    write_plain_filelist(parse_filelist, rtl_files + [stub])
    json_path = temp / "edge.tree.json"
    meta_path = temp / "edge.tree.meta.json"
    warning_path = temp / "verilator-json.log"
    command = [
        verilator, "-Wno-fatal", "--json-only", "--top-module", top,
        "--Mdir", str(temp / "obj-json"), "--json-only-output", str(json_path),
        "--json-only-meta-output", str(meta_path), "-f", str(parse_filelist),
    ]
    with warning_path.open("w") as warnings:
        completed = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=warnings)
    if completed.returncode:
        sys.stderr.write(warning_path.read_text())
        raise RuntimeError("Verilator JSON elaboration failed")
    warning_count = warning_path.read_text().count("%Warning-")
    return json_path, warning_count


def json_symbol_names(value: Any) -> set[str]:
    result: set[str] = set()
    if isinstance(value, dict):
        if value.get("type") in JSON_SYMBOL_TYPES:
            for field in ("name", "origName", "verilogName"):
                name = value.get(field)
                if isinstance(name, str) and IDENT_RE.fullmatch(name):
                    result.add(name)
        for child in value.values():
            result.update(json_symbol_names(child))
    elif isinstance(value, list):
        for child in value:
            result.update(json_symbol_names(child))
    return result


def rewrite(text: str, symbols: dict[str, str], keep_comments: bool) -> str:
    if not keep_comments:
        text = redact_comments(text)
    pieces: list[str] = []
    for match in TOKEN_RE.finditer(text):
        value = match.group(0)
        pieces.append(symbols.get(value, value) if match.lastgroup == "ident" else value)
    return "".join(pieces)


def validate_mixed(verilator: str, top: str, mixed_filelist: Path, temp: Path) -> int:
    warning_path = temp / "verilator-mixed.log"
    command = [
        verilator, "-Wno-fatal", "--json-only", "--top-module", top,
        "--Mdir", str(temp / "obj-mixed"), "--json-only-output",
        str(temp / "mixed.tree.json"), "--json-only-meta-output",
        str(temp / "mixed.tree.meta.json"), "-f", str(mixed_filelist),
    ]
    with warning_path.open("w") as warnings:
        completed = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=warnings)
    if completed.returncode:
        sys.stderr.write(warning_path.read_text())
        raise RuntimeError("generated mixed RTL failed Verilator elaboration")
    return warning_path.read_text().count("%Warning-")


def validate_soc(
    verilator: str, soc_top: str, soc_files: list[Path], mixed_files: list[Path], temp: Path
) -> int:
    filelist = temp / "soc-mixed.fl"
    write_plain_filelist(filelist, mixed_files + soc_files)
    warning_path = temp / "verilator-soc.log"
    command = [
        verilator, "-Wno-fatal", "--json-only", "--top-module", soc_top,
        "--Mdir", str(temp / "obj-soc"), "--json-only-output",
        str(temp / "soc.tree.json"), "--json-only-meta-output",
        str(temp / "soc.tree.meta.json"), "-f", str(filelist),
    ]
    with warning_path.open("w") as warnings:
        completed = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=warnings)
    if completed.returncode:
        sys.stderr.write(warning_path.read_text())
        raise RuntimeError("generated RTL failed edge_soc_top elaboration")
    return warning_path.read_text().count("%Warning-")


def main() -> int:
    args = parse_args()
    source = args.source.resolve()
    output = args.output.resolve()
    filelist = args.filelist.resolve()
    soc = args.soc.resolve()
    repo_root = source.parent.parent
    if not source.is_dir() or not filelist.is_file() or not soc.is_file():
        raise SystemExit("source, filelist, or SoC boundary file does not exist")
    if output == source or source in output.parents:
        raise SystemExit("output must not overwrite or be nested under the readable source")

    patterns = [re.compile(item, re.I) for item in DEFAULT_SRAM_PATTERNS + tuple(args.sram_pattern)]
    all_files = expand_filelist(filelist, source)
    missing = [path for path in all_files if not path.is_file()]
    outside = [path for path in all_files if source not in path.parents]
    if missing:
        raise SystemExit("missing filelist inputs: " + ", ".join(map(str, missing)))
    if outside:
        raise SystemExit("production filelist contains files outside edge-e3")
    sram_files = [path for path in all_files if is_sram(path, source, patterns)]
    rtl_files = [path for path in all_files if path not in sram_files]
    if not sram_files:
        raise SystemExit("no SRAM/array inputs matched; refusing to publish an unpartitioned file")

    texts = {path: path.read_text() for path in rtl_files}
    keep = set(RESERVED) | set(args.keep)
    keep.update(header_symbols(texts[next(path for path in rtl_files if args.top in texts[path])], args.top))
    keep.update(soc_boundary_symbols(soc.read_text(), args.soc_core_module))
    for path in sram_files:
        # The legacy SRAMs use non-ANSI declarations, so their parameters and
        # ports live after the module header. The parser-only stub contains
        # exactly the complete public interface and no implementation names.
        keep.update(IDENT_RE.findall(make_blackbox_stub(path.read_text())))
    defined_macros, external_macros = internal_and_external_macros(list(texts.values()))
    keep.update(external_macros)

    output.parent.mkdir(parents=True, exist_ok=True)
    temp = Path(tempfile.mkdtemp(prefix="edge-e3-obfuscate.", dir=output.parent))
    stage = Path(tempfile.mkdtemp(prefix=f".{output.name}.", dir=output.parent))
    try:
        json_path, source_warnings = run_json(args.verilator, args.top, rtl_files, sram_files, temp)
        semantic_symbols = json_symbol_names(json.loads(json_path.read_text()))
        # The final Verilator AST omits names optimized away during elaboration.
        # Add source identifiers so unused declarations and module names are not
        # accidentally left readable; JSON remains the semantic/linking gate.
        for text in texts.values():
            semantic_symbols.update(IDENT_RE.findall(clean_for_parse(text)))
        # Internal source macros do not survive preprocessing into the AST, but
        # must be renamed consistently at their definitions and uses.
        semantic_symbols.update(defined_macros)
        symbols = {
            name: hash_symbol(name, args.salt)
            for name in sorted(semantic_symbols - keep - RESERVED)
        }

        combined = stage / "edge_e3enc.v"
        with combined.open("w") as stream:
            stream.write("// Generated by tools/obfuscate_edge_e3.py; do not edit.\n")
            for path in rtl_files:
                stream.write("\n")
                stream.write(rewrite(texts[path], symbols, args.keep_comments))
                stream.write("\n")

        sram_fl = stage / "edge_e3enc_sram.fl"
        mixed_fl = stage / "edge_e3enc_mixed.fl"
        nosram_fl = stage / "edge_e3enc_nosram.fl"
        validation_fl = temp / "mixed-absolute.fl"
        write_plain_filelist(validation_fl, [combined] + sram_files)
        mixed_warnings = validate_mixed(args.verilator, args.top, validation_fl, temp)
        soc_files = [
            repo_root / "src/soc/logical/axi/edge_axi_interconnect.v",
            repo_root / "src/soc/logical/mem/edge_axi_ram.v",
            repo_root / "src/soc/logical/axi/edge_axi_err.v",
            soc,
        ]
        soc_warnings = validate_soc(
            args.verilator, "edge_soc_top", soc_files, [combined] + sram_files, temp
        )

        portable_combined = Path("src/edge-e3enc/edge_e3enc.v")
        portable_sram = [path.relative_to(repo_root) for path in sram_files]
        write_plain_filelist(sram_fl, portable_sram)
        write_plain_filelist(nosram_fl, [portable_combined])
        write_plain_filelist(mixed_fl, [portable_combined] + portable_sram)

        manifest = {
            "format": 1,
            "top": args.top,
            "soc_core_module": args.soc_core_module,
            "rtl_inputs": len(rtl_files),
            "sram_inputs": len(sram_files),
            "semantic_symbols": len(semantic_symbols),
            "obfuscated_symbols": len(symbols),
            "public_symbols": len(keep - RESERVED),
            "source_warning_count": source_warnings,
            "mixed_warning_count": mixed_warnings,
            "soc_warning_count": soc_warnings,
            "salt_sha256": hashlib.sha256(args.salt.encode()).hexdigest(),
        }
        (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        (stage / "README.md").write_text(
            "# Generated edge-e3 RTL\n\n"
            "`edge_e3enc.v` contains obfuscated non-SRAM RTL.\n"
            "Use `edge_e3enc_mixed.fl` for simulation, or combine the single RTL "
            "file with target-specific SRAM models/replacements for FPGA/OpenROAD.\n\n"
            "Generate from the repository root with:\n\n"
            "```sh\ncmake --build build/cmake-harness --target edge_e3_obfuscate\n```\n\n"
            "FPGA/Yosys can consume the mixed list and select its `_yosys.v` SRAM "
            "variants:\n\n"
            "```sh\nsynth/run_yosys.sh edge_core_top xilinx "
            "src/edge-e3enc/edge_e3enc_mixed.fl\n```\n\n"
            "OpenROAD can consume the same list; its runner substitutes central "
            "`*_openroad.v` blackboxes for matching SRAM/cache-array entries.\n"
        )
        if args.mapping_output:
            mapping = args.mapping_output.resolve()
            mapping.parent.mkdir(parents=True, exist_ok=True)
            mapping.write_text(json.dumps(symbols, indent=2, sort_keys=True) + "\n")

        if output.exists():
            shutil.rmtree(output)
        stage.rename(output)
        print(
            f"generated {output / 'edge_e3enc.v'}: {len(symbols)} symbols renamed; "
            f"{len(sram_files)} SRAM/array sources external; Verilator validation passed"
        )
    finally:
        shutil.rmtree(temp, ignore_errors=True)
        shutil.rmtree(stage, ignore_errors=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError) as error:
        raise SystemExit(f"error: {error}") from error
