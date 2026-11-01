#!/usr/bin/env python3
"""Validate the existing public matmul run and retain actual Tensor overlap signals."""
import argparse
import csv
import json
import os
from pathlib import Path
from render_arch_trace import ROOT, sha, command, is_command


def distill(csv_path, report_path, elf_path):
    report = report_path.read_text()
    if not {'TEST PASS', 'RETURN_VALUE=0', 'TENSOR_OUTPUT_CHECK=PASS'}.issubset(report.splitlines()):
        raise ValueError('Matmul run did not pass its numerical/return checks')
    hexadecimal = {'if_pc','if_inst','id_pc','id_inst','ex_pc','ex_inst','cmd_inst','cmd_capture'}
    with csv_path.open() as source:
        rows = [{k:int(v,16 if k in hexadecimal else 10) for k,v in r.items()} for r in csv.DictReader(source)]
    if not rows or any(b['cycle'] != a['cycle']+1 for a,b in zip(rows,rows[1:])):
        raise ValueError('Capture must contain consecutive nonempty samples')
    for r in rows:
        r['active_a'] = int(r['weight_valid'] and not r['active_bank'])
        r['active_b'] = int(r['weight_valid'] and r['active_bank'])
        r['fill_a'] = int(r['weight_transport'] and not r['fill_bank'])
        r['fill_b'] = int(r['weight_transport'] and r['fill_bank'])
        r['start_command'] = int(r['cmd_fire'] and is_command(r['cmd_inst'],0x15))
        r['sync_complete'] = int(r['ex_done'] and is_command(r['ex_inst'],0x16))
        r['sync_wait'] = int(r['ex_valid'] and is_command(r['ex_inst'],0x16) and not r['ex_release_ready'])
    def first(predicate):
        found=next((r for r in rows if predicate(r)),None)
        if found is None:
            raise ValueError('Required DMA/WLD/compute/handoff/drain evidence is missing')
        return found
    release=first(lambda r:r['ex_done'] and is_command(r['ex_inst'],0x16))
    dma_release=first(lambda r:r['cycle']>=release['cycle'] and r['ex_done'] and is_command(r['ex_inst'],2))
    rows=[r for r in rows if r['cycle']<=dma_release['cycle']+12]
    launches=[r for r in rows if r['engine_start']]
    loads=[r for r in rows if r['wld_done']]
    activations=[r for r in rows if r['weight_activate']]
    vectors=sum(r['compute_issue'] for r in rows)
    outputs=sum(r['dot_output'] for r in rows)
    if len(launches)!=64 or len(loads)!=64 or len(activations)!=64 or vectors!=8192 or outputs!=8192:
        raise ValueError(f'Incomplete matmul: launches={len(launches)}, WLD={len(loads)}, activation={len(activations)}, vectors={vectors}, results={outputs}')
    changes=[r for a,r in zip(rows,rows[1:]) if a['weight_valid'] and r['weight_valid'] and a['active_bank']!=r['active_bank']]
    if any(r['compute_issue'] and not r['weight_valid'] for r in rows):
        raise ValueError('Compute issued without valid active weights')
    if any(r['weight_transport'] and r['weight_valid'] and r['fill_bank']==r['active_bank'] for r in rows):
        raise ValueError('Weight transport overwrote an active bank')
    if len(changes)!=63 or not any(r['active_a'] for r in rows) or not any(r['active_b'] for r in rows):
        raise ValueError('Expected physical A/B alternation was not observed')
    overlaps={
        'dma_compute_cycles':sum(r['dma_write'] and r['compute_issue'] for r in rows),
        'wld_compute_cycles':sum(r['wld_read'] and r['compute_issue'] for r in rows),
        'write_compute_cycles':sum(r['output_write'] and r['compute_issue'] for r in rows),
        'wld_while_compute_busy':sum(r['wld_active'] and r['compute_busy'] for r in rows),
        'sync_wait_cycles':sum(r['sync_wait'] for r in rows)}
    if not overlaps['wld_while_compute_busy'] or not overlaps['write_compute_cycles']:
        raise ValueError('Required feeding/writeback overlap was not observed')
    if release['tensor_sync_stall'] or release['write_tail'] or release['tensor_busy']:
        raise ValueError('Tensor sync released before its observed drain')
    starts=[r for r in rows if r['start_command']]
    if len(starts)!=64 or any(a['cycle']>b['cycle'] for a,b in zip(starts,launches)):
        raise ValueError('Software starts must precede their ordered compute launches')
    wld_loads=[]
    for r in rows:
        if r['wld_active']:
            if not wld_loads or wld_loads[-1]['end']!=r['cycle']:
                wld_loads.append(dict(begin=r['cycle'],end=r['cycle'],reads=0))
            wld_loads[-1]['end']=r['cycle']+1
            wld_loads[-1]['reads']+=r['wld_read']
    if len(wld_loads)!=64 or any(load['reads']!=4 for load in wld_loads):
        raise ValueError('Expected four accepted 128-bit reads per INT8 tile')
    widths=[load['end']-load['begin'] for load in wld_loads]
    def event(row,label,phase,mode='overlap',node='tensor',group='main'):
        return dict(cycle=row['cycle'],label=label,tensorPhase=phase,mode=mode,node=node,group=group)
    events=[
        event(first(lambda r:r['dma_write']),'DMA writes SRAM',1,node='dma'),
        event(first(lambda r:r['wld_active']),'WLD tile loading',2),
        event(starts[0],'tensor_start accepted',0,mode='start'),
        event(first(lambda r:r['compute_issue']),'First Compute input valid',3,group='internal'),
        event(first(lambda r:r['dma_write'] and r['compute_issue']),'DMA write + Compute input valid',1,node='dma',group='internal'),
        event(first(lambda r:r['wld_read'] and r['compute_issue']),'WLD read + Compute input valid',2,group='internal'),
        event(changes[0],'First A/B switch',5,group='internal'),
        event(first(lambda r:r['output_write'] and r['compute_issue']),'Compute input valid + O write',4,group='internal'),
        event(first(lambda r:r['sync_wait']),'tensor_sync waiting',5,mode='sync',node='join'),
        event(release,'tensor_sync complete',5,mode='done',node='ex-completion'),
        event(dma_release,'Separate DMA join',5,mode='done',node='dma')]
    events.sort(key=lambda event:event['cycle'])
    signals=[('dma_busy','DMA busy','activity'),('wld_active','WLD tile loading','activity'),
             ('tensor_busy','Tensor active (busy)','activity'),('sync_wait','tensor_sync wait (EX)','software'),
             ('start_command','tensor_start accepted (pulse)','internal'),('dma_write','DMA SRAM write accepted','internal'),('wld_read','WLD read accepted (pulse)','internal'),
             ('wld_done','WLD fill complete (pulse)','internal'),
             ('fill_a','Fill bank A (transport)','internal'),('fill_b','Fill bank B (transport)','internal'),
             ('weight_activate','Weight activation accepted','internal'),('active_a','Bank A active','internal'),('active_b','Bank B active','internal'),
             ('engine_start','Compute job launch (internal)','internal'),('compute_busy','Compute job occupied','internal'),
             ('compute_issue','Compute input valid','internal'),('dot_output','Result enters O queue','internal'),
             ('output_write','O write accepted','internal'),('write_tail','Physical write tail','internal'),
             ('sync_complete','tensor_sync complete (pulse)','internal')]
    def runs(key):
        result=[]
        for r in rows:
            c,v=r['cycle'],r[key]
            if result and result[-1][2]==v: result[-1][1]=c+1
            else: result.append([c,c+1,v])
        return result
    paths=['example/tensor/matmul64x64_128tokens_tiled_circular.cpp','example/tensor/build.sh','example/tensor/trace.sh',
           'src/soc/logical/tb/edge_soc_arch_trace.svh','src/soc/logical/tb/edge_soc_demo_tb.v','scripts/build-verilator.sh',
           'tools/render_tensor_trace.py','tools/render_arch_trace.py',
           'src/edge-e3/edge_tensor_unit/edge_tensor_unit.v','src/edge-e3/edge_tensor_unit/rtl/edge_tensor_engine.v',
           'src/edge-e3/edge_tensor_unit/rtl/edge_tensor_weight_banks.v','src/edge-e3/edge_core/rtl/edge_accel_data_ctrl.v']
    return dict(schema=1,target='tensor',source=paths[0],begin=rows[0]['cycle'],end=rows[-1]['cycle']+1,
                title='Follow DMA, WLD, Tensor activity and tensor_sync.',
                description='The existing 64 × 64 × 128-token standalone matmul uses INT8 identity weights and BF16 activations, with all 8,192 final outputs checked by the public testbench. The windows show actual sampled cycles, not the ideal scheduling illustration above.',
                metric_cards=[[len(starts),'tensor_start commands accepted'],[sum(r['sync_complete'] for r in rows),'tensor_sync instruction completed'],[len(loads),'WLD tiles loaded']],
                wld_loads=wld_loads,
                wld_explanation=dict(tile_bytes=64,read_bits=128,reads_per_tile=4,min_cycles=min(widths),max_cycles=max(widths),vectors_per_start=128),
                starts=[dict(index=i+1,cycle=r['cycle'],launch_cycle=launches[i]['cycle']) for i,r in enumerate(starts)],
                metrics=dict(start_commands=len(starts),sync_commands=sum(r['sync_complete'] for r in rows),launches=len(launches),wld_completions=len(loads),weight_activations=len(activations),bank_switches=len(changes),vectors=vectors,results=outputs,**overlaps),
                sampling='Pre-rising-edge snapshots. A=physical bank 0, B=physical bank 1; active bank is meaningful only with weight_valid. An activation handshake changes state at the edge, visible in the next sample. The first tile may use B.',
                derived='Fill A/B qualifies fill_bank with packed-ingress transport busy, not merely !weight_start_ready. DMA/O write lanes are accepted memory requests, not proof of physical visibility at that same edge; write_tail retains the later SRAM lifetime. Simultaneous overlaps count exact cycles with both handshakes asserted; DMA busy alone does not imply a transfer.',
                events=events,channels=[dict(id=k,label=label,group=group,runs=runs(k)) for k,label,group in signals],
                ex_pc=runs('ex_pc'),ex_inst=runs('ex_inst'),
                state={k:runs(k) for k in ['ex_valid','wb_commit','weight_valid','active_bank','fill_bank','tensor_busy','tensor_sync_stall','compute_busy']},
                commands=[dict(cycle=r['cycle'],inst=f"{r['cmd_inst']:08x}",capture=f"{r['cmd_capture']:016x}") for r in rows if r['cmd_fire']],
                jobs=[dict(index=i+1,cycle=r['cycle'],bank=next((x['active_bank'] for x in rows if x['cycle']==r['cycle']+1),r['active_bank'])) for i,r in enumerate(launches)],
                provenance=dict(parent_revision=command('git','rev-parse','HEAD'),
                    submodules={name:command('git','-C',str(ROOT/'src'/name),'rev-parse','HEAD') for name in ['edge-32','edge-e3','edge-asic']},
                    verilator=command(os.environ.get('VERILATOR','verilator'),'--version'),
                    compiler=command(os.environ.get('CLANGXX') or ('/opt/homebrew/opt/llvm/bin/clang++' if Path('/opt/homebrew/opt/llvm/bin/clang++').exists() else 'clang++'),'--version').splitlines()[0],
                    source_sha256={p:sha(ROOT/p) for p in paths},csv_sha256=sha(csv_path),elf_sha256=sha(elf_path),report=report.strip(),
                    reproduction='./example/tensor/trace.sh'))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['csv','report','elf','output']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();data=distill(a.csv,a.report,a.elf)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text('// SPDX-License-Identifier: Apache-2.0\n// Observed matmul; regenerate with example/tensor/trace.sh --publish-trace.\nwindow.E3TensorMeasuredTrace='+json.dumps(data,separators=(',',':'))+';\n')
    print('TENSOR TRACE PASS: '+json.dumps(data['metrics']))


if __name__=='__main__':main()
