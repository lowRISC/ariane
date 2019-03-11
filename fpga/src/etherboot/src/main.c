#include <sys/types.h>
#include <stdint.h>
#include "uart.h"
#include "mini-printf.h"
#include "ariane.h"

int main()
{
  volatile uint32_t *swp = (volatile uint32_t *)GPIOBase;
  uint32_t sw = swp[2];
  
    init_uart();
    print_uart("Hello World!\r\n");
    printf("Switch setting = %X\n", sw);
    //    eth_main();
    switch (sw >> 6)
      {
      case 0: sd_main(sw); break;
      case 1: dram_main(sw); break;
      case 2: eth_main(sw); break;
      case 3: cache_main(sw); break;
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
