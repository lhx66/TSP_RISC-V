report_qor                           >   ${PROJ_TEMP}/${DESIGN_TOP}_qor.rpt
report_area                          >   ${PROJ_TEMP}/${DESIGN_TOP}_area.rpt
report_area -hier                    >>  ${PROJ_TEMP}/${DESIGN_TOP}_area.rpt
report_design                        >   ${PROJ_TEMP}/${DESIGN_TOP}_design.rpt
report_reference                     >   ${PROJ_TEMP}/${DESIGN_TOP}_reference.rpt
report_constraints                   >   ${PROJ_TEMP}/${DESIGN_TOP}_constraints.rpt
report_constraints -all_violator     >>  ${PROJ_TEMP}/${DESIGN_TOP}_constraints.rpt
report_constraints -all_violator -v  >>  ${PROJ_TEMP}/${DESIGN_TOP}_constraints.rpt
report_timing -nets -input -trans -cap -nworst 5 > ${PROJ_TEMP}/${DESIGN_TOP}_timing.rpt
report_power -hier -verbose          > ${PROJ_TEMP}/${DESIGN_TOP}_power.rpt
report_power           >> ${PROJ_TEMP}/${DESIGN_TOP}_power.rpt
report_threshold_voltage_group           > ${PROJ_TEMP}/${DESIGN_TOP}_cell_usage.rpt
sizeof_collection [get_cells -h]     >   ${PROJ_TEMP}/${DESIGN_TOP}_instances.rpt

report_clock_gating -v -ungated      >   ${PROJ_TEMP}/${DESIGN_TOP}_clock_gating.rpt
