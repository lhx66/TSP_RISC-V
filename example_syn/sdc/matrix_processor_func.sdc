
if {![info exists synopsys_program_name]} {
    set synopsys_program_name ""
}

if {${synopsys_program_name} == "pt_shell" || ${synopsys_program_name} == "gca_shell" } {
    set syno_tool    "pt"
} else {
    set syno_tool    "dc"
}
set time_scale              1.0
set time_unit_rate          1.0

#100MHz
#set clk_period          [expr $time_unit_rate*5.6*$time_scale]

#300MHz
set clk_period          [expr $time_unit_rate*3.33*$time_scale]

set setup_uncer 0.1*$time_unit_rate 
set hold_uncer  0.1*$time_unit_rate
##Clock create
create_clock -name "CLK"        [get_ports vsi_clk]         -period $clk_period     -waveform "0 [expr $clk_period/2.0]"

set_input_delay  -max [expr 0.5*$clk_period]   -clock [get_clocks "CLK"] [remove_from_collection [all_inputs] [get_ports {vsi_clk vsi_rst_n}]]
set_output_delay  -max [expr 0.1*$clk_period]   -clock [get_clocks "CLK"] [all_outputs]


set_false_path -from [get_ports "vsi_rst_n"]

set_clock_uncertainty -setup [expr $setup_uncer] [all_clocks]
set_clock_uncertainty -hold  [expr $hold_uncer] [all_clocks]
