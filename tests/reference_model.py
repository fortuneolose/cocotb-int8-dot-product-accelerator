"""Pure-Python golden model and bit-packing helpers."""

from collections.abc import Iterable, Sequence


def signed_from_bits(value: int, width: int) -> int:
    """Interpret ``value`` as a width-bit two's-complement integer."""
    mask = (1 << width) - 1
    value &= mask
    sign_bit = 1 << (width - 1)
    return value - (1 << width) if value & sign_bit else value


def pack_signed_lanes(values: Iterable[int], width: int = 8) -> int:
    """Pack lane zero into the least-significant slice of a flat HDL vector."""
    packed = 0
    mask = (1 << width) - 1
    for lane, value in enumerate(values):
        minimum = -(1 << (width - 1))
        maximum = (1 << (width - 1)) - 1
        if not minimum <= value <= maximum:
            raise ValueError(f"lane {lane}: {value} is outside [{minimum}, {maximum}]")
        packed |= (value & mask) << (lane * width)
    return packed


def dot_product(a: Sequence[int], b: Sequence[int]) -> int:
    """Return a full-precision signed dot product."""
    if len(a) != len(b):
        raise ValueError("input vectors must have the same number of lanes")
    return sum(lhs * rhs for lhs, rhs in zip(a, b, strict=True))
