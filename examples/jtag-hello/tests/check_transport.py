"""Pin-level remote-bitbang and (when installed) real OpenOCD integration tests."""
import argparse, pathlib, socket, subprocess, shutil, sys, time, struct
p=argparse.ArgumentParser();p.add_argument('--sim',type=pathlib.Path,required=True);p.add_argument('--build-dir',type=pathlib.Path,required=True);a=p.parse_args()
a.build_dir.mkdir(parents=True,exist_ok=True)
sim=subprocess.Popen([str(a.sim.resolve()),'0'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
try:
 line=sim.stdout.readline().strip();assert line.startswith('REMOTE_BITBANG_PORT='),line
 port=int(line.split('=')[1]);s=socket.create_connection(('127.0.0.1',port));s.settimeout(10)
 def clocks(bits):
  s.sendall(bytes(x for tms,tdi in bits for x in (48+2*tms+tdi,52+2*tms+tdi,48+2*tms+tdi)))
 def scan(value,n,ir=False):
  clocks([(1,0),(1,0),(0,0),(0,0)] if ir else [(1,0),(0,0),(0,0)])
  buf=bytearray()
  for i in range(n):
   b=((value>>i)&1)+2*(i==n-1);buf.extend([48+b,ord('R'),52+b,48+b])
  s.sendall(buf);result=b''
  while len(result)<n:result+=s.recv(n-len(result))
  clocks([(1,0),(0,0)]+[(0,0)]*8)
  return sum((b==49)<<i for i,b in enumerate(result))
 def dmi(addr,data=0,wr=False):
  scan(17,5,True);scan((addr<<34)|(data<<2)|(2 if wr else 1),41)
  result=scan(0,41)
  assert result&3==0,f'DMI failed: {result:x}'
  return (result>>2)&0xffffffff
 def raw(number,data=0,write=False):
  dmi(0x70,data&0xffffffff,True);dmi(0x71,data>>32,True)
  dmi(0x72,number|(8 if write else 0),True)
  assert dmi(0x73)==0,'raw command failed'
  return dmi(0x70)|(dmi(0x71)<<32)
 def reg(number,value=None):
  if value is not None:dmi(4,value,True)
  dmi(0x17,0x220000|(0x10000 if value is not None else 0)|number,True)
  assert dmi(0x16)&0x700==0,'abstract command failed'
  return dmi(4)
 clocks([(1,0)]*6+[(0,0)])
 assert scan(0,32)==0xffd,'IDCODE'
 scan(16,5,True);assert scan(0,32)&0x3ff==0x71,'DTMCS'
 scan(31,5,True);assert scan(0b1010,4)==0b0100,'BYPASS'
 scan(3,5,True);assert scan(0b1010,4)==0b0100,'unknown IR bypass'
 dmi(0x10,1,True);assert dmi(0x11)&0x300==0x300,'reset halted'
 # Only the host reads ELF; all target bytes travel through JTAG / DMI / SBA.
 def sbwait():
  for _ in range(100):
   status=dmi(0x38)
   if not status&(1<<21):
    assert status&0x407000==0,hex(status)
    return
  raise AssertionError('SBA timeout')
 def sbwrite(addr,value,size=2):
  dmi(0x38,size<<17,True);dmi(0x39,addr,True);dmi(0x3c,value,True);sbwait()
 def sbread(addr,size=2):
  dmi(0x38,(size<<17)|(1<<20),True);dmi(0x39,addr,True);sbwait()
  return dmi(0x3c)
 assert dmi(0x38)&0xe0000fff==0x20000407
 assert sbread(0)==0 and sbread(0x1000)==0,'RAM must start empty'
 elf=(a.build_dir/'jtag_boot.elf').read_bytes()
 assert elf[:5]==b'\x7fELF\x01' and struct.unpack_from('<H',elf,18)[0]==243
 phoff=struct.unpack_from('<I',elf,28)[0]
 phsize,phnum=struct.unpack_from('<HH',elf,42)
 for i in range(phnum):
  typ,off,va,pa,filesz,memsz,flags,align=struct.unpack_from('<8I',elf,phoff+i*phsize)
  if typ!=1:continue
  payload=elf[off:off+filesz]+bytes(memsz-filesz)
  j=0
  while j<len(payload):
   n=4 if (pa+j)%4==0 and len(payload)-j>=4 else 1
   sbwrite(pa+j,int.from_bytes(payload[j:j+n],'little'),2 if n==4 else 0);j+=n
 assert sbread(0)==0x001f8f93 and sbread(0x1000)==41
 for size,value in [(0,0xa5),(1,0xbeef),(2,0x12345678)]:
  sbwrite(0x3000,value,size);assert sbread(0x3000,size)==value
 for addr,size,error in [(1,2,3),(0,3,4),(0x10000,2,2)]:
  dmi(0x38,(size<<17)|(1<<20),True);dmi(0x39,addr,True)
  assert (dmi(0x38)>>12)&7==error
  dmi(0x38,0x470000|0x7000,True)
 assert sbread(0x1000)==41
 # Hart enumeration must not accidentally operate on hart zero.
 dmi(0x10,0x10001,True);assert dmi(0x11)&0xc000==0xc000
 dmi(0x10,1,True)
 assert reg(0x101f)==0
 reg(0x101f,41);assert reg(0x101f)==41
 reg(0x7b1,0);assert reg(0x7b1)==0
 reg(0x7b0,4);dmi(0x10,0x40000001,True)
 assert dmi(0x11)&0x30300==0x30300,'step halt and resume acknowledgement'
 assert reg(0x7b1)==4 and reg(0x101f)==42
 assert (reg(0x7b0)>>6)&7==4
 reg(0x7b0,0);dmi(0x10,0x40000001,True);assert dmi(0x11)&0xc00==0xc00
 dmi(0x17,0x2207b0,True);assert dmi(0x16)&0x700==0x400
 dmi(0x16,0x700,True)
 dmi(0x10,0x80000001,True);assert dmi(0x11)&0x300==0x300
 reg(0x7b1,8);dmi(0x10,0x40000001,True)
 assert dmi(0x11)&0x300==0x300 and reg(0x101e)==44 and reg(0x7b1)==12
 # Patch a previously executed/cached instruction; the adapter syncs its line,
 # then step and observe the downloaded replacement. Restore for later tests.
 sbwrite(0,0x003f8f93);reg(0x7b1,0);reg(0x7b0,4)
 dmi(0x10,0x40000001,True)
 assert reg(0x101f)==45 and reg(0x7b1)==4
 sbwrite(0,0x001f8f93)
 reg(0x101f,42);reg(0x7b1,12);reg(0x7b0,0)
 # Misaligned PC is reported through cmderr, then W1C permits recovery.
 dmi(4,3,True);dmi(0x17,0x2307b1,True);assert dmi(0x16)&0x700==0x400
 dmi(0x16,0x700,True);assert reg(0x7b1)==12
 dmi(0x17,0x220fff,True);assert dmi(0x16)&0x700==0x200
 dmi(0x16,0x700,True)
 # Raw bridge exposes the existing custom controls without inventing AXI accesses.
 dmi(0x70,8,True);dmi(0x71,0,True);dmi(0x72,8,True);assert dmi(0x73)==0
 dmi(0x70,31,True);dmi(0x72,2,True);assert dmi(0x70)==42
 # Existing exact-PC hardware breakpoint is available through the raw bridge.
 raw(6,8,True);raw(7,1,True);reg(0x101e,123);reg(0x7b1,8)
 dmi(0x10,0x40000001,True)
 assert dmi(0x11)&0x300==0x300 and reg(0x7b1)==8 and reg(0x101e)==123
 raw(7,0,True);reg(0x7b0,4);dmi(0x10,0x40000001,True)
 assert reg(0x101e)==44 and reg(0x7b1)==12
 # Real putchar instructions enqueue stdout without stopping the RV32 core.
 reg(0x7b0,0);reg(0x7b1,64);dmi(0x10,0x40000001,True)
 assert dmi(0x11)&0xc00==0xc00
 assert dmi(0x74)==0x400301
 s.sendall(b't');clocks([(0,0)]*3);s.sendall(b'r');clocks([(0,0)]*8)
 assert dmi(0x11)&0xc00==0xc00 and dmi(0x74)==0x400301
 assert bytes(dmi(0x75)&255 for _ in range(3))==b'AB\n'
 assert dmi(0x75)==0 and dmi(0x74)==0x400000
 dmi(0x10,0x80000001,True)
 reg(0x7b1,128);dmi(0x10,0x40000001,True)
 assert dmi(0x74)==0x404007 and dmi(0x11)&0xc00==0xc00
 dmi(0x10,0x80000001,True)
 assert all(dmi(0x75)==0x158 for _ in range(64))
 dmi(0x74,4,True);assert dmi(0x74)==0x400000
 # Running SBA access temporarily halts the scalar and resumes it afterwards.
 reg(0x7b0,0);reg(0x7b1,1024);reg(0x101c,0);dmi(0x10,0x40000001,True)
 assert sbread(0x1000)==0x12345663
 assert dmi(0x11)&0xc00==0xc00,'read left auto-halted core stopped'
 sbwrite(0x1001,0xaa,0)
 assert dmi(0x11)&0xc00==0xc00,'write left auto-halted core stopped'
 assert sbread(0x1004)==77,'partial write lost neighboring dirty word'
 dmi(0x10,0x80000001,True)
 assert reg(0x101d)==0x1234aa63 and reg(0x101c)>0,'resume did not refetch modified data'
 sbwrite(0x1000,41)
 assert dmi(0x11)&0x300==0x300,'external halt was released by SBA'
 # TAP reset must preserve core/register state and not duplicate any command.
 clocks([(1,0)]*6+[(0,0)]);assert scan(0,32)==0xffd
 assert reg(0x101f)==42
 # ndmreset resets the core while keeping the DMI connection live.
 dmi(0x10,3,True);assert dmi(0x11)&0x3000==0x3000
 assert sbread(0x1000)==41,'SBA must remain usable during target reset'
 dmi(0x10,1,True);assert dmi(0x11)&0xc0000==0xc0000
 dmi(0x10,0x10000001,True);assert dmi(0x11)&0xc0000==0
 assert reg(0x101f)==0
 # External SRST keeps the TAP/DM alive and reports target reset.
 reg(0x101f,9);s.sendall(b's');clocks([(0,0)]*20)
 assert dmi(0x11)&0x3000==0x3000
 s.sendall(b'r');clocks([(0,0)]*100)
 assert dmi(0x10)&1==1 and reg(0x101f)==0
 s.sendall(b'Q');s.close()
 print('JTAG PIN / DMI / FULL CORE PASS')
 openocd=shutil.which('openocd')
 if openocd:
  config=a.build_dir/'openocd-test.cfg'
  config.write_text(f'''adapter driver remote_bitbang
remote_bitbang host 127.0.0.1
remote_bitbang port {port}
transport select jtag
reset_config none
jtag newtap edge cpu -irlen 5 -expected-id 0x00000ffd
target create edge.cpu riscv -chain-position edge.cpu
gdb_port disabled
tcl_port disabled
telnet_port disabled
init
halt
reg t6 41
reg pc 0
step
set actual [get_reg -force {{t6 pc}}]
if {{[dict get $actual t6] != 42 || [dict get $actual pc] != 4}} {{error "STEP register mismatch: $actual"}}
resume 4
sleep 10
halt
set resumed [get_reg -force {{pc}}]
if {{[dict get $resumed pc] != 4}} {{error "RESUME PC mismatch: $resumed"}}
echo EDGE_OPENOCD_STEP_PASS
shutdown
''')
  r=subprocess.run([openocd,'-f',str(config)],capture_output=True,text=True,timeout=45)
  (a.build_dir/'openocd.log').write_text(r.stdout+r.stderr)
  assert r.returncode==0 and 'EDGE_OPENOCD_STEP_PASS' in r.stdout+r.stderr and 'Error:' not in r.stdout+r.stderr,r.stdout+r.stderr
  print('OPENOCD FULL CORE PASS')
  # Exercise the shipping console client through OpenOCD's Tcl service.
  with socket.socket() as listener:
   listener.bind(('127.0.0.1',0));tcl_port=listener.getsockname()[1]
  serve=a.build_dir/'openocd-console.cfg'
  serve.write_text(config.read_text().replace('tcl_port disabled',f'tcl_port {tcl_port}').replace('shutdown\n', 'resume 64\necho EDGE_CONSOLE_READY\n'))
  logfile=a.build_dir/'openocd-console.log'
  with logfile.open('w') as log:
   server=subprocess.Popen([openocd,'-f',str(serve)],stdout=log,stderr=subprocess.STDOUT)
   try:
    deadline=time.monotonic()+15
    while 'EDGE_CONSOLE_READY' not in logfile.read_text():
     assert server.poll() is None and time.monotonic()<deadline,logfile.read_text()
     time.sleep(0.02)
    client=subprocess.run([sys.executable,str(pathlib.Path(__file__).resolve().parents[1]/'console.py'),'--port',str(tcl_port),'--once'],capture_output=True,timeout=15)
    assert client.returncode==0 and client.stdout==b'AB\n' and not client.stderr,(client.stdout,client.stderr,logfile.read_text())
    with socket.create_connection(('127.0.0.1',tcl_port),timeout=5) as ctl:ctl.sendall(b'shutdown\x1a')
    assert server.wait(timeout=10)==0,logfile.read_text()
    print('OPENOCD STDOUT CLIENT PASS')
   finally:
    if server.poll() is None:server.terminate();server.wait(timeout=5)

 else:print('OpenOCD not installed: pin-level test passed; OpenOCD integration SKIPPED')
finally:
 sim.terminate()
 try:sim.wait(timeout=5)
 except subprocess.TimeoutExpired:sim.kill();sim.wait()
