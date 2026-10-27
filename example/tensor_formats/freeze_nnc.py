#!/usr/bin/env python3
"""Refresh literal FP4 data/goldens; the readable main.cpp files are handwritten."""
from pathlib import Path
import hashlib
import json
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from nnc.run_smoke import generate

HERE = Path(__file__).resolve().parent
manifest = {
    'nnc_revision': subprocess.check_output(
        ['git', '-C', str(ROOT / 'src/edge-nnc'), 'rev-parse', 'HEAD'], text=True
    ).strip(),
    'cases': {},
}
for name in ('group32', 'group64', 'precision', 'ring_wrap'):
    model = 'smoke_linear_fp4' + ('' if name == 'ring_wrap' else '_' + name)
    source = ROOT / 'nnc/test' / f'{model}.py'
    # Compiler wrappers are temporary: examples keep only payloads and goldens.
    with tempfile.TemporaryDirectory() as directory:
        generated = Path(directory)
        golden = generate(source, generated)
        payloads = {key: (generated / f'{key}.bin').read_bytes()
                    for key in ('weight', 'input')}
    input_bits = struct.unpack('<' + 'H' * (len(payloads['input']) // 2), payloads['input'])
    text = '''// SPDX-License-Identifier: Apache-2.0
#pragma once
#include "libnn/ops.hpp"

// Literal payloads and model golden from NNC. Refresh with ../freeze_nnc.py.
// Input/output are BF16. Each packed FP4 K32 slot contains eight BF16 scales
// (16 bytes) followed by four output-major 8x8 E2M1 tiles (32 bytes each).
namespace data {
using Bf16 = nnedge::bfloat16_t;
using Pack = nnedge::FP4WeightPack;

alignas(64) inline Bf16 input[] = {
'''
    for i in range(0, len(input_bits), 8):
        text += '    ' + ', '.join(f'Bf16(0x{v:04x})' for v in input_bits[i:i+8]) + ',\n'
    text += '};\n\nalignas(64) inline Pack weights[] = {\n'
    slot_bytes = 144  # eight BF16 scales + four FP4 tiles
    assert len(payloads['weight']) % slot_bytes == 0
    for start in range(0, len(payloads['weight']), slot_bytes):
        text += '    {{\n'
        for i in range(start, start + slot_bytes, 16):
            text += '        ' + ', '.join(f'0x{b:02x}' for b in payloads['weight'][i:i+16]) + ',\n'
        text += '    }},\n'
    text += '};\n\ninline constexpr uint16_t expected_output[] = {\n'
    for i in range(0, len(golden), 8):
        text += '    ' + ', '.join(f'0x{v:04x}' for v in golden[i:i+8]) + ',\n'
    text += f'}};\n\nalignas(64) inline Bf16 output[{len(golden)}] = {{}};\n}} // namespace data\n'
    destination = HERE / name
    destination.mkdir(exist_ok=True)
    (destination / 'data.hpp').write_text(text)
    manifest['cases'][name] = {
        'model': f'nnc/test/{model}.py',
        'model_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'payload_sha256': {k: hashlib.sha256(v).hexdigest() for k, v in payloads.items()},
        'golden_sha256': hashlib.sha256(struct.pack('<' + 'H' * len(golden), *golden)).hexdigest(),
    }
(HERE / 'data_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
