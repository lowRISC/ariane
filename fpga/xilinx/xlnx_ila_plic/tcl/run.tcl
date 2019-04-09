set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)

set ipName xlnx_ila_plic

create_project $ipName . -force -part $partNumber
set_property board_part $boardName [current_project]

create_ip -name ila -vendor xilinx.com -library ip -module_name $ipName
set_property -dict [list  CONFIG.C_NUM_OF_PROBES {28} \
                          CONFIG.C_PROBE0_WIDTH {93} \
                          CONFIG.C_PROBE1_WIDTH {93} \
                          CONFIG.C_PROBE2_WIDTH {31} \
                          CONFIG.C_PROBE3_WIDTH {30} \
                          CONFIG.C_PROBE4_WIDTH {62} \
                          CONFIG.C_PROBE5_WIDTH {62} \
                          CONFIG.C_PROBE6_WIDTH {2} \
                          CONFIG.C_PROBE7_WIDTH {6} \
                          CONFIG.C_PROBE8_WIDTH {6} \
                          CONFIG.C_PROBE9_WIDTH {2} \
                          CONFIG.C_PROBE10_WIDTH {10} \
                          CONFIG.C_PROBE11_WIDTH {10} \
                          CONFIG.C_PROBE12_WIDTH {2} \
                          CONFIG.C_PROBE13_WIDTH {2} \
                          CONFIG.C_PROBE14_WIDTH {70} \
                          CONFIG.C_PROBE15_WIDTH {34} \
                          CONFIG.C_PROBE16_WIDTH {30} \
                          CONFIG.C_PROBE17_WIDTH {30} \
                          CONFIG.C_PROBE18_WIDTH {90} \
                          CONFIG.C_PROBE19_WIDTH {60} \
                          CONFIG.C_PROBE20_WIDTH {30} \
                          CONFIG.C_PROBE21_WIDTH {2} \
                          CONFIG.C_PROBE22_WIDTH {10} \
                          CONFIG.C_PROBE23_WIDTH {10} \
                          CONFIG.C_PROBE24_WIDTH {2} \
                          CONFIG.C_PROBE25_WIDTH {1} \
                          CONFIG.C_PROBE26_WIDTH {2} \
                          CONFIG.C_PROBE27_WIDTH {2} \
                          CONFIG.C_DATA_DEPTH {8192}  \
                          CONFIG.C_INPUT_PIPE_STAGES {1} \
                          CONFIG.C_EN_STRG_QUAL {1} \
                          CONFIG.C_TRIGOUT_EN {false} \
                          CONFIG.C_TRIGIN_EN {false} \
                          CONFIG.ALL_PROBE_SAME_MU_CNT {3} ] [get_ips $ipName]


generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
