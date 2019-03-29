#include <sys/types.h>
#include <stdint.h>
#include "uart.h"
#include "mini-printf.h"
#include "ariane.h"

static const uint8_t pattern[] = {0x55, 0xAA, 0x33, 0xcc};

void gpio_leds(uint32_t arg)
{
  volatile uint32_t *swp = (volatile uint32_t *)GPIOBase;
  swp[0] = arg;
}

uint32_t gpio_sw(void)
{
  volatile uint32_t *swp = (volatile uint32_t *)GPIOBase;
  return swp[2];
}

uint32_t hwrnd(void)
{
  volatile uint32_t *swp = (volatile uint32_t *)GPIOBase;
  swp[4] = 0;
  return swp[4];
}

int main()
{
  uint32_t i, rnd, sw, sw2;
  
    init_uart();
    print_uart("Hello World!\r\n");
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
