set_fix_multiple_port_nets -all -exclude_clock_network
set_app_var dc_allow_rtl_pg true
#if  {$enableDFT==1} {
#compile_ultra -scan -gate_clock -no_seq_output_inversion \
#    -no_boundary_optimization -no_autoungroup
#    } elseif {$clockGate == 1} {
#compile_ultra  -gate_clock -no_seq_output_inversion \
#    -no_boundary_optimization -no_autoungroup
#    } else {
#compile_ultra  -no_seq_output_inversion \
#    -no_boundary_optimization -no_autoungroup
#}

compile -map_effort medium -area_effort low -power_effort none

change_names -rules verilog -verbose -hierarchy

check_design    >   ${PROJ_TEMP}/${DESIGN_TOP}_check_design.rpt
check_timing    >   ${PROJ_TEMP}/${DESIGN_TOP}_check_timing.rpt

write -f verilog -h -o ${PROJ_TEMP}/${DESIGN_TOP}_syn.vg
write -f ddc     -h -o ${PROJ_TEMP}/${DESIGN_TOP}_syn.ddc


write_sdc              ${PROJ_TEMP}/${DESIGN_TOP}_syn.sdc
report_timing -nets -input -trans -cap -nworst 5 > ${PROJ_TEMP}/${DESIGN_TOP}_before_dft_timing.rpt

