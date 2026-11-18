// OpenOCD remote_bitbang socket adapter. JTAG protocol is implemented by RTL.
#include "Vjtag_tb.h"
#include "verilated.h"
#include <arpa/inet.h>
#include <sys/socket.h>
#include <poll.h>
#include <unistd.h>
#include <cerrno>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <csignal>
static volatile sig_atomic_t stopped=0;
static void stop(int){stopped=1;}
int main(int argc,char**argv){
 try {
  unsigned port=argc>1?std::stoul(argv[1]):9824;
  if(port>65535)throw std::runtime_error("invalid port");
  VerilatedContext context; context.commandArgs(argc,argv);
  Vjtag_tb top{&context};
  auto tick=[&](){top.clk=0;top.eval();context.timeInc(1);top.clk=1;top.eval();context.timeInc(1);top.clk=0;top.eval();};
  top.reset_n=0;top.srst_n=1;top.trst_n=0;top.tck=0;top.tms=1;top.tdi=0;
  for(int i=0;i<8;i++)tick();
  top.reset_n=1;top.trst_n=1;for(int i=0;i<1024;i++)tick();
  signal(SIGINT,stop);signal(SIGTERM,stop);signal(SIGPIPE,SIG_IGN);
  int server=socket(AF_INET,SOCK_STREAM,0);if(server<0)throw std::runtime_error("socket failed");
  int yes=1;setsockopt(server,SOL_SOCKET,SO_REUSEADDR,&yes,sizeof(yes));
  sockaddr_in addr{};addr.sin_family=AF_INET;addr.sin_addr.s_addr=htonl(INADDR_LOOPBACK);addr.sin_port=htons(port);
  if(bind(server,(sockaddr*)&addr,sizeof(addr))<0 || listen(server,1)<0)throw std::runtime_error("bind/listen failed");
  socklen_t len=sizeof(addr);getsockname(server,(sockaddr*)&addr,&len);
  std::cout<<"REMOTE_BITBANG_PORT="<<ntohs(addr.sin_port)<<std::endl;
  int client=-1;char buf[4096];
  while(!stopped && !context.gotFinish()){
    pollfd p{client<0?server:client,POLLIN,0};int n=poll(&p,1,0);
    if(n<0 && errno!=EINTR)throw std::runtime_error("poll failed");
    if(n>0 && p.revents){
      if(client<0){client=accept(server,nullptr,nullptr);if(client<0)throw std::runtime_error("accept failed");}
      else {
        auto count=recv(client,buf,sizeof(buf),0);
        if(count<=0){close(client);client=-1;}
        else for(int i=0;i<count;i++){
          char c=buf[i];
          if(c>='0' && c<='7'){unsigned b=c-'0';top.tck=(b>>2)&1;top.tms=(b>>1)&1;top.tdi=b&1;top.eval();}
          else if(c=='R'){char r=top.tdo?'1':'0';if(send(client,&r,1,0)!=1)throw std::runtime_error("send failed");}
          else if(c>='r' && c<='u'){
            unsigned b=c-'r';top.trst_n=!(b&2);
            // System reset affects the target; the debug transport stays accessible.
            top.srst_n=!(b&1);top.eval();
          } else if(c=='Q'){close(client);client=-1;break;}
          else if(c=='Z' || c=='z'){for(int j=0;j<(c=='Z'?1000:1);j++)tick();}
          else if(c!='B' && c!='b')throw std::runtime_error("unsupported remote_bitbang command");
          for(int j=0;j<4;j++)tick();
        }
      }
    }
    // The SoC keeps running even while the debugger is waiting for socket input.
    for(int j=0;j<32;j++)tick();
  }
  if(client>=0)close(client);close(server);top.final();return 0;
 }catch(const std::exception&e){std::cerr<<e.what()<<std::endl;return 1;}
}
