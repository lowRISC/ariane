make sim-vcs-debug |& tee compile.log && \
./simv +vcs+finish+1000000000 && \
spike-dasm < trace_hart_00.dasm > trace_hart_00.dis && \
vpd2vcd vcdplus.vpd | vcd2fst - test.fst
