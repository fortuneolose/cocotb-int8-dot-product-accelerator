#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VCD="${ROOT}/artifacts/waves/dot_product.vcd"
SAVE="${ROOT}/gtkwave/dot_product.gtkw"
OUTPUT="${ROOT}/docs/gtkwave-waveform.png"

if [[ ! -f "${VCD}" ]]; then
    echo "Missing ${VCD}; run 'make SIM=icarus WAVES=1' first." >&2
    exit 1
fi

xvfb-run -a --server-args="-screen 0 1600x900x24" \
    bash -c '
        set -e
        gtkwave "$1" "$2" >/tmp/gtkwave-capture.log 2>&1 &
        gtkwave_pid=$!
        trap "kill ${gtkwave_pid} 2>/dev/null || true" EXIT
        sleep 4
        import -window root "$3"
    ' _ "${VCD}" "${SAVE}" "${OUTPUT}"

echo "Wrote ${OUTPUT}"
