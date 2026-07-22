// ModelSim-only behavioural substitute for the Pango GTP_DRM18K primitive.
// It matches the generated-IP port and parameter interface used in this project.
module GTP_DRM18K #(
    parameter GRS_EN="FALSE", parameter SIM_DEVICE="LOGOS", parameter CSA_MASK=0, parameter CSB_MASK=0,
    parameter DATA_WIDTH_A=18, parameter DATA_WIDTH_B=18, parameter WRITE_MODE_A="NORMAL_WRITE", parameter WRITE_MODE_B="NORMAL_WRITE",
    parameter DOA_REG=0, parameter DOB_REG=0, parameter DOA_REG_CLKINV=0, parameter DOB_REG_CLKINV=0,
    parameter RST_TYPE="ASYNC", parameter RAM_MODE="TRUE_DUAL_PORT", parameter INIT_FILE="NONE",
    parameter BLOCK_X=0, parameter BLOCK_Y=0, parameter RAM_ADDR_WIDTH=14, parameter RAM_DATA_WIDTH=18, parameter INIT_FORMAT="BIN",
    parameter [287:0] INIT_00=0, parameter [287:0] INIT_01=0, parameter [287:0] INIT_02=0, parameter [287:0] INIT_03=0,
    parameter [287:0] INIT_04=0, parameter [287:0] INIT_05=0, parameter [287:0] INIT_06=0, parameter [287:0] INIT_07=0,
    parameter [287:0] INIT_08=0, parameter [287:0] INIT_09=0, parameter [287:0] INIT_0A=0, parameter [287:0] INIT_0B=0,
    parameter [287:0] INIT_0C=0, parameter [287:0] INIT_0D=0, parameter [287:0] INIT_0E=0, parameter [287:0] INIT_0F=0,
    parameter [287:0] INIT_10=0, parameter [287:0] INIT_11=0, parameter [287:0] INIT_12=0, parameter [287:0] INIT_13=0,
    parameter [287:0] INIT_14=0, parameter [287:0] INIT_15=0, parameter [287:0] INIT_16=0, parameter [287:0] INIT_17=0,
    parameter [287:0] INIT_18=0, parameter [287:0] INIT_19=0, parameter [287:0] INIT_1A=0, parameter [287:0] INIT_1B=0,
    parameter [287:0] INIT_1C=0, parameter [287:0] INIT_1D=0, parameter [287:0] INIT_1E=0, parameter [287:0] INIT_1F=0,
    parameter [287:0] INIT_20=0, parameter [287:0] INIT_21=0, parameter [287:0] INIT_22=0, parameter [287:0] INIT_23=0,
    parameter [287:0] INIT_24=0, parameter [287:0] INIT_25=0, parameter [287:0] INIT_26=0, parameter [287:0] INIT_27=0,
    parameter [287:0] INIT_28=0, parameter [287:0] INIT_29=0, parameter [287:0] INIT_2A=0, parameter [287:0] INIT_2B=0,
    parameter [287:0] INIT_2C=0, parameter [287:0] INIT_2D=0, parameter [287:0] INIT_2E=0, parameter [287:0] INIT_2F=0,
    parameter [287:0] INIT_30=0, parameter [287:0] INIT_31=0, parameter [287:0] INIT_32=0, parameter [287:0] INIT_33=0,
    parameter [287:0] INIT_34=0, parameter [287:0] INIT_35=0, parameter [287:0] INIT_36=0, parameter [287:0] INIT_37=0,
    parameter [287:0] INIT_38=0, parameter [287:0] INIT_39=0, parameter [287:0] INIT_3A=0, parameter [287:0] INIT_3B=0,
    parameter [287:0] INIT_3C=0, parameter [287:0] INIT_3D=0, parameter [287:0] INIT_3E=0, parameter [287:0] INIT_3F=0
) (
    output reg [17:0] DOA, input [13:0] ADDRA, input ADDRA_HOLD, input [17:0] DIA, input [2:0] CSA,
    input WEA, input CLKA, input CEA, input ORCEA, input RSTA,
    output reg [17:0] DOB, input [13:0] ADDRB, input ADDRB_HOLD, input [17:0] DIB, input [2:0] CSB,
    input WEB, input CLKB, input CEB, input ORCEB, input RSTB
);
    reg [17:0] mem [0:16383];
    always @(posedge CLKA or posedge RSTA) begin
        if (RSTA) DOA <= 18'b0;
        else if (CEA) begin
            if (WEA) mem[ADDRA[13:2]] <= DIA;
            if (ORCEA || !DOA_REG) DOA <= WEA && WRITE_MODE_A == "TRANSPARENT_WRITE" ? DIA : mem[ADDRA[13:2]];
        end
    end
    always @(posedge CLKB or posedge RSTB) begin
        if (RSTB) DOB <= 18'b0;
        else if (CEB) begin
            if (WEB) mem[ADDRB[13:2]] <= DIB;
            if (ORCEB || !DOB_REG) DOB <= WEB && WRITE_MODE_B == "TRANSPARENT_WRITE" ? DIB : mem[ADDRB[13:2]];
        end
    end
endmodule
