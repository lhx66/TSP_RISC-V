#--------------------------------------------
# Common Setup 
#--------------------------------------------
set PROJ_PATH [getenv PROJ_PATH]
source -e -v ${PROJ_PATH}/scr/1_common_setup.tcl

#--------------------------------------------
# Setup Library
#--------------------------------------------

source -e -v ${PROJ_PATH}/scr/2_dc_setup.tcl

if { $DCT == 1 } {
    source -e -v ${PROJ_PATH}scr/2_dct_setup.tcl
}

#--------------------------------------------
# Parse Design and Uniquify
#--------------------------------------------

source -e -v ${PROJ_PATH}/scr/3_read_design.tcl

#--------------------------------------------
# Constrain Design
#--------------------------------------------

source -e -v ${DESIGN_SYN_SDC}
#source -e -v ${DESIGN_DONTCH_SDC}
#source -e -v ${DESIGN_DONTUSE_SDC}

#--------------------------------------------
# Design Environment
#--------------------------------------------

source -e -v ${PROJ_PATH}/scr/4_design_environment.tcl

#--------------------------------------------
# Compile
#--------------------------------------------

source -e -v ${PROJ_PATH}/scr/5_compile_design.tcl

#--------------------------------------------
# Set False Path and Report Timing
#--------------------------------------------

source -e -v ${PROJ_PATH}/scr/6_timing_report.tcl

if {$INTERRUPT != 1} {
    exit
}
