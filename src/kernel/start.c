
#include "kernel.h"
#include "protect.h"

void cstart(){
    display_position = (80*6 + 2 *0)*2;

    low_print("cstart");
    

    //init protect mode
    protect_init();

    interrupt_init();

    u32_t* p_boot_params = (u32_t*)BOOT_PARAM_ADDR;

    if(p_boot_params[BP_MAGIC]!=BOOT_PARAM_MAGIC){
        low_print("wrong boot magic");
        while(1){};
    }

    boot_params = (BootParams_t*)(BOOT_PARAM_ADDR + 4);//after magic number


}