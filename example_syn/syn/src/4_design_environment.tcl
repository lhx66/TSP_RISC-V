set ports_clock_root [get_ports [all_fanout -flat -clock_tree -level 0]]
group_path -name REGOUT -to [all_outputs]
group_path -name REGIN -from [remove_from_collection [all_inputs] $ports_clock_root]
group_path -name FEEDTHROUGH -from [remove_from_collection [all_inputs] $ports_clock_root] -to [all_outputs]

set_operating_conditions $std_operating_condition -library [get_libs ${std_lib_name}]

set timing_enable_multiple_clocks_per_reg "true"

set_max_area 0

#set_clock_gating_style -sequential_cell latch \
#    -positive_edge_logic {integrated} \
#    -control_signal scan_enable \
#    -control_point before \
#    -minimum_bitwidth 3 \
#    -max_fanout 2048

