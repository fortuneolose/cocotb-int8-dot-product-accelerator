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
COMPILE_ARGS += -g2012
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

.PHONY: unit
unit:
	python -m pytest tests/test_reference_model.py
