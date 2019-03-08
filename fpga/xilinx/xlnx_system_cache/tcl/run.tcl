set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)

set ipName xlnx_system_cache

create_project $ipName . -part $partNumber
set_property board_part $boardName [current_project]

create_ip -name system_cache -vendor xilinx.com -library ip -module_name $ipName

set_property -dict [list \
                        CONFIG.C_NUM_OPTIMIZED_PORTS {0} \
                        CONFIG.C_NUM_GENERIC_PORTS {1} \
                        CONFIG.C_ENABLE_ERROR_HANDLING {1} \
                        CONFIG.C_NUM_WAYS {4} \
                        CONFIG.C_CACHE_SIZE {262144} \
                        CONFIG.C_ENABLE_STATISTICS {0} \
                        CONFIG.C_M0_AXI_DATA_WIDTH {32} \
                        CONFIG.C_M1_AXI_DATA_WIDTH {32} \
                        CONFIG.C_M2_AXI_DATA_WIDTH {32} \
                        CONFIG.C_M3_AXI_DATA_WIDTH {32} \
                        CONFIG.C_M0_AXI_DATA_WIDTH {64} \
                        CONFIG.C_S0_AXI_GEN_DATA_WIDTH {64} \
                        CONFIG.C_M0_AXI_THREAD_ID_WIDTH {5} \
                        CONFIG.C_M0_AXI_ADDR_WIDTH {64} \
                        CONFIG.C_CACHE_DATA_WIDTH {64}] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
