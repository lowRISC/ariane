VIVADO ?= vivado
VIVADOFLAGS ?= -nojournal -mode batch -source scripts/prologue.tcl

work-dir := work-fpga
bit := $(work-dir)/ariane_xilinx.bit
mcs := $(work-dir)/ariane_xilinx.mcs
ip-dir := xilinx
ips := xlnx_axi_clock_converter.xci  \
       xlnx_axi_dwidth_converter.xci \
       xlnx_axi_quad_spi.xci         \
       xlnx_axi_xip_spi.xci          \
       xlnx_axi_gpio.xci             \
       xlnx_clk_gen.xci              \
       xlnx_clk_sd.xci               \
       xlnx_ila_axi_0.xci            \
       xlnx_mig_7_ddr3.xci

ips := $(addprefix $(work-dir)/, $(ips))
ips-target := $(join $(addsuffix /ip/, $(addprefix $(ip-dir)/, $(basename $(ips)))), $(ips))

all: $(mcs)

# Generate mcs from bitstream
$(mcs): $(bit)
	$(VIVADO) $(VIVADOFLAGS) -source scripts/write_cfgmem.tcl -tclargs $@ $^

$(bit): $(ips)
	mkdir -p $(work-dir)
	$(VIVADO) $(VIVADOFLAGS) -source scripts/run.tcl
	cp ariane.runs/impl_1/ariane_xilinx* ./$(work-dir)

$(ips): %.xci :
	mkdir -p $(work-dir)
	@echo Generating $(@F)
	@cd $(ip-dir)/$(basename $(@F)) && make clean && make
	@cp $(ip-dir)/$(basename $(@F))/ip/$(@F) $@

mcs: $(mcs)

program:
	$(VIVADO) $(VIVADOFLAGS) -source scripts/program.tcl

ELF=src/etherboot/etherboot.elf

newmcs: work-fpga/ariane_xilinx.new.mcs

work-fpga/ariane_xilinx.new.mcs: work-fpga/ariane_xilinx.new.bit
	env XILINX_PART="xc7k325tffg900-2" XILINX_BOARD="digilentinc.com:genesys2:part0:1.1" vivado -nojournal -mode batch -source scripts/prologue.tcl -source scripts/write_cfgmem.tcl -tclargs $@ $<

new: work-fpga/ariane_xilinx.bit search-ramb.log scripts/cnvmem.v boot.bmm 
	riscv64-unknown-elf-objcopy -O verilog $(ELF) cnvmem.mem
	iverilog scripts/cnvmem.v -o cnvmem
	./cnvmem
	mv bootram.sv src/bootram.sv
	data2mem -bm boot.mem -bd boot.mem -bt $< -o b work-fpga/ariane_xilinx.new.bit
	echo '_start: .globl _start; .incbin "boot.bin"' | riscv64-unknown-elf-gcc -nostdlib -x assembler -Ttext=0x10000 - -o bootrom.elf
	riscv64-unknown-elf-objcopy -O verilog bootrom.elf bootrom.vlog

search-ramb.log: scripts/search_ramb.tcl work-fpga/ariane_xilinx_routed.dcp
	vivado -mode batch -source $< -tclargs work-fpga/ariane_xilinx_routed > $@

boot.bmm: search-ramb.log
	python scripts/bmm_gen.py $< $@ 128 65536

clean:
	rm -rf *.log *.jou *.str *.mif *.xpr $(work-dir) ariane.cache ariane.hw ariane.ip_user_files

.PHONY:
	clean

