# Edge synthesis profiles

This is the repository-local Yosys resource-estimation flow. It is derived
from the maintained `~/n906/synth` runner, but all inputs resolve inside this
repository.

```sh
./synth/run_profile.sh --check edge32@e3
./synth/run_profile.sh edge32@e3 xilinx
./synth/run_profile.sh edge-32 xilinx
```

Profiles:

| Profile | Top | RTL selection |
| --- | --- | --- |
| `edge32@e3` | `edge_core_edge32_top` | public E3 filelist resolved by `tools/prepare_e3_filelist.py` |
| `edge-32` | `edge_32_cached_core` | public Edge32 cached-core boundary |
| `edge-rv` | `edge_rv_top` | public edge-rv resource boundary |
| `edge-rv-lite` | `edge_rv_lite_cached_core` | public cached rv-lite boundary |

The naming convention is `<scalar-core>@<asic-set>`. The `edge32@e3` profile
uses public `src/edge-e3`, `src/edge-32` and `src/edge-asic` RTL, with local
SRAM behavioral models. It does not require private test repositories.

The `edge-rv` and `edge-rv-lite` profiles need their former source trees, which
are no longer submodules of this checkout. Set `EDGE_RV_ROOT` and, for lite,
`EDGE_RV_LITE_ROOT` to their locations. The Edge32 README pins the historical
revisions and commands used for its cached-core resource comparison.

Outputs are under `synth/build/<top>/<profile>/`; `stat.txt` is the primary
resource report. These are FPGA-oriented Yosys estimates, not placed-and-routed
or ASIC PPA results.
