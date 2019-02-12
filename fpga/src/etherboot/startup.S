# start sequence of the bootloader
# 
# 
#include <smp.h>
#define DRAM_BASE 0x80100000

  .section .text.init
  .option norvc
  .globl _prog_start
_prog_start:
  smp_pause(s1, s2)
  la a1, _prog_start
  la a2, _DATA_END_
  li a3, DRAM_BASE
  add a5, zero, a3      
_copy:
  ld a4, 0(a1)
  sd a4, 0(a3)
  ld a4, 8(a1)
  sd a4, 8(a3)
  ld a4, 16(a1)
  sd a4, 16(a3)
  ld a4, 24(a1)
  sd a4, 24(a3)
  add a1, a1, 32
  add a3, a3, 32
  blt a1, a2, _copy
  la a5, _reloc
  add a5, a5, a3      
  sub a5, a5, a1
  jr a5      
_reloc:
  la a5, trap_entry
  csrw mtvec, a5  
  li sp, 0x84000000
  la a1, _BSS_START_
  la a2, _BSS_END_
_zbss:
  sd zero, 0(a1)
  sd zero, 8(a1)
  sd zero, 16(a1)
  sd zero, 24(a1)
  add a1, a1, 32
  blt a1, a2, _zbss
  call main
  smp_resume(s1, s2)
  csrr a0, mhartid
  la a1, _dtb
  li s1, DRAM_BASE
  jr s1
trap_entry:
  csrr t0, mcause
  csrr t1, mepc
1:      
  wfi
  j 1b
  .section .dtb
  .globl _dtb
  .align 4, 0
_dtb:
  .incbin "ariane.dtb"
