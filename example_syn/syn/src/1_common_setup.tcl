set_host_options -max_cores 1
report_host_options
#---------------------------------------
# Gen Environment Settings
#---------------------------------------
set INTERRUPT           [getenv INTERRUPT ] 
set DCT                 [getenv DCT       ] 

set DATE                [getenv DATE      ] 
set PROJ                [getenv PROJ      ] 
set PROJ_PATH           [getenv PROJ_PATH ] 
set PROJ_ROOT           [getenv PROJ_ROOT ] 
set PROJ_TEMP           [getenv PROJ_TEMP ] 

set postCTS             [getenv postCTS   ] 
set enableDFT           [getenv enableDFT ] 
set clockGate           [getenv clockGate ] 

set DESIGN              [getenv DESIGN    ] 
set DESIGN_TOP          [getenv DESIGN_TOP]
set DESIGN_SRC          [getenv DESIGN_SRC]

set DESIGN_SYN_SDC      [getenv DESIGN_SYN_SDC   ] 
set DESIGN_DONTCH_SDC   [getenv DESIGN_DONTCH_SDC] 
set DESIGN_DONTUSE_SDC  [getenv DESIGN_DONTUSE_SDC]
set DESIGN_DFT_SDC      [getenv DESIGN_DFT_SDC   ] 

set DW_DB_PATH          [getenv DW_DB_PATH]

set STD_DB_PATH         [getenv STD_DB_PATH]
set AFE_DB_PATH         [getenv AFE_DB_PATH]
set SYNC_DB_PATH        [getenv SYNC_DB_PATH]
set IO_DB_PATH          [getenv IO_DB_PATH]
set IO_DB_LIST          [getenv IO_DB_LIST]
set PROCE		        [getenv PROCE]
set RTL_ROOT            [getenv RTL_ROOT]
set DESIGN_ROOT         [getenv DESIGN_ROOT]
set AFE_DB_LIST         [getenv AFE_DB_LIST]

set flow  "syn"
#----------------------------------------
# Set Process and Local parameters
#----------------------------------------

set CORNER              [getenv SYN_CONER] 
set std_db_path         "${STD_DB_PATH}"
set mem_db_path         [getenv MEM_DB_PATH]
set sync_db_path        "${SYNC_DB_PATH}"
set std_db_list         [getenv STD_DB_LIST]
set mem_db_list         [getenv MEM_DB_LIST]
set std_lib_name        [getenv SYN_STD_LIB_NAME]
set sync_db_list        ""
set std_db_name         "${PROCE}_${CORNER}"
set std_buff_cell       "BUFHSV1"
set std_buff_cell_drive "Z"
set std_buff_cell_load  "I"

set lpk_db_list         [getenv LPK_DB_LIST]
set lpk_db_path         [getenv LPK_DB_PATH]

set std_operating_condition  [getenv SYN_OPER_CONDITION] 

set afe_db_enable       true 
set afe_db_path         "${AFE_DB_PATH}"
set afe_db_list         "${AFE_DB_LIST}"
set afe_dft_wrapper     false 

set io_db_path          "${IO_DB_PATH}"
set io_db_list          "${IO_DB_LIST}"

set spare_cell_enable   false 
set verilogout_show_unconnected_pins true
set hdlin_auto_save_templates true
