#define ROM_BASE 0x40000000

.section .text.start, "ax", @progbits
.globl _start
_start:
  li s0, ROM_BASE
  csrr a0, mhartid
  la a1, _dtb
  jr s0

.section .text.hang, "ax", @progbits
.globl _hang
_hang:
  li s0, ROM_BASE
  csrr a0, mhartid
  la a1, _dtb
  jr s0

.section .rodata.dtb, "a", @progbits
.globl _dtb
.align 5, 0
_dtb:
.incbin "ariane.dtb"
