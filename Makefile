SIM ?= icarus
TOPLEVEL_LANG := verilog
TOPLEVEL := dot_product_int8
MODULE := tests.test_dot_product

# Cocotb's Icarus makefile selects FST when WAVES=1. Preserve that familiar
# interface while using the DUT's explicit, portable VCD dump instead.
REQUESTED_WAVES := $(WAVES)
override WAVES := 0

PROJECT_ROOT := $(abspath .)
VERILOG_SOURCES := $(PROJECT_ROOT)/rtl/dot_product_int8.sv
COMPILE_ARGS += -Wall

ifeq ($(SIM),icarus)
# Icarus does not consistently implement SystemVerilog immediate assertions;
# the cocotb test duplicates the blocked-output protocol checks.
COMPILE_ARGS += -g2012 -DSYNTHESIS
ifeq ($(REQUESTED_WAVES),1)
COMPILE_ARGS += -DDUMP_WAVES
endif
endif

ifeq ($(SIM),verilator)
COMPILE_ARGS += --Wno-fatal
endif

export PYTHONPATH := $(PROJECT_ROOT):$(PYTHONPATH)
export COCOTB_RESULTS_FILE := results.xml

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: unit vivado-rtl-smoke vivado-equivalence showcase-waveform
unit:
	python -m pytest tests/test_reference_model.py tests/test_waveform_renderer.py

# Simulator-independent smoke test for the plain-Verilog Vivado translation.
# Vivado XSIM uses the same RTL and testbench through vivado/create_project.tcl.
vivado-rtl-smoke:
	mkdir -p sim_build/vivado-rtl
	iverilog -g2012 -Wall -s tb_dot_product_int8_vivado \
		-o sim_build/vivado-rtl/dot_product.vvp \
		rtl/dot_product_int8_vivado.v \
		vivado/tb_dot_product_int8_vivado.sv
	vvp sim_build/vivado-rtl/dot_product.vvp | tee sim_build/vivado-rtl/simulation.log
	grep -q "VIVADO RTL PASS" sim_build/vivado-rtl/simulation.log

vivado-equivalence:
	mkdir -p sim_build/vivado-equivalence
	iverilog -g2012 -Wall -DSYNTHESIS -s tb_dot_product_equivalence \
		-o sim_build/vivado-equivalence/equivalence.vvp \
		rtl/dot_product_int8.sv \
		rtl/dot_product_int8_vivado.v \
		vivado/tb_dot_product_equivalence.sv
	vvp sim_build/vivado-equivalence/equivalence.vvp \
		| tee sim_build/vivado-equivalence/simulation.log
	grep -q "VIVADO EQUIVALENCE PASS" \
		sim_build/vivado-equivalence/simulation.log

# Focused, deterministic RTL waveform suitable for documentation and review.
showcase-waveform:
	mkdir -p sim_build/showcase artifacts/waves docs
	iverilog -g2012 -Wall -DSYNTHESIS -DDUMP_SHOWCASE_WAVES \
		-s tb_dot_product_showcase \
		-o sim_build/showcase/showcase.vvp \
		rtl/dot_product_int8.sv \
		vivado/tb_dot_product_showcase.sv
	vvp sim_build/showcase/showcase.vvp \
		| tee sim_build/showcase/simulation.log
	grep -q "VIVADO XSIM SHOWCASE PASS" \
		sim_build/showcase/simulation.log
	python tools/render_waveform.py \
		artifacts/waves/showcase.vcd docs/showcase-waveform.svg \
		--start-ns 30 --end-ns 270
