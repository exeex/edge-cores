# Test SoC Environment

This directory is the shared test-only SoC and simulation environment for the
Edge hardware products. It supplies AXI interconnect, memory models, the SoC
wrapper, and simulator testbench integration around the selected product RTL.

It is not an edge-e3, edge-e4, or edge-e5 product implementation. Product RTL
must remain under its corresponding sibling directory; this tree should contain
only reusable verification and integration infrastructure.

The public harness builds `src/edge-e3` together with the public Edge32 and
shared ASIC RTL. `tools/prepare_e3_filelist.py` resolves its source filelist and
supplies the local SRAM behavioral model in `logical/mem/edge_sram_sim.v`.
Private internal test repositories are optional and are not inputs to this
public harness. Other product harnesses can select another product root while
reusing this SoC environment.
