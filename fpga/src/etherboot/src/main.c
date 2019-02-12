#include "uart.h"

int eth_main(void);

int main()
{
    init_uart();
    print_uart("Hello World!\r\n");
    eth_main();
    while (1)
    {
        // do nothing
    }
}

void handle_trap(void)
{
    print_uart("trap\r\n");
}
