import subprocess,json,threading,queue,time,os,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[2]
adapter=os.environ.get('CPPDBG_ADAPTER')
if not adapter:
 candidates=list((Path.home()/'.vscode/extensions').glob('ms-vscode.cpptools-*/debugAdapters/bin/OpenDebugAD7'))
 if not candidates:raise SystemExit('Install VS Code C/C++ or set CPPDBG_ADAPTER')
 adapter=max(candidates,key=lambda p:p.stat().st_mtime)
p=subprocess.Popen([str(adapter)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=open('build/jtag-hello/dap-stderr.log','w'))
q=queue.Queue(); seq=0

def reader():
 while True:
  headers={}
  while True:
   line=p.stdout.readline()
   if not line:return
   if line==b'\r\n':break
   k,v=line.decode().split(':',1);headers[k.lower()]=v.strip()
  q.put(json.loads(p.stdout.read(int(headers['content-length']))))
threading.Thread(target=reader,daemon=True).start()
def send(command,args):
 global seq
 seq+=1
 raw=json.dumps(dict(seq=seq,type='request',command=command,arguments=args)).encode()
 p.stdin.write(('Content-Length: %d\r\n\r\n'%len(raw)).encode()+raw);p.stdin.flush()
def until(predicate):
 deadline=time.monotonic()+30
 while time.monotonic()<deadline:
  m=q.get(timeout=30)
  print(json.dumps(m),flush=True)
  if m.get('type')=='response' and not m.get('success'):raise RuntimeError(m)
  if predicate(m):return m
 raise TimeoutError()
try:
 send('initialize',{'adapterID':'cppdbg','linesStartAt1':True,'columnsStartAt1':True,'pathFormat':'path'})
 until(lambda m:m.get('command')=='initialize')
 cfg=json.loads((root/'examples/jtag-hello/launch.json').read_text())['configurations'][0]
 cfg=json.loads(json.dumps(cfg).replace('${workspaceFolder}',str(root)))
 cfg.pop('preLaunchTask')
 cfg.pop('postDebugTask',None)
 cfg['miDebuggerPath']=os.environ.get('GDB') or shutil.which('riscv64-elf-gdb') or shutil.which('gdb-multiarch') or cfg['miDebuggerPath']
 send('launch',cfg)
 until(lambda m:m.get('event')=='initialized')
 send('setBreakpoints',{'source':{'path':str(root/'examples/jtag-hello/main.c')},'breakpoints':[{'line':11}]})
 until(lambda m:m.get('command')=='setBreakpoints')
 send('configurationDone',{})
 stopped=until(lambda m:m.get('event')=='stopped')
 tid=stopped['body']['threadId']
 send('stackTrace',{'threadId':tid})
 stack=until(lambda m:m.get('command')=='stackTrace')
 assert stack['body']['stackFrames'][0]['name'].startswith('main'),stack
 send('continue',{'threadId':tid})
 until(lambda m:m.get('event')=='stopped')
 send('stackTrace',{'threadId':tid})
 stack=until(lambda m:m.get('command')=='stackTrace')
 assert stack['body']['stackFrames'][0]['line']==11,stack
 send('evaluate',{'expression':'message','frameId':stack['body']['stackFrames'][0]['id'],'context':'watch'})
 result=until(lambda m:m.get('command')=='evaluate')
 assert 'Hello world from Edge32!' in result['body']['result'],result
 send('disassemble',{'memoryReference':'0x0','instructionCount':4})
 result=until(lambda m:m.get('command')=='disassemble')
 assert len(result['body']['instructions'])==4,result
 send('next',{'threadId':tid})
 until(lambda m:m.get('event')=='stopped')
 send('setBreakpoints',{'source':{'path':str(root/'examples/jtag-hello/main.c')},'breakpoints':[]})
 until(lambda m:m.get('command')=='setBreakpoints')
 send('continue',{'threadId':tid})
 until(lambda m:m.get('event')=='stopped')
 send('stackTrace',{'threadId':tid})
 stack=until(lambda m:m.get('command')=='stackTrace')
 send('evaluate',{'expression':'characters_written','frameId':stack['body']['stackFrames'][0]['id'],'context':'watch'})
 result=until(lambda m:m.get('command')=='evaluate')
 assert result['body']['result']=='25',result
 send('disconnect',{'terminateDebuggee':False})
 until(lambda m:m.get('command')=='disconnect')
 print('DAP_LAUNCH_AND_SOURCE_BREAKPOINT_PASS')
finally:
 p.terminate()
 p.wait(timeout=10)
