#!/usr/bin/env python3
"""Resolve the public E3 filelist without depending on internal test models."""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
E3 = ROOT / 'src/edge-e3'
ENTRY = E3 / 'edge_core/filelists/edge_core_edge32_top_verilator.fl'
# Upstream names an internal regression model; consumers supply this public
# behavioral implementation of the SRAM interface instead.
SRAM_MODEL = ROOT / 'synth/openroad/tests/asap7_fakeram_functional_models.v'
PUBLIC_MODEL = ROOT / 'src/soc/logical/mem/edge_sram_sim.v'
ALLOWED = tuple(ROOT / p for p in ('src/edge-e3', 'src/edge-32', 'src/edge-asic', 'src/soc'))


def checked(path: Path) -> Path:
    path = path.resolve()
    if not any(path.is_relative_to(root) for root in ALLOWED):
        raise ValueError(f'filelist input outside public RTL roots: {path}')
    if not path.exists():
        raise FileNotFoundError(f'missing public RTL input: {path}; initialize src/edge-e3, src/edge-asic and src/edge-32')
    return path


def expand(filelist: Path, stack: tuple[Path, ...] = ()) -> list[str]:
    filelist = checked(filelist)
    if filelist in stack:
        raise ValueError(f'cyclic filelist: {filelist}')
    entries = []
    for raw in filelist.read_text().splitlines():
        line = raw.split('#', 1)[0].strip()
        if not line:
            continue
        if line.startswith('-f '):
            entries.extend(expand(E3 / line[3:].strip(), (*stack, filelist)))
        elif line.startswith('+incdir+'):
            entries.append('+incdir+' + str(checked(E3 / line[8:])))
        elif line.endswith(('.v', '.sv')):
            source = (E3 / line).resolve()
            entries.append(str(checked(PUBLIC_MODEL if source == SRAM_MODEL else source)))
        else:
            raise ValueError(f'unsupported filelist entry in {filelist}: {line}')
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    entries = list(dict.fromkeys(expand(ENTRY)))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text('\n'.join(entries) + '\n')


if __name__ == '__main__':
    main()
