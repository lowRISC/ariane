CROSSCOMPILE ?= riscv64-unknown-elf-
CC = ${CROSSCOMPILE}gcc
PYTHON=python

CFLAGS = -Os -ggdb -march=rv64imac -mabi=lp64 -Wall -mcmodel=medany -fno-builtin-printf -fno-builtin-memcpy  # -mexplicit-relocs
CCASFLAGS = -mcmodel=medany # -mexplicit-relocs
LDFLAGS = -nostdlib -nodefaultlibs -nostartfiles -Wl,-Map=mapfile

INCLUDES = -I./ -I./src

SRCS_C = src/main.c src/uart.c src/ethlib.c src/dhcp-client.c src/mini-printf.c src/hash-md5.c src/string.c src/tftp_c.c
SRCS_ASM = startup.S
OBJS_C = $(SRCS_C:.c=.o)
OBJS_S = $(SRCS_ASM:.S=.o)

MAIN = etherboot.elf
MAIN_BIN = $(MAIN:.elf=.bin)
MAIN_IMG = $(MAIN:.elf=.img)
MAIN_SV = $(MAIN:.elf=.sv)

#.PHONY: clean

$(MAIN): ariane.dtb $(OBJS_C) $(OBJS_S) linker.lds
	$(CC) $(CFLAGS) $(LDFLAGS) $(INCLUDES) -Tlinker.lds $(OBJS_S) $(OBJS_C) -o $(MAIN)
	@echo "LD    >= $(MAIN)"

%.img: %.bin
	dd if=$< of=$@ bs=128

%.bin: %.elf
	$(CROSSCOMPILE)objcopy -O binary $< $@

%.o: %.c
	@$(CC) $(CFLAGS) $(INCLUDES) -c $<  -o $@
	@echo "CC    <= $<"

%.o: %.S
	@$(CC) $(CFLAGS) $(CCASFLAGS) $(INCLUDES) -c $<  -o $@
	@echo "CC    <= $<"

%.dtb: %.dts
	dtc -I dts $< -O dtb -o $@

%.sv: %.img
	$(PYTHON) ./gen_rom.py $<
	@echo "PYTHON >= $(MAIN_SV)"

clean:
	$(RM) $(OBJS_C) $(OBJS_S) $(MAIN) $(MAIN_BIN) $(MAIN_IMG) *.dtb

all: $(MAIN) $(MAIN_BIN) $(MAIN_IMG) $(MAIN_SV)
	@echo "zero stage etherboot loader has been compiled!"

recvRawEth: src/recvRawEth.c src/hash-md5.c
	cc -g -o $@ src/recvRawEth.c src/hash-md5.c

# DO NOT DELETE THIS LINE -- make depend needs it
