export DESIGN_NAME = dot_product_int8_vivado
export PLATFORM    = nangate45
export VERILOG_FILES = /work/rtl/dot_product_int8_vivado.v
export SDC_FILE      = /work/physical-design/constraints/dot_product_int8.sdc
export CORE_UTILIZATION ?= 40
export PLACE_DENSITY_LB_ADDON = 0.10
export SYNTH_REPEATABLE_BUILD ?= 1
export PDN_TCL ?= $(FLOW_HOME)/designs/nangate45/gcd/grid_strategy-M1-M4-M7.tcl
export TNS_END_PERCENT = 100

# Use the standard ORFS synthesis flow plus a structural-netlist
# compatibility pass for OpenSTA.
export SYNTH_SCRIPT = /work/physical-design/scripts/synth_opensta_compat.tcl
