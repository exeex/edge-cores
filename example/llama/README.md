# Llama NNC example

This example exports the tiny Llama 3 transformer block in
`model/llama3_source.py`, lowers it through `nnc/compiler.py`,
links the generated weights into a bare-metal RISC-V image, and checks the
encrypted-core Verilator output against PyTorch.

```sh
python3 -m pip install -r nnc/requirements.txt
./example/llama/run.sh
```

Pass another model with `--model-file`, or generate and build without running
the simulator with `./example/llama/build.sh`. Compiler regression models live
under `nnc/test/`; this example intentionally contains only the user-facing
Llama source model.

Set `PYTHON=/path/to/python` when PyTorch is installed in a virtual environment.

Profile every lowered node in the complete tiny Llama transformer block:

```sh
./example/llama/profile.sh
```

The profiling smoke compiles `model/llama3_source.py` directly, checks its BF16
result against PyTorch, and writes
`profile.md`, `profile.tsv`, and `software-console.log` below
`example/llama/build/llama3_source/`.

Run every `nnc/test/smoke_*.py` case and the copied `llama3_source.py`
profiling case:

```sh
./example/llama/test.sh
```

The suite writes its summary to `example/llama/build/harness/harness.md` and
keeps one log per model in the same directory.

Generated headers, weights, binaries, and logs are written below
`example/llama/build/` and are not source files.
