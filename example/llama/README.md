# Llama NNC example

This example exports a small PyTorch model, lowers it through `nnc/compiler.py`,
links the generated weights into a bare-metal RISC-V image, and checks the
encrypted-core Verilator output against PyTorch.

```sh
python3 -m pip install -r nnc/requirements.txt
./example/llama/run.sh
```

Pass another model with `--model-file`, or generate and build without running
the simulator with `./example/llama/build.sh`.

Set `PYTHON=/path/to/python` when PyTorch is installed in a virtual environment.

Profile every lowered node in the complete tiny Llama transformer block:

```sh
./example/llama/profile.sh
```

The profiling smoke checks the BF16 result against PyTorch and writes
`profile.md`, `profile.tsv`, and `software-console.log` below
`example/llama/build/smoke_transformer_prefix/`.

Generated headers, weights, binaries, and logs are written below
`example/llama/build/` and are not source files.
