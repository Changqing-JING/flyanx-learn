#include "kernel.h"
#include "printk.h"

static int default_irq_handler(int irq){
    k_printf("intrrupt %d", irq);
}

void interrupt_init(){

    out_byte(INT_M_CTL, 17);//0001001b
    out_byte(INT_S_CTL, 17);

    out_byte(INT_M_CTLMASK,32);//first vector of 8259A high_part(controled by ICW2) + low_part(index)
    out_byte(INT_S_CTLMASK,40);

    out_byte(INT_M_CTLMASK,4);
    out_byte(INT_S_CTLMASK,2);

    out_byte(INT_M_CTLMASK,1);
    out_byte(INT_S_CTLMASK,1);

    /* 由于现在还没有配置中断例程，我们屏蔽所有中断，使其都不能发生 */
    out_byte(INT_M_CTLMASK, 0xff);
    out_byte(INT_S_CTLMASK, 0xff);

    for(int i =0;i<NR_IRQ_VECTORS;i++){
        irq_handler_table[i] = default_irq_handler;
    }

    interrupt_unlock();
}

void put_irq_handler(int irq, irq_handler_t handler){
    if(irq>=0 && irq<=15){

        if(irq_handler_table[irq] != handler){

            if(irq_handler_table[irq] == default_irq_handler){

                interrupt_lock();
                irq_handler_table[irq] = handler;
                interrupt_unlock();

            }


        }


    }
}

