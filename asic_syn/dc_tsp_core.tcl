# TSP_Core ASIC synthesis flow, adapted from example_syn for DC.
# Required environment: RTL_ROOT, LIB_DB, OUT_DIR, CLOCK_PERIOD (ns).

proc need_env {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        puts stderr "ERROR: environment variable $name is required"
        exit 2
    }
    return $::env($name)
}

set rtl_root     [need_env RTL_ROOT]
set lib_db       [need_env LIB_DB]
set out_dir      [need_env OUT_DIR]
set clock_period [need_env CLOCK_PERIOD]
set script_dir   [file dirname [file normalize [info script]]]

file mkdir $out_dir
define_design_lib WORK -path "$out_dir/WORK"
set search_path [list $rtl_root [file dirname $lib_db]]
set target_library [list $lib_db]
set link_library [concat * $target_library]
set synthetic_library [list dw_foundation.sldb]

set_host_options -max_cores 1
set source_files [list \
    "$rtl_root/dff.v" \
    "$rtl_root/regfiles.v" \
    "$rtl_root/PC_control.v" \
    "$rtl_root/Ifu.v" \
    "$rtl_root/idec.v" \
    "$rtl_root/exu_common.v" \
    "$rtl_root/exu_bjp.v" \
    "$rtl_root/exu_muldiv.v" \
    "$rtl_root/exu_ls.v" \
    "$rtl_root/ls_ctrl.v" \
    "$rtl_root/wb_arbiter.v" \
    "$rtl_root/disp_exu.v" \
    "$rtl_root/core.v"]
analyze -format sverilog -vcs "+incdir+$rtl_root" $source_files
elaborate TSP_Core
current_design TSP_Core
link
uniquify
check_design > "$out_dir/check_design_pre.rpt"

create_clock -name core_clk -period $clock_period [get_ports clk]
set_clock_uncertainty -setup 0.10 [get_clocks core_clk]
set_clock_uncertainty -hold 0.05 [get_clocks core_clk]
set reset_port [get_ports rst_n]
set data_inputs [remove_from_collection [all_inputs] [add_to_collection [get_ports clk] $reset_port]]
set_input_delay 0.0 -clock core_clk $data_inputs
set_output_delay 0.0 -clock core_clk [all_outputs]
set_false_path -from $reset_port
set_max_area 0
set_fix_multiple_port_nets -all -buffer_constants

compile_ultra
change_names -rules verilog -hierarchy

check_design > "$out_dir/check_design_post.rpt"
check_timing > "$out_dir/check_timing.rpt"
report_qor > "$out_dir/qor.rpt"
report_area > "$out_dir/area.rpt"
report_area -hierarchy >> "$out_dir/area.rpt"
report_reference -hierarchy > "$out_dir/reference.rpt"
report_cell > "$out_dir/cell.rpt"
report_timing -delay_type max -max_paths 20 -nets -input_pins -transition_time -capacitance > "$out_dir/timing_max.rpt"
report_timing -delay_type min -max_paths 20 -nets -input_pins -transition_time -capacitance > "$out_dir/timing_min.rpt"
report_constraints -all_violators -verbose > "$out_dir/constraints.rpt"
report_lib > "$out_dir/library.rpt"

set nand2_cells [get_lib_cells -quiet */NAND2X1H9R]
set ge_file [open "$out_dir/ge_candidates.rpt" w]
puts $ge_file "NAND2 candidate cells and library area (use one minimum-drive 2-input NAND for GE normalization):"
foreach_in_collection cell $nand2_cells {
    puts $ge_file "[get_object_name $cell] [get_attribute $cell area]"
}
close $ge_file

write -format ddc -hierarchy -output "$out_dir/TSP_Core.ddc"
write -format verilog -hierarchy -output "$out_dir/TSP_Core_gate.v"
write_sdc "$out_dir/TSP_Core.sdc"
quit
