import pytest

from tests.reference_model import dot_product, pack_signed_lanes, signed_from_bits


def test_signed_from_bits() -> None:
    assert signed_from_bits(0x00, 8) == 0
    assert signed_from_bits(0x7F, 8) == 127
    assert signed_from_bits(0x80, 8) == -128
    assert signed_from_bits(0xFF, 8) == -1


def test_lane_packing() -> None:
    assert pack_signed_lanes([-1, 2, -128, 127]) == 0x7F8002FF


def test_dot_product_edges() -> None:
    assert dot_product([-128] * 4, [-128] * 4) == 65_536
    assert dot_product([127] * 4, [127] * 4) == 64_516
    assert dot_product([-128] * 4, [127] * 4) == -65_024


def test_model_rejects_bad_inputs() -> None:
    with pytest.raises(ValueError):
        dot_product([1, 2], [3])
    with pytest.raises(ValueError):
        pack_signed_lanes([128])
