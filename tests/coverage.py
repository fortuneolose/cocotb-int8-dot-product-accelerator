"""Small dependency-free functional coverage collector."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class FunctionalCoverage:
    input_classes: set[str] = field(default_factory=set)
    result_signs: set[str] = field(default_factory=set)
    result_magnitudes: set[str] = field(default_factory=set)
    samples: int = 0
    accepted_outputs: int = 0
    backpressure_cycles: int = 0
    input_stall_cycles: int = 0
    consecutive_accepts: int = 0
    max_scoreboard_depth: int = 0
    _previous_input_accepted: bool = False

    def sample_input(self, a: list[int], b: list[int], result: int) -> None:
        values = a + b
        self.samples += 1
        if all(value == 0 for value in values):
            self.input_classes.add("all_zero")
        if any(value == 0 for value in values):
            self.input_classes.add("contains_zero")
        if any(value in (-128, 127) for value in values):
            self.input_classes.add("contains_int8_extreme")
        if any(value < 0 for value in values) and any(value > 0 for value in values):
            self.input_classes.add("mixed_sign_values")
        if all(value >= 0 for value in values):
            self.input_classes.add("all_nonnegative")
        if all(value <= 0 for value in values):
            self.input_classes.add("all_nonpositive")

        self.result_signs.add("negative" if result < 0 else "positive" if result > 0 else "zero")
        magnitude = abs(result)
        if magnitude == 0:
            self.result_magnitudes.add("zero")
        elif magnitude <= 255:
            self.result_magnitudes.add("small_1_255")
        elif magnitude <= 16_383:
            self.result_magnitudes.add("medium_256_16383")
        else:
            self.result_magnitudes.add("large_16384_plus")

    def sample_cycle(
        self,
        *,
        input_accepted: bool,
        output_accepted: bool,
        output_blocked: bool,
        input_blocked: bool,
        scoreboard_depth: int,
    ) -> None:
        if input_accepted and self._previous_input_accepted:
            self.consecutive_accepts += 1
        self._previous_input_accepted = input_accepted
        self.accepted_outputs += int(output_accepted)
        self.backpressure_cycles += int(output_blocked)
        self.input_stall_cycles += int(input_blocked)
        self.max_scoreboard_depth = max(self.max_scoreboard_depth, scoreboard_depth)

    def as_dict(self) -> dict[str, object]:
        return {
            "samples": self.samples,
            "accepted_outputs": self.accepted_outputs,
            "input_classes": sorted(self.input_classes),
            "result_signs": sorted(self.result_signs),
            "result_magnitudes": sorted(self.result_magnitudes),
            "protocol": {
                "backpressure_cycles": self.backpressure_cycles,
                "input_stall_cycles": self.input_stall_cycles,
                "consecutive_accepts": self.consecutive_accepts,
                "max_scoreboard_depth": self.max_scoreboard_depth,
            },
        }

    def write_json(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.as_dict(), indent=2) + "\n", encoding="utf-8")
