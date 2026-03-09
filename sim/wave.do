onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_TSP_Core/clk
add wave -noupdate /tb_TSP_Core/rst_n
add wave -noupdate /tb_TSP_Core/u_TSP_Core/global_pc
add wave -noupdate /tb_TSP_Core/u_TSP_Core/inst_if
add wave -noupdate /tb_TSP_Core/u_TSP_Core/u_TSP_Regfiles/RV32I_regs
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {2013500 ps} {2023500 ps}
