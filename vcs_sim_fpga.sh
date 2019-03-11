rm -f verilog.dump test.fst trace_hart_00.*
make sim-vcs-fpga |& tee compile.log && \
./simv +PRELOAD=$1.vlog && \
spike-dasm < trace_hart_00.dasm > trace_hart_00.dis
vcd2fst verilog.dump test.fst
