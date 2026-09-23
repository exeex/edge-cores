# Edge synthesis profiles

This is the repository-local Yosys resource-estimation flow. It is derived
from the maintained `~/n906/synth` runner, but all inputs resolve inside this
repository.

```sh
./synth/run_profile.sh --check edge32@e3
./synth/run_profile.sh edge32@e3 xilinx
./synth/run_profile.sh edge-rv xilinx
./synth/run_profile.sh edge-rv-lite xilinx
```

Profiles:

| Profile | Top | RTL selection |
| --- | --- | --- |
| `edge32@e3` | `edge_core_edge32_top` | `src/edge-e3enc/edge_e3enc_mixed.fl` |
| `edge-rv` | `edge_rv_top` | public edge-rv resource boundary |
| `edge-rv-lite` | `edge_rv_lite_cached_core` | public cached rv-lite boundary |

The naming convention is `<scalar-core>@<asic-set>`. The `edge32@e3` profile
uses only the generated `edge-e3enc` package; it never falls back to private
`src/edge-e3` RTL.

Outputs are under `synth/build/<top>/<profile>/`; `stat.txt` is the primary
resource report. These are FPGA-oriented Yosys estimates, not placed-and-routed
or ASIC PPA results.
