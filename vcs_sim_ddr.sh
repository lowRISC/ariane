make sim-vcs-ddr |& tee compile.log && \
./simv && \
spike-dasm < trace_hart_00.dasm > trace_hart_00.dis && \
vpd2vcd vcdplus.vpd | vcd2fst - test.fst
