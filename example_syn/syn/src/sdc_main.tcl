set_operating_conditions -library "${std_lib_name}" "${std_operating_condition}"
set auto_wire_load_selection "true"
set_wire_load_mode top
set_max_area 0.0

source -e -v ../sdc/${DESIGN_TOP}_func.sdc 
#source -e -v ../sdc/${DESIGN_TOP}_intf.sdc
