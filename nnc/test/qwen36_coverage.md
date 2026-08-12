# Qwen3.6 NNC coverage

`qwen36_source.py` is a runnable 32-token, 64-wide, one-head reduction of one
Qwen3.6 full-attention decoder layer. It preserves Q/K RMSNorm, the sigmoid
attention-output gate, SwiGLU MLP, and residual structure.

Run it with:

```sh
PYTHON=.venv/bin/python ./example/llama/run.sh \
  --model-file nnc/test/qwen36_source.py
```

## Coverage result

| Qwen3.6 text-layer feature | Current NNC status |
| --- | --- |
| BF16 bias-free Linear | Supported |
| RMSNorm, including Q/K normalization | Supported through semantic custom op |
| SiLU, sigmoid, multiply, residual add | Supported |
| Full attention with equal Q/K/V head layout | Supported through semantic custom op |
| KV-cache semantic boundary | Present; smoke implementation does not retain prior tokens |
| Attention scaling and causal/additive mask | Missing from the runtime attention implementation |
| Grouped-query attention (`24` Q heads, `4` KV heads) | Missing; runtime requires equal flattened Q/K/V widths |
| Partial multimodal RoPE (`partial_rotary_factor=0.25`, theta `10,000,000`) | Missing; compiler generates full-width, theta-10,000 RoPE |
| Hybrid gated-delta/linear-attention layers | Missing compiler and runtime operators |
| Qwen zero-centred RMSNorm parameter (`1 + weight`) | Requires import-time conversion to the effective multiplier |
| Native Hugging Face graph/checkpoint import | Missing; this test mirrors the architecture with NNC semantic ops |
| Vision encoder and multimodal merge | Out of scope and unsupported |

The current compiler is sufficient for a reduced full-attention compatibility
slice, but not comprehensive enough for an unchanged Qwen3.6 text layer or
checkpoint. The first production-oriented additions should be GQA-aware scaled
causal attention, configurable partial RoPE, and a gated-delta-net semantic op.
