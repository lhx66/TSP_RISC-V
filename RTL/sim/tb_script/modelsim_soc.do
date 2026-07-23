set tbname tb_soc_program
if {![file isdirectory work]} { vlib work }
if {![file isdirectory log]} { file mkdir log }
vmap work work
vlog -sv -incr -work work -override_timescale 1ns/10ps -f modelsim_filelist.f -l ./log/vlog_soc.log
vopt work.$tbname -o voptsim_soc -l ./log/vopt_soc.log
set program_args ""
if {[info exists env(PROGRAM_ARGS)]} { set program_args $env(PROGRAM_ARGS) }
set vsim_args [list -c voptsim_soc]
foreach arg $program_args { lappend vsim_args $arg }
lappend vsim_args -l ./log/vsim_soc.log -do "run -all; quit -f"
eval vsim $vsim_args
quit -f
