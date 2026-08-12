# Edge synthesis profiles

This is the repository-local Yosys resource-estimation flow. It is derived
from the maintained `~/n906/synth` runner, but all inputs resolve inside this
repository.

```sh
./synth/run_profile.sh --check edge-rv@e3
./synth/run_profile.sh edge-rv@e3 xilinx
./synth/run_profile.sh edge-rv xilinx
./synth/run_profile.sh edge-rv-lite xilinx
```

Profiles:

| Profile | Top | RTL selection |
| --- | --- | --- |
| `edge-rv@e3` | `edge_core_top` | `src/edge-e3enc/edge_e3enc_mixed.fl` |
| `edge-rv-lite@e3` | `edge_core_lite_top` | encrypted release, once that top is exported |
| `edge-rv` | `edge_rv_top` | public edge-rv resource boundary |
| `edge-rv-lite` | `edge_rv_lite_cached_core` | public cached rv-lite boundary |

The naming convention is `<scalar-core>@<asic-set>`. A downstream ASIC package
can therefore add profiles such as `edge-rv@some_asic_set` and
`edge-rv-lite@some_asic_set`, while the names without `@` continue to mean the
standalone public scalar boundaries.

`edge-rv-lite@e3` intentionally fails its preflight with the current encrypted
release, because `edge_e3enc.v` does not yet contain `edge_core_lite_top`. The
profile must never silently read private `src/edge-e3` RTL.

Outputs are under `synth/build/<top>/<profile>/`; `stat.txt` is the primary
resource report. These are FPGA-oriented Yosys estimates, not placed-and-routed
or ASIC PPA results.
