#include <sys/types.h>
#include <stdint.h>
#include "uart.h"
#include "mini-printf.h"
#include "ariane.h"

// QSPI commands
#define CMD_RDID 0x9F
#define CMD_MIORDID 0xAF
#define CMD_RDSR 0x05
#define CMD_RFSR 0x70
#define CMD_RDVECR 0x65
#define CMD_WRVECR 0x61
#define CMD_WREN 0x06
#define CMD_SE 0xD8
#define CMD_BE 0xC7
#define CMD_PP 0x02
#define CMD_QCFR 0x0B
#define CMD_OTPR 0x4B

static const uint8_t pattern[] = {0x55, 0xAA, 0x33, 0xcc};

void gpio_leds(uint32_t arg)
{
  volatile uint64_t *swp = (volatile uint64_t *)GPIOBase;
  swp[0] = arg;
}

uint32_t gpio_sw(void)
{
  volatile uint64_t *swp = (volatile uint64_t *)GPIOBase;
  return swp[0];
}

uint32_t hwrnd(void)
{
  volatile uint64_t *swp = (volatile uint64_t *)GPIOBase;
  swp[2] = 0;
  return swp[2];
}

uint32_t qspistatus(void)
{
  volatile uint64_t *swp = (volatile uint64_t *)GPIOBase;
  return swp[6]; // {spi_busy, spi_error}
}

uint64_t qspi_send(uint8_t cmd, uint8_t len, uint8_t quad, uint32_t *data)
{
  uint32_t i, stat;
  volatile uint64_t *swp = (volatile uint64_t *)GPIOBase;
  swp[5] = cmd | (len << 8) | (quad << 16);
  for (i = 0; i < len; i++)
    swp[5] = data[i];
  i = 0;
  do
    {
      stat = swp[6];
    }
  while ((stat & 0x2) && (++i < 1000));
  return swp[4];
}

int main()
{
  uint32_t i, rnd, sw, sw2, data[32];
  
    init_uart();
    print_uart("Hello World!\r\n");
    for (i = 0; i < 5; i++)
      {
        volatile uint64_t *swp = (volatile uint64_t *)GPIOBase;
        printf("swp[%d] = %X\n", i, swp[i]);
      }
    if (0) printf("QSPI ID = %x\n", qspi_send(CMD_RDID, 0, 0, data));
    for (i = 0; i < 6; i++)
      {
        //        data[0] = (2 << 24) | i; // Random factory init string
        data[0] = (2 << 24) | (0x20 + i); // OEM Base address of MAC address (6 bytes)
        printf("QSPI OEM[%d] = %x\n", i, qspi_send(CMD_OTPR, 1, 0, data));
      }
    for (i = 0; i < 4; i++)
      {
        gpio_leds(pattern[i]);
        sw = gpio_sw();
        sw2 = gpio_sw();
        printf("Switch setting = %X,%X\n", sw, sw2);
        rnd = hwrnd();
        printf("Random seed = %X\n", rnd);
        sw = sw2 & 0xFF;
      }
    switch (sw >> 6)
      {
      case 0x0: printf("SD boot\n"); sd_main(sw); break;
      case 0x1: printf("DRAM test\n"); dram_main(); break;
      case 0x2: printf("TFTP boot\n"); eth_main(); break;
      case 0x3: printf("Cache test\n"); cache_main(); break;
      }
    while (1)
    {
        // do nothing
    }
}

void handle_trap(void)
{
    print_uart("trap\r\n");
}
