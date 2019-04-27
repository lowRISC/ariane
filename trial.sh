rm -f work-ver/Variane_testharness
make verilate DEBUG=1 |& tee compile.log
work-ver/Variane_testharness -v verilog.dump /local/scratch/jrrk2/lowrisc-chip-refresh-v0.6/rocket-chip/riscv-tools/riscv-tests/isa/$1
vcd2fst verilog.dump test.fst
#gtkwave test.fst &
#less /local/scratch/jrrk2/lowrisc-chip-refresh-v0.6/rocket-chip/riscv-tools/riscv-tests/isa/$1.dump
