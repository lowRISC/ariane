make sim-vcs |& tee compile.log && \
./simv +vcs+finish+200000000 +PRELOAD=$1.vlog && \
spike-dasm < trace_hart_00.dasm > trace_hart_00.dis && vpd2vcd vcdplus.vpd | vcd2fst - test.fst
