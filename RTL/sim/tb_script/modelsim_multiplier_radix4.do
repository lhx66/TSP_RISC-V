set tbname tb_multiplier_radix4
if {![file isdirectory work]} { vlib work }
if {![file isdirectory log]} { file mkdir log }
vmap work work

vlog -sv -incr -work work -override_timescale 1ns/10ps -f modelsim_filelist.f -l ./log/vlog_multiplier_radix4.log
if {[catch {vopt +acc +nospecify work.$tbname -o voptsim_multiplier_radix4 -l ./log/vopt_multiplier_radix4.log} result]} {
    puts stderr "[TB_ERROR] vopt failed: $result"
    quit -code 1 -f
}
if {[catch {vsim -c +nospecify voptsim_multiplier_radix4 -l ./log/vsim_multiplier_radix4.log -do "run -all; quit -f"} result]} {
    puts stderr [format {[TB_ERROR] vsim failed: %s} $result]
    quit -code 1 -f
}
quit -code 0 -f
