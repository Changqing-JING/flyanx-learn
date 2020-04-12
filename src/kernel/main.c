#include "printk.h"
int display_position = (80 * 6 + 0) * 2; 

void low_print(const char * s);

void flyanx_main(){
    
    low_print("Hello OS");

    k_printf("test printk, %d, %x\n", 0x328, 0x328);
    k_printf("aabb\n");
    k_printf("ccdd");
    while(1){}
}