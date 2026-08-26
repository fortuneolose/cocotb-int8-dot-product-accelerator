# Run the standard ORFS Yosys synthesis flow first.
source $::env(FLOW_HOME)/scripts/synth.tcl

# OpenSTA's structural Verilog parser does not accept the `signed`
# qualifier emitted by Yosys on mapped port/net declarations.
#
# Signed arithmetic has already been resolved into structural cells
# during synthesis. This post-process therefore changes declaration
# syntax only; it does not modify the source RTL or arithmetic logic.

set netlist "$::env(RESULTS_DIR)/1_2_yosys.v"

if {![file exists $netlist]} {
    error "OpenSTA compatibility: mapped netlist not found: $netlist"
}

set fh [open $netlist r]
set data [read $fh]
close $fh

set count [regsub -all {\msigned\M[ \t]+} $data {} data]

set fh [open $netlist w]
puts -nonewline $fh $data
close $fh

puts "OpenSTA compatibility: removed $count signed qualifier(s) from $netlist"
