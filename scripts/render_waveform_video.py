"""Render a compact waveform and datapath walkthrough for repository review.

The native Vivado WDB is the signal-level source of truth. This animation is a
portable companion that makes the ready/valid behavior and the main hardware
blocks easy to understand without requiring a Vivado GUI session.
"""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FFMpegWriter
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Rectangle


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "media" / "int8_dot_product_waveform_showcase.mp4"
END_NS = 345.0
FPS = 24
FRAMES = 288

RESULTS = [
    (75.0, 70),
    (95.0, 65536),
    (115.0, -70),
    (205.0, -32510),
    (215.0, -540),
    (225.0, 64516),
    (245.0, 0),
]

OUT_WINDOWS = [
    (70.0, 80.0, 70),
    (90.0, 100.0, 65536),
    (110.0, 120.0, -70),
    (135.0, 200.0, -32510),
    (200.0, 210.0, -32510),
    (210.0, 220.0, -540),
    (220.0, 230.0, 64516),
    (240.0, 250.0, 0),
]

IN_PULSES = [25.0, 35.0, 45.0, 55.0, 65.0, 145.0, 155.0, 165.0, 175.0]


def high_for_interval(t, start, end):
    return start <= t < end


def pulse_signal(times, starts, width=5.0):
    return [
        1 if any(high_for_interval(t, start, start + width) for start in starts) else 0
        for t in times
    ]


def interval_signal(times, intervals):
    return [
        1 if any(high_for_interval(t, start, end) for start, end in intervals) else 0
        for t in times
    ]


def draw_block(ax, x, y, width, height, label, subtitle, active=False):
    edge = "#f4c95d" if active else "#6d7b99"
    face = "#3b4260" if active else "#222a44"
    block = FancyBboxPatch(
        (x, y),
        width,
        height,
        boxstyle="round,pad=0.012,rounding_size=0.02",
        linewidth=2.2 if active else 1.2,
        edgecolor=edge,
        facecolor=face,
    )
    ax.add_patch(block)
    ax.text(
        x + width / 2,
        y + height * 0.61,
        label,
        color="#f7f8fb",
        ha="center",
        va="center",
        fontsize=10,
        fontweight="bold",
    )
    ax.text(
        x + width / 2,
        y + height * 0.28,
        subtitle,
        color="#b8c2d8",
        ha="center",
        va="center",
        fontsize=7.7,
    )


def draw_arrow(ax, x1, y1, x2, y2):
    ax.add_patch(
        FancyArrowPatch(
            (x1, y1),
            (x2, y2),
            arrowstyle="-|>",
            mutation_scale=13,
            linewidth=1.5,
            color="#83d5ff",
        )
    )


def architecture_status(t):
    if t < 15:
        return "reset asserted"
    if 130 <= t < 200:
        return "consumer stalled: result held stable"
    if 200 <= t < 250:
        return "backpressure released: queued results drain"
    return "streaming ready/valid traffic"


def draw_architecture(ax, t):
    ax.clear()
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")
    ax.set_title(
        "INT8 dot-product datapath  |  four lanes, signed products, 18-bit sum",
        loc="left",
        color="#f7f8fb",
        fontsize=13,
        fontweight="bold",
        pad=10,
    )

    active = [
        t < 25,
        25 <= t < 100 or 200 <= t < 230,
        45 <= t < 125 or 200 <= t < 235,
        70 <= t < 150 or 200 <= t < 245,
        t >= 70,
    ]
    blocks = [
        (0.03, 0.34, 0.16, 0.31, "Packed a_vec / b_vec", "lane 0..3, INT8"),
        (0.24, 0.34, 0.17, 0.31, "Unpack + sign", "two's complement"),
        (0.47, 0.34, 0.17, 0.31, "4 × multipliers", "8-bit × 8-bit"),
        (0.70, 0.17, 0.16, 0.48, "Adder tree", "sign-extend to 18b"),
        (0.89, 0.34, 0.08, 0.31, "Result", "ready / valid"),
    ]
    for index, (x, y, width, height, label, subtitle) in enumerate(blocks):
        draw_block(ax, x, y, width, height, label, subtitle, active=active[index])

    draw_arrow(ax, 0.19, 0.50, 0.24, 0.50)
    draw_arrow(ax, 0.41, 0.50, 0.47, 0.50)
    draw_arrow(ax, 0.64, 0.50, 0.70, 0.50)
    draw_arrow(ax, 0.86, 0.50, 0.89, 0.50)

    ax.text(
        0.50,
        0.09,
        architecture_status(t),
        ha="center",
        va="center",
        color="#f4c95d",
        fontsize=10,
        fontweight="bold",
    )
    ax.text(
        0.50,
        0.02,
        "Two elastic registered stages let the output hold steady when out_ready is low.",
        ha="center",
        va="center",
        color="#b8c2d8",
        fontsize=8.5,
    )


def draw_digital(ax, times, values, y, color="#83d5ff"):
    ax.step(times, y + 0.30 * np.asarray(values), where="post", color=color, linewidth=1.8)


def draw_waveform(ax, t):
    ax.clear()
    times = np.linspace(0.0, END_NS, 1381)
    clock = [1 if (time % 10.0) < 5.0 else 0 for time in times]
    reset_n = [1 if time >= 15.0 else 0 for time in times]
    in_valid = pulse_signal(times, IN_PULSES, width=5.0)
    in_ready = [0 if 145.0 <= time < 190.0 else 1 for time in times]
    out_valid = interval_signal(times, [(start, end) for start, end, _ in OUT_WINDOWS])
    out_ready = [0 if 130.0 <= time < 200.0 else 1 for time in times]

    rows = [
        ("clk", clock),
        ("rst_n", reset_n),
        ("in_valid", in_valid),
        ("in_ready", in_ready),
        ("out_valid", out_valid),
        ("out_ready", out_ready),
    ]
    row_y = {name: 5.8 - index for index, (name, _) in enumerate(rows)}

    ax.set_facecolor("#11172b")
    ax.set_xlim(0, END_NS)
    ax.set_ylim(-0.25, 6.35)
    ax.set_yticks([row_y[name] + 0.12 for name, _ in rows])
    ax.set_yticklabels([name for name, _ in rows], color="#e8edf7", fontsize=8.5)
    ax.tick_params(axis="y", length=0, pad=8)
    ax.tick_params(axis="x", colors="#b8c2d8", labelsize=8)
    ax.set_xlabel("simulation time (ns)", color="#b8c2d8", fontsize=8.5)
    ax.set_title(
        "Vivado-style ready/valid waveform  |  output data bus",
        loc="left",
        color="#f7f8fb",
        fontsize=12,
        fontweight="bold",
        pad=8,
    )
    ax.grid(axis="x", color="#293452", linewidth=0.7, alpha=0.85)

    for name, values in rows:
        y = row_y[name]
        ax.axhline(y, color="#293452", linewidth=0.7)
        draw_digital(ax, times, values, y)

    bus_y = -0.05
    ax.axhline(bus_y, color="#293452", linewidth=0.7)
    ax.text(-4.0, bus_y + 0.15, "out_data", color="#e8edf7", fontsize=8.5, ha="right")
    for start, end, value in OUT_WINDOWS:
        visible_end = min(end, END_NS)
        if visible_end <= 0:
            continue
        patch = Rectangle(
            (start, bus_y - 0.22),
            visible_end - start,
            0.44,
            linewidth=0.8,
            edgecolor="#83d5ff",
            facecolor="#243c5a",
        )
        ax.add_patch(patch)
        ax.text(
            start + (visible_end - start) / 2,
            bus_y,
            str(value),
            color="#f7f8fb",
            ha="center",
            va="center",
            fontsize=7.3,
            clip_on=True,
        )

    ax.axvline(t, color="#f4c95d", linewidth=1.2, alpha=0.95)
    ax.text(
        t,
        6.2,
        f"{t:5.1f} ns",
        color="#f4c95d",
        ha="center",
        va="top",
        fontsize=8,
    )
    ax.text(
        END_NS - 2,
        6.2,
        architecture_status(t),
        color="#f4c95d",
        ha="right",
        va="top",
        fontsize=8.5,
        fontweight="bold",
    )


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    fig = plt.figure(figsize=(14, 8), facecolor="#11172b")
    grid = fig.add_gridspec(2, 1, height_ratios=[1.0, 1.25], hspace=0.18)
    architecture_ax = fig.add_subplot(grid[0])
    waveform_ax = fig.add_subplot(grid[1])
    fig.subplots_adjust(left=0.09, right=0.98, top=0.96, bottom=0.09)

    writer = FFMpegWriter(
        fps=FPS,
        codec="libx264",
        bitrate=2200,
        extra_args=["-pix_fmt", "yuv420p", "-movflags", "+faststart"],
    )
    with writer.saving(fig, str(OUTPUT), dpi=100):
        for frame in range(FRAMES):
            time_ns = END_NS * frame / (FRAMES - 1)
            draw_architecture(architecture_ax, time_ns)
            draw_waveform(waveform_ax, time_ns)
            writer.grab_frame()

    plt.close(fig)
    print(f"Rendered {OUTPUT}")


if __name__ == "__main__":
    main()
