"""Build a remote-bitbang server around the real full-core/cache debug path."""
from pathlib import Path
import argparse,re,subprocess,os,shutil
p=argparse.ArgumentParser();p.add_argument('--views',type=Path,required=True);p.add_argument('--build-dir',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2];physical=root/'src/test-32/physical/openroad';here=physical/'legacy/targets/rv32core-debug-readport';rtl=root/'src/edge-32/rtl';out=a.build_dir.resolve();out.mkdir(parents=True,exist_ok=True)
defines=['EDGE32_LOCAL_FP_WB','EDGE32_EXTERNAL_FPU','EDGE32_APR_DENSE_CACHES','EDGE32_APR_DTCM_PORT','EDGE32_ID_DEBUG','EDGE32_APR_DTCM_ISSUE_STAGE','EDGE32_APR_CACHE_COMPLETION_STAGE','EDGE32_APR_PHYSICAL_RESET_MANAGER']
flags=['-D'+x for x in defines]+['-I'+str(rtl)]
s=subprocess.run(['verilator','-E',*flags,str(a.views/'full-core.sv')],check=True,capture_output=True,text=True).stdout
s=re.sub(r'^`line.*$', '',s,flags=re.M);s=s[s.index('module edge32_full_core_apr #'):];s=s[s.index(') (')+3:s.index(');')]
ports={}
for m in re.finditer(r'\b(input|output)\s+(?:wire|reg)?\s*(\[[^\]]+\])?\s*(.*?)(?=\b(?:input|output)\b|$)',s,re.S):
 for n in m[3].strip().rstrip(',').split(','):
  n=n.strip();assert re.fullmatch(r'\w+',n),n;ports[n]=(m[1],m[2] or '')

# Wrap the real cached full core; only its existing external debug req/resp is driven.
managed={'dtcm_cfg_valid','forever_cpuclk','reset_request_n','pad_biu_arready','pad_biu_rdata','pad_biu_rlast',
 'pad_biu_rid','pad_biu_rvalid','pad_biu_rresp','pad_biu_awready','pad_biu_wready',
 'pad_biu_bid','pad_biu_bvalid','pad_biu_bresp','debug_req_valid','debug_req_write','debug_req_id',
 'debug_req_data','debug_resp_ready','core_reset_n'}
decl='\n'.join(f'wire {t} {n};' if d=='output' or n in managed else f'wire {t} {n}=0;'
 for n,(d,t) in ports.items())
tb='''module jtag_tb(input wire clk,reset_n,srst_n,tck,trst_n,tms,tdi,output wire tdo);
 localparam PC_WIDTH=32,AXI_ADDR_WIDTH=64,AXI_DATA_WIDTH=128,AXI_ID_WIDTH=8,AXI_LEN_WIDTH=8,DTCM_ADDR_WIDTH=14;
'''+decl+'''
wire ndmreset;
 wire reset_request_n;
 edge32_core_reset_bridge reset_bridge(.clk(clk),.reset_n(reset_request_n),.core_reset_n(core_reset_n));
 wire mem_req_valid,mem_req_write,mem_req_ready,mem_resp_valid,mem_resp_ready;
 wire[31:0]mem_req_addr,mem_req_wdata,mem_resp_rdata;
 wire[1:0]mem_req_size;wire[2:0]mem_resp_error;
 assign forever_cpuclk=clk;
 assign reset_request_n=reset_n && srst_n && !ndmreset;

 // Commit the board memory map once after each target reset; otherwise LSU
 // correctly refuses requests until its route configuration has been accepted.
 reg map_configured;
 always @(posedge clk or negedge reset_request_n)
   if(!reset_request_n)map_configured<=0;
   else if(dtcm_cfg_valid && dtcm_cfg_ready)map_configured<=1;
 assign dtcm_cfg_valid=reset_release_done && !map_configured;
 edge32_jtag_debug transport(.clk(clk),.reset_n(reset_n),.core_reset_n(reset_release_done),.tck(tck),.trst_n(trst_n),.tms(tms),.tdi(tdi),.tdo(tdo),.ndmreset(ndmreset),.putchar_valid(putchar_valid),.putchar_char(putchar_char),
 .mem_req_valid(mem_req_valid),.mem_req_write(mem_req_write),.mem_req_addr(mem_req_addr),.mem_req_wdata(mem_req_wdata),
 .mem_req_size(mem_req_size),.mem_req_ready(mem_req_ready),.mem_resp_valid(mem_resp_valid),.mem_resp_ready(mem_resp_ready),
 .mem_resp_rdata(mem_resp_rdata),.mem_resp_error(mem_resp_error),
 .req_valid(debug_req_valid),.req_ready(debug_req_ready),.req_write(debug_req_write),.req_id(debug_req_id),.req_data(debug_req_data),
 .resp_valid(debug_resp_valid),.resp_ready(debug_resp_ready),.resp_error(debug_resp_error),.resp_data(debug_resp_data));
'''+ 'edge32_full_core_apr #(.ENABLE_FPU(1)) dut('+','.join(f'.{n}({n})' for n in ports)+');\n'+'''
 jtag_ram memory(.clk(clk),.reset_n(reset_n),.cpu_reset_n(reset_request_n),
 .mem_req_valid(mem_req_valid),.mem_req_write(mem_req_write),.mem_req_addr(mem_req_addr),.mem_req_wdata(mem_req_wdata),
 .mem_req_size(mem_req_size),.mem_req_ready(mem_req_ready),.mem_resp_valid(mem_resp_valid),.mem_resp_ready(mem_resp_ready),
 .mem_resp_rdata(mem_resp_rdata),.mem_resp_error(mem_resp_error),
 .araddr(biu_pad_araddr),.arlen(biu_pad_arlen),.arid(biu_pad_arid),.arsize(biu_pad_arsize),.arvalid(biu_pad_arvalid),.arready(pad_biu_arready),
 .rdata(pad_biu_rdata),.rid(pad_biu_rid),.rlast(pad_biu_rlast),.rresp(pad_biu_rresp),.rvalid(pad_biu_rvalid),.rready(biu_pad_rready),
 .awaddr(biu_pad_awaddr),.awlen(biu_pad_awlen),.awid(biu_pad_awid),.awsize(biu_pad_awsize),.awvalid(biu_pad_awvalid),.awready(pad_biu_awready),
 .wdata(biu_pad_wdata),.wstrb(biu_pad_wstrb),.wlast(biu_pad_wlast),.wvalid(biu_pad_wvalid),.wready(pad_biu_wready),
 .bid(pad_biu_bid),.bvalid(pad_biu_bvalid),.bresp(pad_biu_bresp),.bready(biu_pad_bready));
 endmodule
'''
(out/'jtag_tb.sv').write_text(tb)
replacements={'edge_32_core.v':'core-adapter.sv','edge_32_cached_core.v':'edge_32_cached_core.v','edge_32_axi_core.v':'edge_32_axi_core.v','edge32_debug_port.v':'edge32_debug_port.v','edge32_debug_bus.v':'edge32_debug_bus.v','edge32_full_core_apr.v':'full-core.sv','edge_32_gpr.v':'gpr-parent.v'}
sources=[]
for line in (physical/'legacy/targets/full-core32-cache-grt/filelists/core.fl').read_text().splitlines():
 if not line or '/rtl/cache_arrays.v' in line or '/rtl/metadata_sram.v' in line or Path(line).name in ('edge32_debug_bus.v', 'edge32_debug_iobuf.v', 'edge32_fpga_ram.v'):continue
 line=line.replace('${ROOT_DIR}',str(root)).replace('${EDGE32_ROOT}',str(root/'src/edge-32'))
 if Path(line).name in ('edge32_debug_port.v', 'edge32_debug_bus.v'):
  line=str(root/'src/edge-32/rtl/debug_control'/Path(line).name)
 elif Path(line).name in replacements:line=str(a.views/replacements[Path(line).name])
 if Path(line).name=='edge_32_dtcm_router.v':line=str(a.views/'dtcm-router.v')
 sources.append(line)
for cache,names in [('dcache',['edge_dcache_banked_data_array','edge_dcache_tag_array','edge_dcache_metadata_array']),('icache',['edge_ifu_icache_data_array','edge_ifu_icache_tag_array'])]:
 sources += [str(rtl/'cache'/cache/(n+'.v')) for n in names]
sources += [str(a.views/n) for n in ['edge32_scalar_shell_apr.sv','edge32_ex_apr.sv']]
sources += [str(physical/'targets/rv32-gpr4-readport-drt/rtl/edge32_gpr4_2r1w.v'),str(a.views/'split-lsu.v'),str(rtl/'reset/edge32_core_reset_manager.v'),str(rtl/'reset/edge32_core_reset_bridge.v')]
# Exercise the same contract wrapper and APR leaf default used by synthesis.
# Keep the implementation behavioral below that boundary for simulation.
for index, source in enumerate(sources):
 if Path(source).name == 'edge_32_icache.v':
  impl=(out/'edge_32_icache_impl.v')
  impl.write_text(Path(source).read_text().replace('module edge_32_icache', 'module edge_32_icache_impl', 1))
  sources[index]=str(impl)
  break
else:raise AssertionError('Missing behavioral I-cache implementation')
leaf=physical/'targets/icache32-dense-grt/rtl/edge32_icache32_apr.v'
(out/'edge32_icache32_apr.v').write_text(leaf.read_text().replace('edge_32_icache #', 'edge_32_icache_impl #'))
sources += [str(a.views/'icache/wrapper.v'),str(out/'edge32_icache32_apr.v')]
sources += [str(here/'tests/jtag_ram.sv')]
sources += [line.replace('${EDGE32_ROOT}',str(root/'src/edge-32')) for line in (root/'src/edge-32/filelists/debug_jtag.fl').read_text().splitlines() if line and not line.startswith('#')]
(out/'core.fl').write_text('\n'.join(sources)+'\n')
with(out/'build.log').open('w') as log:
 subprocess.run(['verilator','--cc','--exe','--build','-Wno-fatal','-Werror-IMPLICIT','--top-module','jtag_tb',
 '--Mdir',str(out),'-j','4',*flags,'-f',str(out/'core.fl'),str(out/'jtag_tb.sv'),str(here/'tests/remote_bitbang.cpp')],
 stdout=log,stderr=subprocess.STDOUT,check=True)
