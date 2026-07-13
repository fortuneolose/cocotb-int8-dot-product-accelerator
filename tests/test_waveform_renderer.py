from pathlib import Path

from tools.render_waveform import _format_vector, parse_vcd


def test_parse_minimal_vcd(tmp_path: Path) -> None:
    vcd = tmp_path / "minimal.vcd"
    vcd.write_text(
        """$timescale 1ps $end
$scope module tb_dot_product_showcase $end
$var wire 1 ! clk $end
$upscope $end
$enddefinitions $end
#0
0!
#5000
1!
""",
        encoding="utf-8",
    )

    parsed = parse_vcd(vcd)
    assert parsed.tick_ns == 0.001
    assert parsed.end_tick == 5000
    assert parsed.variables["!"].changes == [(0, "0"), (5000, "1")]


def test_vector_formatting() -> None:
    assert _format_vector("0001000110", 10, "hex") == "0x046"
    assert _format_vector("1111111111111110111010", 22, "signed") == "-70"
