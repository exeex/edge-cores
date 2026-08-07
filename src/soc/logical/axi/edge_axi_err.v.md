# edge_axi_err.v

## Purpose

`edge_axi_err` is the clean-room Edge SoC default/error slave. It gives unmapped
AXI accesses a deterministic response instead of leaving the core bus hanging.

## Behavior

- Read requests return one beat of all-ones data with `SLVERR`.
- Write requests accept address/data and return `SLVERR`.
- Only one read and one write response are tracked at a time.

