# Test SoC Environment

This directory is the shared test-only SoC and simulation environment for the
Edge hardware products. It supplies AXI interconnect, memory models, the SoC
wrapper, and simulator testbench integration around the selected product RTL.

It is not an edge-e3, edge-e4, or edge-e5 product implementation. Product RTL
must remain under its corresponding sibling directory; this tree should contain
only reusable verification and integration infrastructure.

The current harness selects `src/edge-e3`. Future e4/e5 enablement should make
the product root configurable without duplicating this SoC environment.
