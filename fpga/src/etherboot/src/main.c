#include <sys/types.h>
#include <stdint.h>
#include "uart.h"
#include "mini-printf.h"
#include "ariane.h"
#include "qspi.h"
#include "eth.h"

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

void puthex(unsigned n, int w)
{
  if (w > 1) puthex(n>>4, w-1);
  write_serial("0123456789ABCDEF"[n&15]);
}

void qspi_main(int sw)
{
  uint64_t rslt, rslt2;
  uint32_t i, j, data[2];
  uint8_t *buf = (uint8_t *)0x80000000;
  for (i = 0; i < 0x01000000; i += 8)
      {
        int data_in_count = 5;
        int data_out_count = 8;
        uint32_t off = i + 0x00B00000;
        data[0] = (CMD_4READ << 8) | (off >> 24); // Should locate start of BBL
        data[1] = (off << 8) | (data_in_count << 4) | data_out_count;
        rslt = qspi_send(CMD_4READ, 2, 0, data);
        rslt2 = qspi_send(CMD_4READ, 2, 0, data);
        for (j = 0; j < 8; j++) buf[i+j] = rslt2 >> (7-j)*8;
        if (rslt != rslt2)
          {
            uint8_t compare;
            printf("QSPI read consistency failure\n");
            for (j = 0; j < 8; j++)
              {
                compare = rslt >> (7-j)*8;
                printf("%x : %x\n", compare, buf[i+j]);
              }
          }
        rslt ^= rslt2;
      }
  for (i = 0; i < 0x01000000; i += 0x00100000)
      {
        puthex(i, 8);
        printf(" ");
        for (j = 0; j < 16; j++)
          {
            puthex(buf[i+j], 2);
            printf(" ");
          }
        printf("\n");
      }
  just_jump();
}

int main()
{
  uint32_t i, rnd, sw, sw2;
  init_uart();
  print_uart("Hello World!\r\n");
  for (i = 0; i < 5; i++)
    {
      volatile uint64_t *swp = (volatile uint64_t *)GPIOBase;
      printf("swp[%d] = %X\n", i, swp[i]);
    }
  set_dummy_mac();
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
  switch (sw >> 5)
    {
    case 0x0: printf("SD boot\n"); sd_main(sw); break;
    case 0x1: printf("QSPI boot\n"); qspi_main(sw); break;
    case 0x2: printf("DRAM test\n"); dram_main(); break;
    case 0x4: printf("TFTP boot\n"); eth_main(); break;
    case 0x6: printf("Cache test\n"); cache_main(); break;
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
