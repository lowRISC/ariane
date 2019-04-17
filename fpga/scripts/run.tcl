# Copyright 2018 ETH Zurich and University of Bologna.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
# This version modified by Jonathan Kimmitt to support Nexys4DDR

# hard-coded to Nexys4ddr for the moment
add_files -fileset constrs_1 -norecurse constraints/nexys4ddr.xdc

read_ip xilinx/xlnx_mig_7_ddr3/ip/xlnx_mig_7_ddr3.xci
read_ip xilinx/xlnx_axi_clock_converter/ip/xlnx_axi_clock_converter.xci
read_ip xilinx/xlnx_axi_dwidth_converter/ip/xlnx_axi_dwidth_converter.xci
read_ip xilinx/xlnx_axi_gpio/ip/xlnx_axi_gpio.xci
read_ip xilinx/xlnx_axi_quad_spi/ip/xlnx_axi_quad_spi.xci
read_ip xilinx/xlnx_clk_nexys/ip/xlnx_clk_nexys.xci
read_ip xilinx/xlnx_clk_sd/ip/xlnx_clk_sd.xci
read_ip xilinx/xlnx_ila/ip/xlnx_ila.xci
read_ip xilinx/xlnx_ila_4/ip/xlnx_ila_4.xci
read_ip xilinx/xlnx_ila_5/ip/xlnx_ila_5.xci
read_ip xilinx/xlnx_ila_sd/ip/xlnx_ila_sd.xci
read_ip xilinx/xlnx_ila_plic/ip/xlnx_ila_plic.xci
read_ip xilinx/xlnx_ila_rng/ip/xlnx_ila_rng.xci
read_ip xilinx/xlnx_ila_axi_0/ip/xlnx_ila_axi_0.xci
read_ip xilinx/xlnx_proto_check/ip/xlnx_proto_check.xci

source scripts/add_sources.tcl

set_property top ${project}_xilinx [current_fileset]

if {$::env(BOARD) eq "nexys4_ddr"} {
    read_verilog -sv {src/nexys4ddr.svh ../src/common_cells/include/common_cells/registers.svh}
    set file "src/nexys4ddr.svh"
    set registers "../src/common_cells/include/common_cells/registers.svh"
} else {
    exit 1
}

set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file" "*$registers"]]
set_property -dict { file_type {Verilog Header} is_global_include 1} -objects $file_obj

update_compile_order -fileset sources_1

add_files -fileset constrs_1 -norecurse constraints/$project.xdc

set_property include_dirs src/axi_sd_bridge/include [current_fileset]

synth_design -rtl -name rtl_1

set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY full [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.GATED_CLOCK_CONVERSION on [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RESOURCE_SHARING auto [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AreaMapLargeShiftRegToBRAM [get_runs synth_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraTimingOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AlternateFlowWithRetiming [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE MoreGlobalIterations [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AddRetime [get_runs impl_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreWithRemap [get_runs impl_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]

launch_runs synth_1
wait_on_run synth_1
open_run synth_1

exec mkdir -p reports/
exec rm -rf reports/*

check_timing -verbose                                                   -file reports/$project.check_timing.rpt
report_timing -max_paths 100 -nworst 100 -delay_type max -sort_by slack -file reports/$project.timing_WORST_100.rpt
report_timing -nworst 1 -delay_type max -sort_by group                  -file reports/$project.timing.rpt
report_utilization -hierarchical                                        -file reports/$project.utilization.rpt
report_cdc                                                              -file reports/$project.cdc.rpt
report_clock_interaction                                                -file reports/$project.clock_interaction.rpt

# set for RuntimeOptimized implementation
set_property "steps.place_design.args.directive" "RuntimeOptimized" [get_runs impl_1]
set_property "steps.route_design.args.directive" "RuntimeOptimized" [get_runs impl_1]

launch_runs impl_1
wait_on_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
open_run impl_1

# output Verilog netlist + SDC for timing simulation
write_verilog -force -mode funcsim work-fpga/${project}_funcsim.v
write_verilog -force -mode timesim work-fpga/${project}_timesim.v
write_sdf     -force work-fpga/${project}_timesim.sdf

# reports
exec mkdir -p reports/
exec rm -rf reports/*
check_timing                                                              -file reports/${project}.check_timing.rpt
report_timing -max_paths 100 -nworst 100 -delay_type max -sort_by slack   -file reports/${project}.timing_WORST_100.rpt
report_timing -nworst 1 -delay_type max -sort_by group                    -file reports/${project}.timing.rpt
report_utilization -hierarchical                                          -file reports/${project}.utilization.rpt
