#!/usr/bin/env python3
"""Validate a public simulator CSV and distill an architecture documentation fixture."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def is_command(inst, index):
    return inst & 127 == 0x3f and (inst >> 25) & 127 == index


def distill(csv_path, report_path, elf_path):
    if not {'TEST PASS','RETURN_VALUE=0'}.issubset(report_path.read_text().splitlines()):
        raise ValueError('Simulator report must contain TEST PASS')
    with csv_path.open() as source:
        rows = list(csv.DictReader(source))
    if not rows:
        raise ValueError('Empty trace')
    hex_fields = {'if_pc', 'if_inst', 'id_pc', 'id_inst', 'ex_pc', 'ex_inst', 'cmd_inst', 'cmd_capture'}
    rows = [{k: int(v, 16 if k in hex_fields else 10) for k, v in row.items()} for row in rows]
    for before, after in zip(rows, rows[1:]):
        if after['cycle'] != before['cycle'] + 1:
            raise ValueError('Trace must sample consecutive cycles')
    # A single WB completion slot captures EX on ex_done. These shadow tags are
    # reconstructed from observed transfers, not read from a nonexistent WB PC port.
    pending = None
    for row in rows:
        row['retired_inst'] = pending if row['wb_commit'] else None
        if row['ex_done']:
            pending = row['ex_inst']
        row['sync_wait'] = int(row['ex_valid'] and is_command(row['ex_inst'], 0x26) and not row['ex_release_ready'])
        row['scalar_commit'] = int(row['wb_commit'] and row['actu_busy'] and
                                   row['retired_inst'] is not None and row['retired_inst'] & 127 in (0x13, 0x33, 0x63, 0x37, 0x17))
    def first(predicate):
        cycle = next((row['cycle'] for row in rows if predicate(row)), None)
        if cycle is None:
            raise ValueError('Trace is missing a required start, scalar, sync or completion event')
        return cycle
    start = first(lambda r: r['cmd_fire'] and is_command(r['cmd_inst'], 0x25))
    join = first(lambda r: r['ex_valid'] and is_command(r['ex_inst'], 0x26))
    release = first(lambda r: r['ex_done'] and is_command(r['ex_inst'], 0x26))
    work = first(lambda r: r['scalar_commit'] and start < r['cycle'] < join)
    wait_cycles = sum(r['sync_wait'] for r in rows if join <= r['cycle'] <= release)
    overlap = sum(r['scalar_commit'] for r in rows if start < r['cycle'] < join)
    if not start < work < join <= release or not wait_cycles or overlap < 32:
        raise ValueError('Trace does not demonstrate scalar overlap and a pending join')
    if not any(r['cmd_fire'] and is_command(r['cmd_inst'], 0x23) and r['cmd_capture'] == 4096 for r in rows):
        raise ValueError('Missing captured setn(4096) command')
    selected = [r for r in rows if r['cycle'] <= release + 12]
    begin, end = selected[0]['cycle'], selected[-1]['cycle'] + 1
    signals = [('if_valid','IF parcel valid'),('id_valid','ID occupied'),('ex_valid','EX occupied'),
               ('wb_pending','WB occupied'),('wb_commit','WB commit'),('actu_busy','ACTU busy'),
               ('scalar_commit','Scalar commit while busy'),('sync_wait','EX sync waiting'),
               ('ex_done','EX transfer'),('cmd_fire','ASIC command accepted')]
    def runs(key):
        result = []
        for row in selected:
            cycle, value = row['cycle'], row[key]
            if result and result[-1][2] == value:
                result[-1][1] = cycle + 1
            else:
                result.append([cycle, cycle+1, value])
        return result
    files = ['example/fork_join/fork_join.cpp', 'src/soc/logical/tb/edge_soc_arch_trace.svh',
             'src/soc/logical/tb/edge_soc_demo_tb.v', 'scripts/build-verilator.sh',
             'scripts/build-cpp-example.sh', 'example/fork_join/run.sh',
             'example/fork_join/build.sh', 'tools/render_arch_trace.py']
    revisions = {name: command('git','-C',str(ROOT/'src'/name),'rev-parse','HEAD') for name in ['edge-32','edge-e3','edge-asic']}
    events = [{'cycle':start,'label':'Start accepted','mode':'start','node':'launch'},
              {'cycle':work,'label':'Scalar overlap','mode':'overlap','node':'alu'},
              {'cycle':join,'label':'Sync enters EX','mode':'sync','node':'join'},
              {'cycle':release,'label':'Sync completes','mode':'done','node':'ex-completion'}]
    return dict(schema=1, source='example/fork_join/fork_join.cpp', target='actu', begin=begin, end=end,
                sampling='Pre-rising-edge snapshots; cycle is the public testbench counter. High means true for that edge. IF valid describes a buffered parcel, not fetch-request occupancy.',
                derived='Scalar commit while busy uses WB commit plus the instruction shadowed from the preceding EX transfer; it includes integer ALU/branch instructions, not ASIC commands.',
                metrics=dict(scalar_commits_while_busy_before_join=overlap, sync_wait_cycles=wait_cycles,
                             start_to_sync_completion=release-start),
                events=events, channels=[dict(id=k,label=label,runs=runs(k)) for k,label in signals],
                ex_pc=runs('ex_pc'), ex_inst=runs('ex_inst'),
                commands=[dict(cycle=r['cycle'],inst=f"{r['cmd_inst']:08x}",capture=f"{r['cmd_capture']:016x}") for r in selected if r['cmd_fire']],
                provenance=dict(parent_revision=command('git','rev-parse','HEAD'), submodules=revisions,
                                verilator=command(os.environ.get('VERILATOR','verilator'),'--version'),
                                compiler=command(os.environ.get('CLANGXX') or ('/opt/homebrew/opt/llvm/bin/clang++' if Path('/opt/homebrew/opt/llvm/bin/clang++').exists() else 'clang++'),'--version').splitlines()[0],
                                source_sha256={name:sha(ROOT/name) for name in files},
                                csv_sha256=sha(csv_path),elf_sha256=sha(elf_path),
                                report=report_path.read_text().strip(),
                                reproduction='./example/fork_join/run.sh'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csv',type=Path,required=True)
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--elf',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    data = distill(args.csv,args.report,args.elf)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text('// SPDX-License-Identifier: Apache-2.0\n// Observed public RTL; regenerate with example/fork_join/run.sh --publish-trace.\nwindow.E3MeasuredTrace='+json.dumps(data,separators=(',',':'))+';\n')
    print('TRACE PASS: '+json.dumps(data['metrics']))


if __name__ == '__main__':
    main()
