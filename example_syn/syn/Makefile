export 
DC_SHELL            :=  dc_shell

DESIGN_TOP_NAME 	:= matrix_processor
PT_STAGE		    :=  pre 
PT_CHECK_FUNCTION	:=  func
PT_CHECK_CONER		:=  fast

INTERRUPT			:=	1
DCT					:=	0

DATE				:=	$(shell date +%y%m%d)
PROJ				:=  VESC2026
PROJ_PATH			:=	$(PWD)
PROJ_ROOT			:=	$(PROJ_PATH)/..
PRJ_HOME			:=	$(PROJ_ROOT)
PROJ_TEMP			:=	$(PROJ_PATH)/output/$(DATE)
RTL_ROOT            :=  $(PROJ_ROOT)/rtl

postCTS				:=  0
clockGate			:=  0
enableDFT			:=  0

#Change Design List to  filelist
DESIGN				:=	$(DESIGN_TOP_NAME)
DESIGN_TOP			:=	$(DESIGN)
DESIGN_SRC			:=	
DESIGN_ROOT			:=  $(PROJ_ROOT)/..

DESIGN_SCR			:=	$(PROJ_PATH)/scr/dc.tcl
DESIGN_DEBUG_SCR	:=	$(PROJ_PATH)/scr/dc_debug.tcl
DESIGN_DFT_SCR		:=	$(PROJ_PATH)/scr/dc_dft.tcl
DESIGN_DONTCH_SDC	:=	$(PROJ_PATH)/scr/$(DESIGN)_dont_touch.tcl
DESIGN_DONTUSE_SDC  :=	$(PROJ_PATH)/scr/$(DESIGN)_dont_use.tcl

DESIGN_SYN_SDC		:=	$(PROJ_PATH)/scr/sdc_main.tcl
DESIGN_DFT_SDC		:=	$(PROJ_ROOT)/sdc/$(DESIGN)_scan.sdc


DW_DB_PATH         	:= 
STD_DB_PATH1       	:= 	$(PROJ_ROOT)/syn/lib/FreePDK45/osu_soc/lib/files
STD_DB_PATH2       	:=
STD_DB_PATH         := 	$(STD_DB_PATH1)
SYNC_DB_PATH        := 	$(STD_DB_PATH)
STD_LIB_PATH        :=  
STD_MODEL_PATH      :=  
MEM_DB_PATH         :=  
IO_DB_PATH			:= 	
LPK_DB_PATH         :=  
AFE_DB_PATH         := 	
AFE_LIB_PATH        :=  

PROCE               := 	gscl45nm
SYN_CONER			:= 	
SYN_OPER_CONDITION  :=  typical
SYN_OPR_CON			:= 	$(SYN_CONER)
SYN_STD_LIB_NAME    :=   gscl45nm

STD_DB_LIST1       	:= 	gscl45nm.db
STD_DB_LIST2       	:=
STD_DB_LIST       	:=  $(STD_DB_LIST1)
STD_LIB_LIST       	:=  
SYNC_DB_LIST        := 	$(STD_DB_LIST)
STD_MODEL           :=  
MEM_DB_LIST         :=  
IO_DB_LIST			:= 	
LPK_DB_LIST         :=  
AFE_DB_LIST         :=  
AFE_LIB_LIST        :=  

.PHONY:

env:.PHONY
	@env

syn:.PHONY
	mkdir -p $(PROJ_TEMP)
	$(DC_SHELL) -f $(DESIGN_SCR) | tee syn.log
debug:.PHONY
	$(DC_SHELL) -f $(DESIGN_DEBUG_SCR)
clean:
	rm  -rf *.log *.svf
	rm  -rf WORK alib-52
