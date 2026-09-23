"""Pack static model weights and operator constants into a binary payload."""

from __future__ import annotations

import math
import struct
from dataclasses import dataclass

import torch

from nnc.graph import TensorSpec


@dataclass(frozen=True)
class WeightRecord:
    tensor: TensorSpec
    offset: int
    nbytes: int
    ctype: str


class WeightStore:
    def __init__(self, parameters: dict[str, torch.Tensor]) -> None:
        self.parameters = parameters
        self.records: dict[str, WeightRecord] = {}
        self.data = bytearray()
        self.cursor = 0

    def use(self, tensor: TensorSpec, ctype: str = "dtype") -> None:
        if tensor.name in self.records:
            return
        payload = self.weight_bytes(tensor, ctype)
        self.use_payload(tensor, payload, ctype)

    def use_payload(self, tensor: TensorSpec, payload: bytes, ctype: str = "dtype") -> None:
        if tensor.name in self.records:
            return
        nbytes = len(payload)
        self.records[tensor.name] = WeightRecord(tensor, self.cursor, nbytes, ctype)
        self.data.extend(payload)
        self.cursor += nbytes

    def use_rope_table(self, name: str, max_seq_len: int, dim: int) -> TensorSpec:
        if dim % 8 != 0:
            raise SystemExit(f"Tensor RoPE dim must be a multiple of 8, got {dim}")
        shape = (max_seq_len, dim // 8, 8, 8)
        tensor = TensorSpec(name, shape, "synthetic")
        if name not in self.records:
            self.use_payload(tensor, self.rope_table_bytes(max_seq_len, dim))
        return tensor

    def use_eye8(self, name: str) -> TensorSpec:
        tensor = TensorSpec(name, (8, 8), "synthetic")
        if name not in self.records:
            self.use_payload(tensor, self.eye8_bytes())
        return tensor

    def use_rms_diag(self, name: str, weight: TensorSpec) -> TensorSpec:
        if len(weight.shape) != 1 or weight.shape[0] % 8 != 0:
            raise SystemExit(f"Tensor RMSNorm weight must be 1-D and a multiple of 8: {weight.shape}")
        tensor = TensorSpec(name, (weight.shape[0] // 8, 8, 8), "synthetic")
        if name not in self.records:
            self.use_payload(tensor, self.rms_diag_bytes(weight))
        return tensor

    def use_rms_square_mean(self, name: str, cols: int) -> TensorSpec:
        if cols <= 0 or cols % 8 != 0:
            raise SystemExit(f"Tensor RMSNorm width must be a positive multiple of 8: {cols}")
        tensor = TensorSpec(name, (8, 8), "synthetic")
        if name not in self.records:
            values = torch.eye(8, dtype=torch.float32) / float(cols)
            self.use_payload(tensor, self.bf16_bytes(values))
        return tensor

    def use_rms_reduce_sum8(self, name: str) -> TensorSpec:
        tensor = TensorSpec(name, (8, 8), "synthetic")
        if name not in self.records:
            values = torch.ones((8, 8), dtype=torch.float32)
            self.use_payload(tensor, self.bf16_bytes(values))
        return tensor

    def weight_bytes(self, tensor: TensorSpec, ctype: str) -> bytes:
        try:
            value = self.parameters[tensor.target]
        except KeyError as exc:
            raise SystemExit(f"missing parameter tensor: {tensor.target}") from exc
        if ctype == "int8_t":
            return self.q8_bytes(value)
        if value.ndim == 2 and value.shape[0] % 8 == 0 and value.shape[1] % 8 == 0:
            return self.bf16_packed_tile_bytes(value)
        bf16 = value.detach().to(torch.bfloat16).contiguous().view(torch.int16).flatten()
        return struct.pack(f"<{bf16.numel()}H", *(int(item) & 0xffff for item in bf16.tolist()))

    def rms_diag_bytes(self, tensor: TensorSpec) -> bytes:
        try:
            value = self.parameters[tensor.target]
        except KeyError as exc:
            raise SystemExit(f"missing RMSNorm weight tensor: {tensor.target}") from exc
        if value.ndim != 1 or value.numel() % 8 != 0:
            raise SystemExit(f"Tensor RMSNorm weight must be 1-D and a multiple of 8: {tuple(value.shape)}")
        blocks = int(value.numel()) // 8
        diagonal = torch.zeros((blocks, 8, 8), dtype=torch.float32)
        bf16_weight = value.detach().to(torch.bfloat16).to(torch.float32)
        for block in range(blocks):
            for lane in range(8):
                diagonal[block, lane, lane] = bf16_weight[block * 8 + lane]
        return self.bf16_bytes(diagonal)

    @staticmethod
    def bf16_bytes(value: torch.Tensor) -> bytes:
        bf16 = value.to(torch.bfloat16).contiguous().view(torch.int16).flatten()
        bits = [int(item) & 0xffff for item in bf16.tolist()]
        return struct.pack(f"<{len(bits)}H", *bits)

    @staticmethod
    def rope_table_bytes(max_seq_len: int, dim: int) -> bytes:
        values: list[float] = []
        dim_blocks = dim // 8
        for pos in range(max_seq_len):
            for block in range(dim_blocks):
                tile = [[0.0 for _ in range(8)] for _ in range(8)]
                for local_pair in range(4):
                    pair = block * 4 + local_pair
                    theta = 1.0 / (10000.0 ** ((2.0 * pair) / float(dim)))
                    angle = float(pos) * theta
                    cos_value = math.cos(angle)
                    sin_value = math.sin(angle)
                    row = local_pair * 2
                    col = local_pair * 2
                    tile[row][col] = cos_value
                    tile[row][col + 1] = -sin_value
                    tile[row + 1][col] = sin_value
                    tile[row + 1][col + 1] = cos_value
                for row in range(8):
                    values.extend(tile[row])
        bf16 = torch.tensor(values, dtype=torch.float32).to(torch.bfloat16)
        bits = bf16.contiguous().view(torch.int16).flatten().tolist()
        return struct.pack(f"<{len(bits)}H", *(int(item) & 0xffff for item in bits))

    @staticmethod
    def eye8_bytes() -> bytes:
        values = torch.eye(8, dtype=torch.float32).to(torch.bfloat16)
        bits = values.contiguous().view(torch.int16).flatten().tolist()
        return struct.pack("<64H", *(int(item) & 0xffff for item in bits))

    @staticmethod
    def bf16_packed_tile_bytes(value: torch.Tensor) -> bytes:
        if value.ndim != 2 or value.shape[0] % 8 != 0 or value.shape[1] % 8 != 0:
            raise SystemExit(f"BF16 tiled linear weight must be PxQ with P,Q multiple of 8: {tuple(value.shape)}")
        p, q = (int(value.shape[0]), int(value.shape[1]))
        bf16 = value.detach().to(torch.bfloat16).contiguous()
        tiled = bf16.reshape(p // 8, 8, q // 8, 8).permute(0, 2, 1, 3).contiguous()
        packed = [int(item) & 0xffff for item in tiled.view(torch.int16).flatten().tolist()]
        return struct.pack(f"<{len(packed)}H", *packed)

    @staticmethod
    def q8_bytes(value: torch.Tensor) -> bytes:
        quant = value.detach().round().clamp(-128, 127).to(torch.int8).contiguous()
        if tuple(quant.shape) == (64, 64):
            packed: list[int] = []
            for out_blk in range(8):
                for k_blk in range(8):
                    for out_lane in range(8):
                        for k_lane in range(8):
                            packed.append(int(quant[out_blk * 8 + out_lane, k_blk * 8 + k_lane]))
            return struct.pack("<4096b", *packed)
        quant = quant.flatten()
        return struct.pack(f"<{quant.numel()}b", *(int(item) for item in quant.tolist()))
