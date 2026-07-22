set tbname tb_ls_ctrl_unaligned

if {![file isdirectory work]} { vlib work }
if {![file isdirectory log]} { file mkdir log }
vmap work work

vlog -sv -incr -work work -override_timescale 1ns/10ps -f modelsim_filelist.f -l ./log/vlog.log
if {[catch {vopt +acc +nospecify work.$tbname -o voptsim -l ./log/vopt.log} result]} {
    puts stderr "[TB_ERROR] vopt failed: $result"
    quit -code 1 -f
}
if {[catch {vsim -c +nospecify voptsim -l ./log/vsim.log -do "run -all; quit -f"} result]} {
    puts stderr [format {[TB_ERROR] vsim failed: %s} $result]
    quit -code 1 -f
}
foreach f [glob -nocomplain -- "wlf*"] { file delete -force $f }
quit -code 0 -f
