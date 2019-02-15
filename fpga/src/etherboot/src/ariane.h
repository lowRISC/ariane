#ifndef __ARIANE_H
#define __ARIANE_H

typedef enum {
        DebugBase    = 0x00000000,
        ROMBase      = 0x00010000,
        CLINTBase    = 0x02000000,
        PLICBase     = 0x0C000000,
        UARTBase     = 0x10000000,
        SPIBase      = 0x20000000,
        EthernetBase = 0x30000000,
        GPIOBase     = 0x40000000,
        DRAMBase     = 0x80000000
    } soc_bus_start_t;

enum {
    DebugLength    = 0x1000,
    ROMLength      = 0x10000,
    CLINTLength    = 0xC0000,
    PLICLength     = 0x3FFFFFF,
    UARTLength     = 0x1000,
    SPILength      = 0x800000,
    EthernetLength = 0x10000,
    GPIOLength     = 0x1000,
    DRAMLength     = 0x40000000, // 1GByte of DDR (split between two chips on Genesys2)
    SRAMLength     = 0x1800000,  // 24 MByte of SRAM
};

void eth_main(void);
void sd_main(int sw);

#endif
