# compile and launch verilator simulation
make verilate |& tee compile.log && \
work-ver/Variane_testharness && \
spike-dasm < trace_hart_00.dasm > trace_hart_00.dis && \
vcd2fst verilog.dump test.fst
