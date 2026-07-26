define_design_lib work -path "./WORK"

set_svf ${PROJ_TEMP}/${DESIGN_TOP}.svf

set_app_var simplified_verification_mode true

set macro_param ""

echo "#------------------------------------------"
echo "Redefine RTL Parameters:"
echo "$macro_param"
echo "#------------------------------------------"
set PRJ_HOME           [getenv PRJ_HOME]
echo ${PRJ_HOME}
analyze  -vcs "+define+SYNTHESIS +incdir+${RTL_ROOT} -f ${RTL_ROOT}/../filelist/${DESIGN_TOP}.f"  -format sverilog 

elab ${DESIGN_TOP}

write -f ddc -h -o ${PROJ_TEMP}/${DESIGN_TOP}_elab.ddc

set verilogout_no_tri true
set verilogout_show_unconnected_pins true
set hdlin_enable_rtldrc_info true
set hdlin_vrlg_std "2001"
set power_preserve_rtl_hier_names true
set hdlin_shorten_long_module_name true
set hdlin_module_name_limit 256

current_design ${DESIGN_TOP}

set uniquify_naming_style "${DESIGN_TOP}_%s_%d"
uniquify -force

link

check_design 

