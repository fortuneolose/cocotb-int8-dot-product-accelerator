"""Render a focused, reviewable SVG waveform from an RTL-generated VCD.

The renderer intentionally uses only the Python standard library so the same
artifact can be reproduced in CI without a desktop waveform viewer.
"""

from __future__ import annotations

import argparse
import html
import math
import re
from dataclasses import dataclass, field
from pathlib import Path


TIMESCALE_TO_NS = {
    "s": 1e9,
    "ms": 1e6,
    "us": 1e3,
    "ns": 1.0,
    "ps": 1e-3,
    "fs": 1e-6,
}


@dataclass
class VcdVariable:
    width: int
    names: list[str] = field(default_factory=list)
    changes: list[tuple[int, str]] = field(default_factory=list)


@dataclass
class VcdData:
    tick_ns: float
    variables: dict[str, VcdVariable]
    names: dict[str, str]
    end_tick: int


def parse_vcd(path: Path) -> VcdData:
    """Parse the VCD subset needed by this project's waveform renderer."""
    variables: dict[str, VcdVariable] = {}
    names: dict[str, str] = {}
    scopes: list[str] = []
    current_tick = 0
    end_tick = 0
    in_definitions = True
    header: list[str] = []

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue

            if in_definitions:
                header.append(line)
                if line.startswith("$scope"):
                    parts = line.split()
                    scopes.append(parts[2])
                elif line.startswith("$upscope"):
                    if scopes:
                        scopes.pop()
                elif line.startswith("$var"):
                    match = re.match(
                        r"\$var\s+\S+\s+(\d+)\s+(\S+)\s+(.+?)\s+\$end$",
                        line,
                    )
                    if match:
                        width = int(match.group(1))
                        identifier = match.group(2)
                        reference = match.group(3).replace(" ", "")
                        full_name = ".".join([*scopes, reference])
                        variable = variables.setdefault(identifier, VcdVariable(width))
                        variable.width = max(variable.width, width)
                        variable.names.append(full_name)
                        names[full_name] = identifier
                elif line.startswith("$enddefinitions"):
                    in_definitions = False
                continue

            if line.startswith("#"):
                current_tick = int(line[1:])
                end_tick = max(end_tick, current_tick)
                continue

            if line[0] in "01xXzZ":
                value = line[0].lower()
                identifier = line[1:]
            elif line[0] in "bB":
                parts = line.split()
                if len(parts) != 2:
                    continue
                value = parts[0][1:].lower()
                identifier = parts[1]
            else:
                continue

            variable = variables.get(identifier)
            if variable is None:
                continue
            if not variable.changes or variable.changes[-1][1] != value:
                variable.changes.append((current_tick, value))

    joined_header = " ".join(header)
    match = re.search(r"\$timescale\s+(\d+)\s*(s|ms|us|ns|ps|fs)\s+\$end", joined_header)
    if not match:
        raise ValueError(f"No supported $timescale declaration in {path}")
    tick_ns = int(match.group(1)) * TIMESCALE_TO_NS[match.group(2)]
    return VcdData(tick_ns, variables, names, end_tick)


def _find_identifier(data: VcdData, suffix: str) -> str:
    exact = f"tb_dot_product_showcase.{suffix}"
    if exact in data.names:
        return data.names[exact]
    matches = [(name, identifier) for name, identifier in data.names.items() if name.endswith(suffix)]
    if not matches:
        raise KeyError(f"Signal ending in '{suffix}' is absent from the VCD")
    matches.sort(key=lambda item: (item[0].count("."), len(item[0])))
    return matches[0][1]


def _value_at(changes: list[tuple[int, str]], tick: int) -> str:
    value = "x"
    for change_tick, changed_value in changes:
        if change_tick > tick:
            break
        value = changed_value
    return value


def _segments(changes: list[tuple[int, str]], start: int, end: int) -> list[tuple[int, int, str]]:
    points = [(start, _value_at(changes, start))]
    points.extend((tick, value) for tick, value in changes if start < tick < end)
    return [
        (tick, points[index + 1][0] if index + 1 < len(points) else end, value)
        for index, (tick, value) in enumerate(points)
    ]


def _format_vector(value: str, width: int, radix: str) -> str:
    if any(bit not in "01" for bit in value):
        return "X"
    integer = int(value, 2)
    if radix == "signed":
        sign_bit = 1 << (width - 1)
        integer = integer - (1 << width) if integer & sign_bit else integer
        return str(integer)
    digits = math.ceil(width / 4)
    return f"0x{integer:0{digits}X}"


def render_svg(
    data: VcdData,
    output: Path,
    start_ns: float,
    end_ns: float,
) -> None:
    """Render the project showcase signals over the selected time window."""
    if end_ns <= start_ns:
        raise ValueError("end time must be greater than start time")

    signal_specs = [
        ("clk", "clk", "bit"),
        ("rst_n", "rst_n", "bit"),
        ("in_valid", "in_valid", "bit"),
        ("in_ready", "in_ready", "bit"),
        ("a_vec[31:0]", "a_vec[31:0]", "hex"),
        ("b_vec[31:0]", "b_vec[31:0]", "hex"),
        ("products_valid", "dut.products_valid_q", "bit"),
        ("result_valid", "dut.result_valid_q", "bit"),
        ("out_valid", "out_valid", "bit"),
        ("out_ready", "out_ready", "bit"),
        ("out_data[17:0]", "out_data[17:0]", "signed"),
    ]

    selected: list[tuple[str, VcdVariable, str]] = []
    for label, suffix, radix in signal_specs:
        identifier = _find_identifier(data, suffix)
        selected.append((label, data.variables[identifier], radix))

    start_tick = round(start_ns / data.tick_ns)
    end_tick = round(end_ns / data.tick_ns)
    if start_tick > data.end_tick:
        raise ValueError("selected window starts after the VCD ends")
    end_tick = min(end_tick, data.end_tick)
    end_ns = end_tick * data.tick_ns

    width = 1600
    left = 220
    right = 28
    top = 142
    row_height = 46
    bottom = 42
    height = top + row_height * len(selected) + bottom
    plot_width = width - left - right

    def x_for_tick(tick: int) -> float:
        return left + (tick - start_tick) * plot_width / (end_tick - start_tick)

    def esc(value: str) -> str:
        return html.escape(value, quote=True)

    svg: list[str] = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">',
        '<title id="title">Signed INT8 dot-product RTL showcase waveform</title>',
        '<desc id="desc">Actual Icarus Verilog simulation waveform showing the two-stage '
        'ready-valid pipeline, signed results, and output backpressure.</desc>',
        '<rect width="100%" height="100%" fill="#0b1020"/>',
        '<style>text{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}'
        '.label{fill:#d7e0f0;font-size:15px}.small{fill:#93a4be;font-size:13px}'
        '.bus{fill:#e8eef8;font-size:13px}.title{fill:#f8fafc;font-size:24px;font-weight:700}'
        '.grid{stroke:#27324a;stroke-width:1}.wave{stroke:#47d18c;stroke-width:2;fill:none}'
        '.unknown{stroke:#f87171;stroke-width:2;fill:none}.separator{stroke:#202a40;stroke-width:1}'
        '</style>',
        '<text class="title" x="24" y="38">Signed INT8 dot-product — RTL showcase</text>',
        f'<text class="small" x="24" y="66">Icarus-generated VCD · '
        f'{start_ns:g}–{end_ns:g} ns · 10 ns clock · signed decimal output</text>',
        '<text class="small" x="24" y="88">A low out_ready interval demonstrates stable '
        'out_data and propagated backpressure.</text>',
    ]

    grid_step = 10
    first_grid = math.ceil(start_ns / grid_step) * grid_step
    grid = first_grid
    while grid <= end_ns + 1e-9:
        x = left + (grid - start_ns) * plot_width / (end_ns - start_ns)
        svg.append(f'<line class="grid" x1="{x:.2f}" y1="{top - 20}" x2="{x:.2f}" y2="{height - bottom}"/>')
        svg.append(f'<text class="small" x="{x + 4:.2f}" y="{top - 28}">{grid:g} ns</text>')
        grid += grid_step

    for index, (label, variable, radix) in enumerate(selected):
        row_top = top + index * row_height
        center = row_top + row_height / 2
        svg.append(
            f'<rect x="0" y="{row_top}" width="{width}" height="{row_height}" '
            f'fill="{"#10172a" if index % 2 == 0 else "#0d1425"}"/>'
        )
        svg.append(f'<line class="separator" x1="0" y1="{row_top + row_height}" x2="{width}" y2="{row_top + row_height}"/>')
        svg.append(f'<text class="label" x="24" y="{center + 5:.2f}">{esc(label)}</text>')

        segments = _segments(variable.changes, start_tick, end_tick)
        if radix == "bit":
            low_y = center + 11
            high_y = center - 11
            path_parts: list[str] = []
            unknown_parts: list[str] = []
            for segment_index, (segment_start, segment_end, value) in enumerate(segments):
                x1 = x_for_tick(segment_start)
                x2 = x_for_tick(segment_end)
                if value == "1":
                    y = high_y
                elif value == "0":
                    y = low_y
                else:
                    y = center
                target = unknown_parts if value not in {"0", "1"} else path_parts
                target.append(f'M {x1:.2f} {y:.2f} H {x2:.2f}')
                if segment_index + 1 < len(segments):
                    next_value = segments[segment_index + 1][2]
                    next_y = high_y if next_value == "1" else low_y if next_value == "0" else center
                    target.append(f'M {x2:.2f} {y:.2f} V {next_y:.2f}')
            if path_parts:
                svg.append(f'<path class="wave" d="{" ".join(path_parts)}"/>')
            if unknown_parts:
                svg.append(f'<path class="unknown" d="{" ".join(unknown_parts)}"/>')
        else:
            for segment_index, (segment_start, segment_end, value) in enumerate(segments):
                x1 = x_for_tick(segment_start)
                x2 = x_for_tick(segment_end)
                fill = "#14233a" if segment_index % 2 == 0 else "#172b40"
                svg.append(
                    f'<rect x="{x1:.2f}" y="{center - 14:.2f}" width="{max(0.8, x2 - x1):.2f}" '
                    f'height="28" rx="3" fill="{fill}" stroke="#4c6a88"/>'
                )
                rendered = _format_vector(value, variable.width, radix)
                if x2 - x1 >= 46:
                    svg.append(
                        f'<text class="bus" x="{(x1 + x2) / 2:.2f}" y="{center + 5:.2f}" '
                        f'text-anchor="middle">{esc(rendered)}</text>'
                    )

    svg.append('</svg>')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(svg) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("vcd", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--start-ns", type=float, default=30.0)
    parser.add_argument("--end-ns", type=float, default=270.0)
    args = parser.parse_args()
    render_svg(parse_vcd(args.vcd), args.output, args.start_ns, args.end_ns)
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
