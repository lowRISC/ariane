# Author: Florian Zaruba, ETH Zurich
# Date: 03/19/2017
# Description: Makefile for linting and testing Ariane.

# questa library
library        ?= work
# verilator lib
ver-library    ?= work-ver
# library for DPI
dpi-library    ?= work-dpi
# Top level module to compile
top_level      ?= ariane_tb
# Maximum amount of cycles for a successful simulation run
max_cycles     ?= 10000000
# Test case to run
test_case      ?= core_test
# QuestaSim Version
questa_version ?= ${QUESTASIM_VERSION}
# verilator version
verilator      ?= verilator
# traget option
target-options ?=
# additional definess
defines        ?= WT_DCACHE
# test name for torture runs (binary name)
test-location  ?= output/test
# set to either nothing or -log
torture-logs   :=
# custom elf bin to run with sim or sim-verilator
elf-bin        ?= tmp/riscv-tests/build/benchmarks/dhrystone.riscv
# root path
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
root-dir := $(dir $(mkfile_path))

support_verilator_4 := $(shell (verilator --version | grep '4\.') &> /dev/null; echo $$?)
ifeq ($(support_verilator_4), 0)
	verilator_threads := 2
endif

ifndef RISCV
$(error RISCV not set - please point your RISCV variable to your RISCV installation)
endif

# spike tandem verification
ifdef spike-tandem
    compile_flag += -define SPIKE_TANDEM
    ifndef preload
        $(error Tandem verification requires preloading)
    endif
endif

# Sources
# Package files -> compile first
ariane_pkg := include/riscv_pkg.sv                          \
			  src/riscv-dbg/src/dm_pkg.sv                   \
			  include/ariane_pkg.sv                         \
			  include/std_cache_pkg.sv                      \
			  include/wt_cache_pkg.sv                       \
			  src/axi/src/axi_pkg.sv                        \
			  src/register_interface/src/reg_intf.sv        \
			  include/axi_intf.sv                           \
			  tb/ariane_soc_pkg.sv                          \
			  include/ariane_axi_pkg.sv                     \
			  src/fpu/src/fpnew_pkg.sv                      \

ariane_pkg := $(addprefix $(root-dir), $(ariane_pkg))

# utility modules
util := $(wildcard src/util/*.svh)                          \
        src/util/instruction_tracer_pkg.sv                  \
        src/util/instruction_tracer_if.sv                   \
        src/tech_cells_generic/src/cluster_clock_gating.sv  \
        tb/common/mock_uart.sv                              \
        src/util/sram.sv

ifdef spike-tandem
    util += tb/common/spike.sv
endif

util := $(addprefix $(root-dir), $(util))
# Test packages
test_pkg := $(wildcard tb/test/*/*sequence_pkg.sv*) \
			$(wildcard tb/test/*/*_pkg.sv*)
# DPI
dpi_list := $(patsubst tb/dpi/%.cc, ${dpi-library}/%.o, $(wildcard tb/dpi/*.cc))
# filter spike stuff if tandem is not activated
ifndef spike-tandem
    dpi = $(filter-out ${dpi-library}/spike.o ${dpi-library}/sim_spike.o, $(dpi_list))
else
    dpi = $(dpi_list)
endif

dpi_hdr := $(wildcard tb/dpi/*.h)
dpi_hdr := $(addprefix $(root-dir), $(dpi_hdr))
CFLAGS := -I$(QUESTASIM_HOME)/include         \
          -I$(RISCV)/include                  \
          -std=c++11 -I../tb/dpi

ifdef spike-tandem
    CFLAGS += -Itb/riscv-isa-sim/install/include/spike
endif

# this list contains the standalone components
src :=  $(filter-out src/ariane_regfile.sv, $(wildcard src/*.sv))              \
        $(filter-out src/fpu/src/fpnew_pkg.sv, $(wildcard src/fpu/src/*.sv))   \
        $(filter-out src/fpu/src/fpu_div_sqrt_mvp/hdl/defs_div_sqrt_mvp.sv,    \
        $(wildcard src/fpu/src/fpu_div_sqrt_mvp/hdl/*.sv))                     \
        $(wildcard src/frontend/*.sv)                                          \
        $(filter-out src/cache_subsystem/std_no_dcache.sv src/cache_subsystem/std_nbdcache.sv src/cache_subsystem/miss_handler.sv,                     \
        $(wildcard src/cache_subsystem/*.sv))                                  \
        $(wildcard bootrom/*.sv)                                               \
        $(wildcard src/clint/*.sv)                                             \
        $(filter-out fpga/src/axi2apb/src/axi2apb_wrap.sv, $(wildcard fpga/src/axi2apb/src/*.sv)) \
        $(wildcard fpga/src/axi_slice/src/*.sv)                                \
        $(wildcard src/plic/*.sv)                                              \
        $(wildcard src/axi_node/src/*.sv)                                      \
        $(wildcard src/axi_riscv_atomics/src/*.sv)                             \
        $(wildcard src/axi_mem_if/src/*.sv)                                    \
        src/riscv-dbg/src/dmi_cdc.sv                                           \
        src/riscv-dbg/src/dmi_jtag.sv                                          \
        src/riscv-dbg/src/dmi_jtag_tap.sv                                      \
        src/riscv-dbg/src/dm_csrs.sv                                           \
        src/riscv-dbg/src/dm_mem.sv                                            \
        src/riscv-dbg/src/dm_sba.sv                                            \
        src/riscv-dbg/src/dm_top.sv                                            \
        src/riscv-dbg/debug_rom/debug_rom.sv                                   \
        src/register_interface/src/apb_to_reg.sv                               \
        src/axi/src/axi_multicut.sv                                            \
        src/common_cells/src/deprecated/generic_fifo.sv                        \
        src/common_cells/src/deprecated/pulp_sync.sv                           \
        src/common_cells/src/deprecated/find_first_one.sv                      \
        src/common_cells/src/rstgen_bypass.sv                                  \
        src/common_cells/src/rstgen.sv                                         \
        src/common_cells/src/stream_mux.sv                                     \
        src/common_cells/src/stream_demux.sv                                   \
        src/common_cells/src/stream_arbiter.sv                                 \
        src/common_cells/src/stream_arbiter_flushable.sv                       \
        src/util/axi_master_connect.sv                                         \
        src/util/axi_slave_connect.sv                                          \
        src/util/axi_master_connect_rev.sv                                     \
        src/util/axi_slave_connect_rev.sv                                      \
        src/axi/src/axi_cut.sv                                                 \
        src/axi/src/axi_join.sv                                                \
        src/axi/src/axi_delayer.sv                                             \
        src/axi/src/axi_to_axi_lite.sv                                         \
        src/fpga-support/rtl/SyncSpRamBeNx64.sv                                \
        src/common_cells/src/sync.sv                                           \
        src/common_cells/src/cdc_2phase.sv                                     \
        src/common_cells/src/spill_register.sv                                 \
        src/common_cells/src/sync_wedge.sv                                     \
        src/common_cells/src/edge_detect.sv                                    \
        src/common_cells/src/fifo_v3.sv                                        \
        src/common_cells/src/fifo_v2.sv                                        \
        src/common_cells/src/fifo_v1.sv                                        \
        src/common_cells/src/lzc.sv                                            \
        src/common_cells/src/rrarbiter.sv                                      \
        src/common_cells/src/stream_delay.sv                                   \
        src/common_cells/src/lfsr_8bit.sv                                      \
        src/common_cells/src/lfsr_16bit.sv                                     \
        src/common_cells/src/counter.sv                                        \
        src/common_cells/src/shift_reg.sv                                      \
        src/tech_cells_generic/src/cluster_clock_inverter.sv                   \
        src/tech_cells_generic/src/pulp_clock_mux2.sv                          \
        tb/ariane_testharness.sv                                               \
        tb/ariane_peripherals.sv                                               \
        tb/common/uart.sv                                                      \
        tb/common/SimDTM.sv                                                    \
        tb/common/SimJTAG.sv

src := $(addprefix $(root-dir), $(src))

uart_src := $(wildcard fpga/src/apb_uart/src/*.vhd)
uart_src := $(addprefix $(root-dir), $(uart_src))

fpga_src :=  $(wildcard fpga/src/*.sv) $(wildcard fpga/src/bootrom/*.sv) $(wildcard fpga/src/ariane-ethernet/*.sv)
fpga_src := $(addprefix $(root-dir), $(fpga_src))

# look for testbenches
tbs := tb/ariane_tb.sv tb/ariane_testharness.sv
# RISCV asm tests and benchmark setup (used for CI)
# there is a definesd test-list with selected CI tests
riscv-test-dir            := tmp/riscv-tests/build/isa/
riscv-benchmarks-dir      := tmp/riscv-tests/build/benchmarks/
riscv-asm-tests-list      := ci/riscv-asm-tests.list
riscv-amo-tests-list      := ci/riscv-amo-tests.list
riscv-mul-tests-list      := ci/riscv-mul-tests.list
riscv-fp-tests-list       := ci/riscv-fp-tests.list
riscv-benchmarks-list     := ci/riscv-benchmarks.list
riscv-asm-tests           := $(shell xargs printf '\n%s' < $(riscv-asm-tests-list)  | cut -b 1-)
riscv-amo-tests           := $(shell xargs printf '\n%s' < $(riscv-amo-tests-list)  | cut -b 1-)
riscv-mul-tests           := $(shell xargs printf '\n%s' < $(riscv-mul-tests-list)  | cut -b 1-)
riscv-fp-tests            := $(shell xargs printf '\n%s' < $(riscv-fp-tests-list)   | cut -b 1-)
riscv-benchmarks          := $(shell xargs printf '\n%s' < $(riscv-benchmarks-list) | cut -b 1-)

# Search here for include files (e.g.: non-standalone components)
incdir := src/common_cells/include/common_cells
# Compile and sim flags
compile_flag     += +cover=bcfst+/dut -incr -64 -nologo -quiet -suppress 13262 -permissive +define+$(defines)
uvm-flags        += +UVM_NO_RELNOTES +UVM_VERBOSITY=LOW
questa-flags     += -t 1ns -64 -coverage -classdebug $(gui-sim) $(QUESTASIM_FLAGS)
compile_flag_vhd += -64 -nologo -quiet -2008

# Iterate over all include directories and write them with +incdir+ prefixed
# +incdir+ works for Verilator and QuestaSim
list_incdir := $(foreach dir, ${incdir}, +incdir+$(dir))

# RISCV torture setup
riscv-torture-dir    := tmp/riscv-torture
# old java flags  -Xmx1G -Xss8M -XX:MaxPermSize=128M
# -XshowSettings -Xdiag
riscv-torture-bin    := java -jar sbt-launch.jar

# if defined, calls the questa targets in batch mode
ifdef batch-mode
	questa-flags += -c
	questa-cmd   := -do "coverage save -onexit tmp/$@.ucdb; run -a; quit -code [coverage attribute -name TESTSTATUS -concise]"
	questa-cmd   += -do " log -r /*; run -all;"
else
	questa-cmd   := -do " log -r /*; run -all;"
endif
# we want to preload the memories
ifdef preload
	questa-cmd += +PRELOAD=$(preload)
	elf-bin = none
endif

ifdef spike-tandem
    questa-cmd += -gblso tb/riscv-isa-sim/install/lib/libriscv.so
endif

# remote bitbang is enabled
ifdef rbb
	questa-cmd += +jtag_rbb_enable=1
else
	questa-cmd += +jtag_rbb_enable=0
endif

# Build the TB and module using QuestaSim
build: $(library) $(library)/.build-srcs $(library)/.build-tb $(dpi-library)/ariane_dpi.so
	# Optimize top level
	vopt$(questa_version) $(compile_flag) -work $(library)  $(top_level) -o $(top_level)_optimized +acc -check_synthesis

# src files
$(library)/.build-srcs: $(util) $(library)
	vlog$(questa_version) $(compile_flag) -work $(library) $(filter %.sv,$(ariane_pkg)) $(list_incdir) -suppress 2583
	# vcom$(questa_version) $(compile_flag_vhd) -work $(library) -pedanticerrors $(filter %.vhd,$(ariane_pkg))
	vlog$(questa_version) $(compile_flag) -work $(library) $(filter %.sv,$(util)) $(list_incdir) -suppress 2583
	# Suppress message that always_latch may not be checked thoroughly by QuestaSim.
	vcom$(questa_version) $(compile_flag_vhd) -work $(library) -pedanticerrors $(filter %.vhd,$(uart_src))
	# vcom$(questa_version) $(compile_flag_vhd) -work $(library) -pedanticerrors $(filter %.vhd,$(src))
	vlog$(questa_version) $(compile_flag) -work $(library) -pedanticerrors $(filter %.sv,$(src)) $(list_incdir) -suppress 2583
	touch $(library)/.build-srcs

# build TBs
$(library)/.build-tb: $(dpi)
	# Compile top level
	vlog$(questa_version) $(compile_flag) -sv $(tbs) -work $(library)
	touch $(library)/.build-tb

$(library):
	vlib${questa_version} $(library)

# compile DPIs
$(dpi-library)/%.o: tb/dpi/%.cc $(dpi_hdr)
	mkdir -p $(dpi-library)
	$(CXX) -shared -fPIC -std=c++0x -Bsymbolic $(CFLAGS) -c $< -o $@

$(dpi-library)/ariane_dpi.so: $(dpi)
	mkdir -p $(dpi-library)
	# Compile C-code and generate .so file
	$(CXX) -shared -m64 -o $(dpi-library)/ariane_dpi.so $? -L$(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -lfesvr

# single test runs on Questa can be started by calling make <testname>, e.g. make towers.riscv
# the test names are defined in ci/riscv-asm-tests.list, and in ci/riscv-benchmarks.list
# if you want to run in batch mode, use make <testname> batch-mode=1
# alternatively you can call make sim elf-bin=<path/to/elf-bin> in order to load an arbitrary binary
sim: build
	vsim${questa_version} +permissive $(questa-flags) $(questa-cmd) -lib $(library) +MAX_CYCLES=$(max_cycles) +UVM_TESTNAME=$(test_case) \
	+BASEDIR=$(riscv-test-dir) $(uvm-flags) $(QUESTASIM_FLAGS) -gblso $(RISCV)/lib/libfesvr.so -sv_lib $(dpi-library)/ariane_dpi  \
	${top_level}_optimized +permissive-off ++$(elf-bin) ++$(target-options) | tee sim.log

$(riscv-asm-tests): build
	vsim${questa_version} +permissive $(questa-flags) $(questa-cmd) -lib $(library) +max-cycles=$(max_cycles) +UVM_TESTNAME=$(test_case) \
	+BASEDIR=$(riscv-test-dir) $(uvm-flags) +jtag_rbb_enable=0  -gblso $(RISCV)/lib/libfesvr.so -sv_lib $(dpi-library)/ariane_dpi        \
	${top_level}_optimized $(QUESTASIM_FLAGS) +permissive-off ++$(riscv-test-dir)/$@ ++$(target-options) | tee tmp/riscv-asm-tests-$@.log

$(riscv-amo-tests): build
	vsim${questa_version} +permissive $(questa-flags) $(questa-cmd) -lib $(library) +max-cycles=$(max_cycles) +UVM_TESTNAME=$(test_case) \
	+BASEDIR=$(riscv-test-dir) $(uvm-flags) +jtag_rbb_enable=0  -gblso $(RISCV)/lib/libfesvr.so -sv_lib $(dpi-library)/ariane_dpi        \
	${top_level}_optimized $(QUESTASIM_FLAGS) +permissive-off ++$(riscv-test-dir)/$@ ++$(target-options) | tee tmp/riscv-amo-tests-$@.log

$(riscv-mul-tests): build
	vsim${questa_version} +permissive $(questa-flags) $(questa-cmd) -lib $(library) +max-cycles=$(max_cycles) +UVM_TESTNAME=$(test_case) \
	+BASEDIR=$(riscv-test-dir) $(uvm-flags) +jtag_rbb_enable=0  -gblso $(RISCV)/lib/libfesvr.so -sv_lib $(dpi-library)/ariane_dpi        \
	${top_level}_optimized $(QUESTASIM_FLAGS) +permissive-off ++$(riscv-test-dir)/$@ ++$(target-options) | tee tmp/riscv-mul-tests-$@.log

$(riscv-fp-tests): build
	vsim${questa_version} +permissive $(questa-flags) $(questa-cmd) -lib $(library) +max-cycles=$(max_cycles) +UVM_TESTNAME=$(test_case) \
	+BASEDIR=$(riscv-test-dir) $(uvm-flags) +jtag_rbb_enable=0  -gblso $(RISCV)/lib/libfesvr.so -sv_lib $(dpi-library)/ariane_dpi        \
	${top_level}_optimized $(QUESTASIM_FLAGS) +permissive-off ++$(riscv-test-dir)/$@ ++$(target-options) | tee tmp/riscv-fp-tests-$@.log

$(riscv-benchmarks): build
	vsim${questa_version} +permissive $(questa-flags) $(questa-cmd) -lib $(library) +max-cycles=$(max_cycles) +UVM_TESTNAME=$(test_case) \
	+BASEDIR=$(riscv-benchmarks-dir) $(uvm-flags) +jtag_rbb_enable=0 -gblso $(RISCV)/lib/libfesvr.so -sv_lib $(dpi-library)/ariane_dpi   \
	${top_level}_optimized $(QUESTASIM_FLAGS) +permissive-off ++$(riscv-benchmarks-dir)/$@ ++$(target-options) | tee tmp/riscv-benchmarks-$@.log

# can use -jX to run ci tests in parallel using X processes
run-asm-tests: $(riscv-asm-tests)
	$(MAKE) check-asm-tests

run-amo-tests: $(riscv-amo-tests)
	$(MAKE) check-amo-tests

run-mul-tests: $(riscv-mul-tests)
	$(MAKE) check-mul-tests

run-fp-tests: $(riscv-fp-tests)
	$(MAKE) check-fp-tests

check-asm-tests:
	ci/check-tests.sh tmp/riscv-asm-tests- $(shell wc -l $(riscv-asm-tests-list) | awk -F " " '{ print $1 }')

check-amo-tests:
	ci/check-tests.sh tmp/riscv-amo-tests- $(shell wc -l $(riscv-amo-tests-list) | awk -F " " '{ print $1 }')

check-mul-tests:
	ci/check-tests.sh tmp/riscv-mul-tests- $(shell wc -l $(riscv-mul-tests-list) | awk -F " " '{ print $1 }')

check-fp-tests:
	ci/check-tests.sh tmp/riscv-fp-tests- $(shell wc -l $(riscv-fp-tests-list) | awk -F " " '{ print $1 }')

# can use -jX to run ci tests in parallel using X processes
run-benchmarks: $(riscv-benchmarks)
	$(MAKE) check-benchmarks

check-benchmarks:
	ci/check-tests.sh tmp/riscv-benchmarks- $(shell wc -l $(riscv-benchmarks-list) | awk -F " " '{ print $1 }')

# verilator-specific
#                   -Wno-lint                                                                          \

verilate_command := $(verilator)                                                                       \
                    $(filter-out %.vhd, $(ariane_pkg))                                                 \
                    $(filter-out src/fpu_wrap.sv, $(filter-out %.vhd, $(src)))                         \
                    +define+$(defines)                                                                 \
                    src/util/sram.sv                                                                   \
                    fpga/xilinx/xlnx_ila_plic/ip/xlnx_ila_plic_stub.v                                  \
                    fpga/xilinx/xlnx_ila_5/ip/xlnx_ila_5_stub.v                                        \
                    +incdir+src/axi_node                                                               \
                    $(if $(verilator_threads), --threads $(verilator_threads))                         \
                    --unroll-count 256                                                                 \
                    -Werror-PINMISSING                                                                 \
                    -Werror-IMPLICIT                                                                   \
                    -Wno-fatal                                                                         \
                    -Wno-PINCONNECTEMPTY                                                               \
                    -Wno-ASSIGNDLY                                                                     \
                    -Wno-DECLFILENAME                                                                  \
                    -Wno-UNUSED                                                                        \
                    -Wno-UNOPTFLAT                                                                     \
                    -Wno-style                                                                         \
                    $(if $(PROFILE),--stats --stats-vars --profile-cfuncs,)                            \
                    $(if $(DEBUG),--trace --trace-structs,)                                            \
                    -LDFLAGS "-L$(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -lfesvr$(if $(PROFILE), -g -pg,)" \
                    -CFLAGS "$(CFLAGS)$(if $(PROFILE), -g -pg,)" -Wall --cc  --vpi                     \
                    $(list_incdir) --top-module ariane_testharness                                     \
                    --Mdir $(ver-library) -O3                                                          \
                    --exe tb/ariane_tb.cpp tb/dpi/SimDTM.cc tb/dpi/SimJTAG.cc                          \
					          tb/dpi/remote_bitbang.cc tb/dpi/msim_helper.cc

# User Verilator, at some point in the future this will be auto-generated
verilate:
	@echo "[Verilator] Building Model$(if $(PROFILE), for Profiling,)"
	$(verilate_command)
	cd $(ver-library) && $(MAKE) -j${NUM_JOBS} -f Variane_testharness.mk

sim-verilator: verilate
	$(ver-library)/Variane_testharness $(elf-bin)

ddr_path = fpga/xlnx_mig_7_ddr3_ex
ddr_user_design = xlnx_mig_7_ddr3_ex.srcs/sources_1/ip/xlnx_mig_7_ddr3/xlnx_mig_7_ddr3/user_design/rtl
ddr_sim_files = \
fpga/xilinx/xlnx_axi_clock_converter/ip/xlnx_axi_clock_converter_sim_netlist.v \
$(ddr_path)/imports/ddr3_model.sv \
$(ddr_path)/imports/example_top.v \
$(ddr_path)/imports/mig_7series_v4_1_axi4_tg.v \
$(ddr_path)/imports/mig_7series_v4_1_axi4_wrapper.v \
$(ddr_path)/imports/mig_7series_v4_1_cmd_prbs_gen_axi.v \
$(ddr_path)/imports/mig_7series_v4_1_data_gen_chk.v \
$(ddr_path)/imports/mig_7series_v4_1_tg.v \
$(ddr_path)/imports/sim_tb_top.v \
$(ddr_path)/imports/wiredly.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_ctrl_addr_decode.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_ctrl_read.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_ctrl_reg_bank.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_ctrl_reg.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_ctrl_top.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_ctrl_write.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_ar_channel.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_aw_channel.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_b_channel.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_cmd_arbiter.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_cmd_fsm.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_cmd_translator.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_fifo.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_incr_cmd.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_r_channel.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_simple_fifo.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_w_channel.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_wrap_cmd.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_axi_mc_wr_cmd_fsm.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_a_upsizer.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_axic_register_slice.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_axi_register_slice.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_axi_upsizer.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_carry_and.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_carry_latch_and.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_carry_latch_or.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_carry_or.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_command_fifo.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_comparator_sel_static.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_comparator_sel.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_comparator.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_r_upsizer.v \
$(ddr_path)/$(ddr_user_design)/axi/mig_7series_v4_1_ddr_w_upsizer.v \
$(ddr_path)/$(ddr_user_design)/clocking/mig_7series_v4_1_clk_ibuf.v \
$(ddr_path)/$(ddr_user_design)/clocking/mig_7series_v4_1_infrastructure.v \
$(ddr_path)/$(ddr_user_design)/clocking/mig_7series_v4_1_iodelay_ctrl.v \
$(ddr_path)/$(ddr_user_design)/clocking/mig_7series_v4_1_tempmon.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_arb_mux.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_arb_row_col.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_arb_select.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_bank_cntrl.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_bank_common.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_bank_compare.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_bank_mach.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_bank_queue.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_bank_state.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_col_mach.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_mc.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_rank_cntrl.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_rank_common.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_rank_mach.v \
$(ddr_path)/$(ddr_user_design)/controller/mig_7series_v4_1_round_robin_arb.v \
$(ddr_path)/$(ddr_user_design)/ecc/mig_7series_v4_1_ecc_buf.v \
$(ddr_path)/$(ddr_user_design)/ecc/mig_7series_v4_1_ecc_dec_fix.v \
$(ddr_path)/$(ddr_user_design)/ecc/mig_7series_v4_1_ecc_gen.v \
$(ddr_path)/$(ddr_user_design)/ecc/mig_7series_v4_1_ecc_merge_enc.v \
$(ddr_path)/$(ddr_user_design)/ecc/mig_7series_v4_1_fi_xor.v \
$(ddr_path)/$(ddr_user_design)/ip_top/mig_7series_v4_1_memc_ui_top_axi.v \
$(ddr_path)/$(ddr_user_design)/ip_top/mig_7series_v4_1_mem_intfc.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_byte_group_io.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_byte_lane.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_calib_top.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_if_post_fifo.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_mc_phy.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_mc_phy_wrapper.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_of_pre_fifo.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_4lanes.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_ck_addr_cmd_delay.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_dqs_found_cal_hr.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_dqs_found_cal.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_init.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_ocd_cntlr.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_ocd_data.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_ocd_edge.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_ocd_lim.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_ocd_mux.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_ocd_po_cntlr.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_ocd_samp.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_oclkdelay_cal.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_prbs_rdlvl.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_rdlvl.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_tempmon.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_top.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_wrcal.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_wrlvl_off_delay.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_phy_wrlvl.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_prbs_gen.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_ddr_skip_calib_tap.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_poc_cc.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_poc_edge_store.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_poc_meta.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_poc_pd.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_poc_tap_base.v \
$(ddr_path)/$(ddr_user_design)/phy/mig_7series_v4_1_poc_top.v \
$(ddr_path)/$(ddr_user_design)/ui/mig_7series_v4_1_ui_cmd.v \
$(ddr_path)/$(ddr_user_design)/ui/mig_7series_v4_1_ui_rd_data.v \
$(ddr_path)/$(ddr_user_design)/ui/mig_7series_v4_1_ui_top.v \
$(ddr_path)/$(ddr_user_design)/ui/mig_7series_v4_1_ui_wr_data.v \
$(ddr_path)/$(ddr_user_design)/xlnx_mig_7_ddr3_mig_sim.v \
$(ddr_path)/$(ddr_user_design)/xlnx_mig_7_ddr3.v \

vcs_command := vcs -q -full64 -sverilog -assert svaext +lint=PCWM -v2k_generate +warn=noOBSV2G -debug_access+all -timescale=1ns/1ps \
	            $(filter-out %.vhd, $(ariane_pkg))                                     \
	            $(filter-out src/fpu_wrap.sv fpga/src/axi_slice/src/axi_slice_wrap.sv, $(filter-out %.vhd, $(src)))             \
	            +define+$(defines)                                                     \
	            +define+SIMPLE_XBAR                                                    \
	            +define+SIMULATION                                                     \
	            +incdir+src/axi_node                                                   \
		    src/util/sram.sv                                                       \
	            tb/ariane_tb.sv                                                        \

vlogan_command_ddr := vlogan -work xil_defaultlib -q -full64 -sverilog -assert svaext +lint=PCWM -v2k_generate +warn=noOBSV2G -debug_access+all -timescale=1ns/1ps \
	            $(filter-out %.vhd, $(ariane_pkg))                                     \
                    $(wildcard fpga/src/bootrom/*.sv)                                      \
	            $(filter-out src/fpu_wrap.sv, $(filter-out %.vhd, $(src)))             \
                    -y $(XILINX_VIVADO)/data/verilog/src/unisims +libext+.v                \
                    -y $(XILINX_VIVADO)/data/verilog/src/retarget                          \
                    $(XILINX_VIVADO)/data/verilog/src/glbl.v                               \
                    $(ddr_sim_files)                                                       \
                    +define+$(defines)                                                     \
	            +define+SIMPLE_XBAR                                                    \
	            +define+SIMULATION                                                     \
	            +define+SIMULATE_DDR                                                   \
	            +incdir+$(ddr_path)/imports                                            \
		    src/util/sram.sv                                                       \
	            tb/ariane_tb.sv                                                        \

vcs_command_ddr := vcs -q -full64 -sverilog -assert svaext +lint=PCWM +lint=TFIPC-L +warn=noOBSV2G -debug_access+all -timescale=1ns/1ps \
xil_defaultlib.ariane_tb xil_defaultlib.glbl

vcs_command_xbar := vcs -q -full64 -sverilog -assert svaext +lint=PCWM -v2k_generate +warn=noOBSV2G -debug_access+all -timescale=1ns/1ps \
	            $(filter-out %.vhd, $(ariane_pkg))                                     \
                    $(wildcard bootrom/*.sv)                                               \
	            $(filter-out src/fpu_wrap.sv, $(filter-out %.vhd, $(src)))             \
                    $(foreach i, ${openip_xbar_src}, -v $(i))                              \
	            +define+$(defines)                                                     \
	            +incdir+src/axi_node                                                   \
		    src/util/sram.sv                                                       \
		    fpga/xilinx/xlnx_ila_4/ip/sim/xlnx_ila_4.v                             \
		    fpga/xilinx/xlnx_ila_5/ip/sim/xlnx_ila_5.v                             \
	            tb/ariane_tb.sv                                                        \

vcs_command_orig := vcs -q -full64 -sverilog -assert svaext +lint=PCWM -v2k_generate +warn=noOBSV2G -debug_access+all -timescale=1ns/1ps \
	            $(filter-out %.vhd, $(ariane_pkg))                                     \
	            $(filter-out src/fpu_wrap.sv, $(filter-out %.vhd, $(src)))             \
	            +define+$(defines)                                                     \
	            +define+SIMPLE_XBAR                                                    \
	            +incdir+src/axi_node                                                   \
		    src/util/sram.sv                                                       \
		    fpga/xilinx/xlnx_ila_4/ip/sim/xlnx_ila_4.v                             \
		    fpga/xilinx/xlnx_ila_5/ip/sim/xlnx_ila_5.v                             \
	            tb/ariane_tb.sv                                                        \

sim-vcs:
	@echo "[Vcs] Building Model"
	$(vcs_command)

sim-vcs-debug:
	@echo "[Vcs] Building Model"
	$(vcs_command) +define+VCDPLUS

sim-vcs-ddr:
	@echo "[Vcs] Building Model"
	rm -rf vcs_lib csrc simv.daidir AN.DB vcdplus.vpd test.fst*
	mkdir -p vcs_lib/xil_defaultlib
	$(vlogan_command_ddr) -PP +vcsd
	$(vcs_command_ddr)

sim-vcs-ddr-debug:
	@echo "[Vcs] Building Model"
	rm -rf vcs_lib csrc simv.daidir AN.DB vcdplus.vpd test.fst*
	mkdir -p vcs_lib/xil_defaultlib
	$(vlogan_command_ddr) +define+VCDPLUS
	$(vcs_command_ddr)

sim-vcs-orig:
	@echo "[Vcs] Building Model"
	$(vcs_command_orig)

$(addsuffix -verilator,$(riscv-asm-tests)): verilate
	$(ver-library)/Variane_testharness $(riscv-test-dir)/$(subst -verilator,,$@)

$(addsuffix -verilator,$(riscv-amo-tests)): verilate
	$(ver-library)/Variane_testharness $(riscv-test-dir)/$(subst -verilator,,$@)

$(addsuffix -verilator,$(riscv-mul-tests)): verilate
	$(ver-library)/Variane_testharness $(riscv-test-dir)/$(subst -verilator,,$@)

$(addsuffix -verilator,$(riscv-fp-tests)): verilate
	$(ver-library)/Variane_testharness $(riscv-test-dir)/$(subst -verilator,,$@)

$(addsuffix -verilator,$(riscv-benchmarks)): verilate
	$(ver-library)/Variane_testharness $(riscv-benchmarks-dir)/$(subst -verilator,,$@)

run-asm-tests-verilator: $(addsuffix -verilator, $(riscv-asm-tests)) $(addsuffix -verilator, $(riscv-amo-tests)) $(addsuffix -verilator, $(riscv-fp-tests)) $(addsuffix -verilator, $(riscv-fp-tests))

# split into two halfs for travis jobs (otherwise they will time out)
run-asm-tests1-verilator: $(addsuffix -verilator, $(filter rv64ui-v-% ,$(riscv-asm-tests)))

run-asm-tests2-verilator: $(addsuffix -verilator, $(filter-out rv64ui-v-% ,$(riscv-asm-tests)))

run-amo-verilator: $(addsuffix -verilator, $(riscv-amo-tests))

run-mul-verilator: $(addsuffix -verilator, $(riscv-mul-tests))

run-fp-verilator: $(addsuffix -verilator, $(riscv-fp-tests))

run-benchmarks-verilator: $(addsuffix -verilator,$(riscv-benchmarks))

# torture-specific
torture-gen:
	cd $(riscv-torture-dir) && $(riscv-torture-bin) 'generator/run'

torture-itest:
	cd $(riscv-torture-dir) && $(riscv-torture-bin) 'testrun/run -a output/test.S'

torture-rtest: build
	cd $(riscv-torture-dir) && printf "#!/bin/sh\ncd $(root-dir) && $(MAKE) run-torture$(torture-logs) batch-mode=1 defines=$(defines) test-location=$(test-location)" > call.sh && chmod +x call.sh
	cd $(riscv-torture-dir) && $(riscv-torture-bin) 'testrun/run -r ./call.sh -a $(test-location).S' | tee $(test-location).log
	make check-torture test-location=$(test-location)

torture-dummy: build
	cd $(riscv-torture-dir) && printf "#!/bin/sh\ncd $(root-dir) && $(MAKE) run-torture batch-mode=1 defines=$(defines) test-location=\$${@: -1}" > call.sh

torture-rnight: build
	cd $(riscv-torture-dir) && printf "#!/bin/sh\ncd $(root-dir) && $(MAKE) run-torture$(torture-logs) batch-mode=1 defines=$(defines) test-location=\$${@: -1}" > call.sh && chmod +x call.sh
	cd $(riscv-torture-dir) && $(riscv-torture-bin) 'overnight/run -r ./call.sh -g none' | tee output/overnight.log
	$(MAKE) check-torture

torture-rtest-verilator: verilate
	cd $(riscv-torture-dir) && printf "#!/bin/sh\ncd $(root-dir) && $(MAKE) run-torture-verilator batch-mode=1 defines=$(defines)" > call.sh && chmod +x call.sh
	cd $(riscv-torture-dir) && $(riscv-torture-bin) 'testrun/run -r ./call.sh -a output/test.S' | tee output/test.log
	$(MAKE) check-torture

run-torture: build
	vsim${questa_version} +permissive $(questa-flags) $(questa-cmd) -lib $(library) +max-cycles=$(max_cycles)+UVM_TESTNAME=$(test_case)                                  \
	+BASEDIR=$(riscv-torture-dir) $(uvm-flags) +jtag_rbb_enable=0 -gblso $(RISCV)/lib/libfesvr.so -sv_lib $(dpi-library)/ariane_dpi                                      \
	${top_level}_optimized +permissive-off +signature=$(riscv-torture-dir)/$(test-location).rtlsim.sig ++$(riscv-torture-dir)/$(test-location) ++$(target-options)

run-torture-log: build
	vsim${questa_version} +permissive $(questa-flags) $(questa-cmd) -lib $(library) +max-cycles=$(max_cycles)+UVM_TESTNAME=$(test_case)                                  \
	+BASEDIR=$(riscv-torture-dir) $(uvm-flags) +jtag_rbb_enable=0 -gblso $(RISCV)/lib/libfesvr.so -sv_lib $(dpi-library)/ariane_dpi                                      \
	${top_level}_optimized +permissive-off +signature=$(riscv-torture-dir)/$(test-location).rtlsim.sig ++$(riscv-torture-dir)/$(test-location) ++$(target-options)
	cp vsim.wlf $(riscv-torture-dir)/$(test-location).wlf
	cp trace_hart_0000.log $(riscv-torture-dir)/$(test-location).trace
	cp trace_hart_0000_commit.log $(riscv-torture-dir)/$(test-location).commit
	cp transcript $(riscv-torture-dir)/$(test-location).transcript

run-torture-verilator: verilate
	$(ver-library)/Variane_testharness +max-cycles=$(max_cycles) +signature=$(riscv-torture-dir)/output/test.rtlsim.sig $(riscv-torture-dir)/output/test

check-torture:
	grep 'All signatures match for $(test-location)' $(riscv-torture-dir)/$(test-location).log
	diff -s $(riscv-torture-dir)/$(test-location).spike.sig $(riscv-torture-dir)/$(test-location).rtlsim.sig

fpga_filter := $(addprefix $(root-dir), bootrom/bootrom.sv)

fpga: $(ariane_pkg) $(util) $(src) $(fpga_src) $(util) $(uart_src)
	@echo "[FPGA] Generate sources"
	@echo read_vhdl        {$(uart_src)}    > fpga/scripts/add_sources.tcl
	@echo read_verilog -sv {$(ariane_pkg)} >> fpga/scripts/add_sources.tcl
	@echo read_verilog -sv {$(util)}       >> fpga/scripts/add_sources.tcl
	@echo read_verilog -sv {$(filter-out $(fpga_filter), $(src))} 	   >> fpga/scripts/add_sources.tcl
	@echo read_verilog -sv {$(fpga_src)}   >> fpga/scripts/add_sources.tcl
	@echo "[FPGA] Generate Bitstream"
	cd fpga && make BOARD="nexys4_ddr" XILINX_PART="xc7a100tcsg324-1" XILINX_BOARD="digilentinc.com:nexys4_ddr:part0:1.1" CLK_PERIOD_NS="20"

.PHONY: fpga

build-spike:
	cd tb/riscv-isa-sim && mkdir -p build && cd build && ../configure --prefix=`pwd`/../install --with-fesvr=$(RISCV) --enable-commitlog && make -j8 install

clean:
	rm -rf $(riscv-torture-dir)/output/test*
	rm -rf $(library)/ $(dpi-library)/ $(ver-library)/
	rm -f tmp/*.ucdb tmp/*.log *.wlf *vstf wlft* *.ucdb

.PHONY:
	build sim sim-verilate clean                                              \
	$(riscv-asm-tests) $(addsuffix _verilator,$(riscv-asm-tests))             \
	$(riscv-benchmarks) $(addsuffix _verilator,$(riscv-benchmarks))           \
	check-benchmarks check-asm-tests                                          \
	torture-gen torture-itest torture-rtest                                   \
	run-torture run-torture-verilator check-torture check-torture-verilator

