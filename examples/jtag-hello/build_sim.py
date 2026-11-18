#!/usr/bin/env python3
"""Build JTAG simulation from public Edge32 RTL and local simulation support."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
EDGE32 = ROOT / 'src/edge-32'


def build(out):
    out = out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sources = []
    for name in ('edge_32.fl', 'debug_core.fl', 'debug_jtag.fl'):
        for line in (EDGE32 / 'filelists' / name).read_text().splitlines():
            if not line or line.startswith(('#', '+incdir+', '+define+')):
                continue
            # Only used by the FPGA cache mapping, not native simulation arrays.
            if line.endswith('/edge32_fpga_ram.v'):
                continue
            sources.append(Path(line.replace('${ROOT_DIR}', str(ROOT)).replace('${EDGE32_ROOT}', str(EDGE32))))
    sources += [EDGE32 / 'rtl/reset/edge32_core_reset_bridge.v',
                HERE / 'sim/jtag_ram.sv', HERE / 'sim/jtag_tb.sv']
    for source in sources:
        if not source.is_file():
            raise RuntimeError(f'Missing public RTL source: {source}')
    (out / 'core.fl').write_text('\n'.join(map(str, sources)) + '\n')
    cmd = ['verilator', '--cc', '--exe', '--build', '-Wno-fatal', '-Werror-IMPLICIT',
           '--top-module', 'jtag_tb', '--Mdir', str(out), '-j', '4',
           '-DEDGE32_DEBUG', '-I' + str(EDGE32 / 'rtl'), '-f', str(out / 'core.fl'),
           str(HERE / 'sim/remote_bitbang.cpp')]
    with (out / 'build.log').open('w') as log:
        result = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f'Verilator failed; see {out / "build.log"}')
    inputs = set(sources) | set((EDGE32 / 'rtl').rglob('*.svh')) | set((EDGE32 / 'rtl').rglob('*.sv'))
    inputs.add(HERE / 'sim/remote_bitbang.cpp')
    inputs.update(EDGE32 / 'filelists' / name for name in ('edge_32.fl', 'debug_core.fl', 'debug_jtag.fl'))
    (out / 'inputs.json').write_text(json.dumps({
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(inputs)
    }, indent=2) + '\n')
    print(f'Built {out / "Vjtag_tb"}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, default=ROOT / 'build/jtag-hello/sim')
    build(parser.parse_args().build_dir)
