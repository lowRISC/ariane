rm -f vcdplus.vpd test.fst
make sim-vcs |& tee compile.log && \
./simv +vcs+finish+1000000000 && \
spike-dasm < trace_hart_00.dasm > trace_hart_00.dis
