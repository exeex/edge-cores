"""Find the last use of each temporary tensor for runtime frees."""

from __future__ import annotations

from nnc.graph import LoweredNode, LoweredProgram


class Liveness:
    def __init__(self, program: LoweredProgram) -> None:
        self.temp_names = {output.name for node in program.nodes for output in node.outputs}
        self.last_use = self.compute_last_use(program)

    def compute_last_use(self, program: LoweredProgram) -> dict[str, int]:
        last: dict[str, int] = {}
        for index, node in enumerate(program.nodes):
            for arg in node.args:
                if arg in self.temp_names:
                    last[arg] = index
        last[program.output] = len(program.nodes)
        return last

    def frees_after(self, index: int, node: LoweredNode) -> list[str]:
        return [
            arg for arg in node.args
            if arg in self.temp_names and self.last_use.get(arg) == index
        ]
