set tbname tb_pc_control_no_btb
if {![file isdirectory work]} { vlib work }
if {![file isdirectory log]} { file mkdir log }
vmap work work

vlog -sv -incr -work work -override_timescale 1ns/10ps -f modelsim_filelist.f -l ./log/vlog_pc_control_no_btb.log
if {[catch {vopt +acc +nospecify work.$tbname -o voptsim_pc_control_no_btb -l ./log/vopt_pc_control_no_btb.log} result]} {
    puts stderr "[TB_ERROR] vopt failed: $result"
    quit -code 1 -f
}
if {[catch {vsim -c +nospecify voptsim_pc_control_no_btb -l ./log/vsim_pc_control_no_btb.log -do "run -all; quit -f"} result]} {
    puts stderr [format {[TB_ERROR] vsim failed: %s} $result]
    quit -code 1 -f
}
quit -code 0 -f
