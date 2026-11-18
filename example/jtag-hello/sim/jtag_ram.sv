// Test-only shared 64 KiB RAM. No image preload; SBA and CPU AXI see the same bytes.
module jtag_ram #(parameter RAM_BYTES=65536)(
 input wire clk,reset_n,cpu_reset_n,
 input wire mem_req_valid,mem_req_write,input wire[31:0]mem_req_addr,mem_req_wdata,
 input wire[1:0]mem_req_size,output wire mem_req_ready,
 output reg mem_resp_valid,output reg[31:0]mem_resp_rdata,output reg[2:0]mem_resp_error,
 input wire mem_resp_ready,
 input wire[63:0]araddr,input wire[7:0]arlen,arid,input wire[2:0]arsize,
 input wire arvalid,output wire arready,output reg[127:0]rdata,
 output reg[7:0]rid,output reg rlast,rvalid,output reg[1:0]rresp,input wire rready,
 input wire[63:0]awaddr,input wire[7:0]awlen,awid,input wire[2:0]awsize,
 input wire awvalid,output wire awready,input wire[127:0]wdata,input wire[15:0]wstrb,
 input wire wvalid,wlast,output wire wready,output reg[7:0]bid,
 output reg bvalid,output reg[1:0]bresp,input wire bready
);
 reg[7:0]ram[0:RAM_BYTES-1];
 integer init_i,b;
 initial for(init_i=0;init_i<RAM_BYTES;init_i=init_i+1)ram[init_i]=0;
 reg[63:0]read_addr,write_addr;
 reg[7:0]read_left,write_left,write_id;
 reg write_active,write_error,read_error;
 reg [4:0] bdelay;
 wire cpu_write_fire=wvalid&&wready;
 assign arready=cpu_reset_n&&!rvalid;
 assign awready=cpu_reset_n&&!write_active&&!bvalid&&bdelay==0;
 assign wready=cpu_reset_n&&write_active&&!bvalid;
 assign mem_req_ready=reset_n&&!mem_resp_valid&&!cpu_write_fire;
 function[127:0]read_line(input[63:0]addr);
   integer j;begin
     read_line=0;
     if(addr<=RAM_BYTES-16)for(j=0;j<16;j=j+1)read_line[j*8+:8]=ram[addr+j];
   end
 endfunction
 always @(posedge clk)begin
  if(!reset_n)begin mem_resp_valid<=0;mem_resp_rdata<=0;mem_resp_error<=0;end
  else begin
   if(mem_resp_valid&&mem_resp_ready)mem_resp_valid<=0;
   if(mem_req_valid&&mem_req_ready)begin
    if(!mem_req_write && (write_active || bvalid || bdelay!=0))
      $fatal(1,"SBA read before CPU writeback response completed");
    mem_resp_valid<=1;mem_resp_rdata<=0;mem_resp_error<=0;
    if(mem_req_size>2 || mem_req_addr>RAM_BYTES-(1<<mem_req_size))mem_resp_error<=2;
    else for(b=0;b<4;b=b+1)if(b<(1<<mem_req_size))begin
      if(mem_req_write)ram[mem_req_addr+b]<=mem_req_wdata[b*8+:8];
      else mem_resp_rdata[b*8+:8]<=ram[mem_req_addr+b];
    end
   end
  end
  // Target reset cancels CPU bus ownership, but neither SBA nor RAM contents.
  if(!cpu_reset_n)begin
   rvalid<=0;rdata<=0;rid<=0;rlast<=0;rresp<=0;read_addr<=0;read_left<=0;read_error<=0;
   write_active<=0;write_addr<=0;write_left<=0;write_id<=0;write_error<=0;
   bdelay<=0;bvalid<=0;bid<=0;bresp<=0;
  end else begin
   if(arvalid&&arready)begin
    rvalid<=1;read_addr<=araddr;read_left<=arlen;rid<=arid;rlast<=arlen==0;
    read_error<=arsize!=4;rresp<=(arsize!=4 || araddr>RAM_BYTES-16)?2:0;
    rdata<=read_line(araddr);
   end else if(rvalid&&rready)begin
    if(read_left==0)rvalid<=0;
    else begin
     read_left<=read_left-1;read_addr<=read_addr+16;rlast<=read_left==1;
     rdata<=read_line(read_addr+16);rresp<=(read_error || read_addr+16>RAM_BYTES-16)?2:0;
    end
   end
   if(bvalid&&bready)bvalid<=0;
   if(bdelay!=0)begin bdelay<=bdelay-1; if(bdelay==1)bvalid<=1; end
   if(awvalid&&awready)begin
    write_active<=1;write_addr<=awaddr;write_left<=awlen;write_id<=awid;
    write_error<=awsize!=4;
   end
   if(cpu_write_fire)begin
    if(!write_error && write_addr<=RAM_BYTES-16)
      for(b=0;b<16;b=b+1)if(wstrb[b])ram[write_addr+b]<=wdata[b*8+:8];
    write_error<=write_error || write_addr>RAM_BYTES-16 || (wlast!=(write_left==0));
    if(write_left==0)begin
     write_active<=0;bdelay<=16;bid<=write_id;
     bresp<=(write_error || write_addr>RAM_BYTES-16 || !wlast)?2:0;
    end else begin write_addr<=write_addr+16;write_left<=write_left-1;end
   end
  end
 end
endmodule
