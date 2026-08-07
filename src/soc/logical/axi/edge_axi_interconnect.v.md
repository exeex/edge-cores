# edge_axi_interconnect.v

## Purpose

`edge_axi_interconnect` is the first clean-room Edge SoC AXI fabric. It is a
small one-master, two-slave decoder used by `edge_soc_top` to separate the core
synthesis boundary from the SoC shell.

It follows the C906 SoC role of an external interconnect, but it does not reuse
C906 RTL.

## Current Shape

```text
edge_core_top BIU master
  -> edge_axi_interconnect
       -> edge_axi_ram
       -> edge_axi_err
```

Addresses with bits above `RAM_ADDR_MSB` clear route to RAM. Other addresses
route to the error slave.

## First-Slice Simplifications

- Single outstanding read and single outstanding write are supported.
- Burst metadata is forwarded, but this first slice treats responses as
  single-beat.
- No APB, UART, timer, GPIO, or interrupt fabric is implemented yet.

