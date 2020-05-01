
#include "kernel.h"
#include "process.h"
#include "protect.h"
#include "flyanx/syslib.h"
int display_position = (80 * 6 + 0) * 2; 



void flyanx_main(){
    
    

    //init all task table element as empty
    register Process_t *proc;
    register int logic_nr;

    for(proc = BEG_PROC_ADDR, logic_nr = -NR_TASKS; proc<END_PROC_ADDR; proc++, logic_nr++){
        if(logic_nr>0){//system sercive
            strcpy(proc->name, "unused");
            

        }
        proc->logic_nr = logic_nr;
        p_proc_addr[logic_nr_2_index(logic_nr)] = proc;
    } 

    //init stack for each process
    SysProc_t* sys_proc;
    reg_t sys_proc_stack_base = (reg_t)sys_proc_stack;
    u8_t privilege;
    u8_t rpl;
    for(logic_nr=-NR_TASKS; logic_nr<=LOW_USER;logic_nr++){
        proc = proc_addr(logic_nr);
        sys_proc = &sys_proc_table[logic_nr_2_index(logic_nr)];
        strcpy(proc->name, sys_proc->name);

        //check if system task or service
        if(logic_nr<0){
            proc->priority = PROC_PRI_TASK;
            rpl = privilege = TASK_PRIVILEGE;
        }else{
             proc->priority = PROC_PRI_SERVER;
            rpl = privilege = SERVER_PRIVILEGE;
        }
        // set stack top of process
        sys_proc_stack_base += sys_proc->stack_size;

        //init ldt
        proc->ldt[CS_LDT_INDEX] = gdt[TEXT_INDEX]; //use same as kernel
        proc->ldt[DS_LDT_INDEX] = gdt[DATA_INDEX];

        //change DPL discriptor
        proc->ldt[CS_LDT_INDEX].access = DA_CR | (privilege<<5);
        proc->ldt[DS_LDT_INDEX].access = DA_DRW | (privilege<<5);

        proc->map.base = KERNEL_DATA_SEG_BASE;
        proc->map.size = 0;//not need to size for kernel

        //set context for process
        proc->regs.cs = (CS_LDT_INDEX * DESCRIPTOR_SIZE) | SA_TIL | rpl;
        proc->regs.ds = (DS_LDT_INDEX * DESCRIPTOR_SIZE) | SA_TIL | rpl;
        proc->regs.es = proc->regs.fs = proc->regs.ss  = proc->regs.ds;
        proc->regs.gs = SELECTOR_KERNEL_GS & SA_RPL_MASK | rpl;
        proc->regs.eip = (reg_t)sys_proc->initial_eip;
        proc->regs.esp = sys_proc_stack_base;
        proc->regs.eflags = is_task_proc(proc) ? INIT_TASK_PSW : INIT_PSW;
        proc->flags = CLEAN_MAP;

        if(!is_idle_hardware(logic_nr)){
            ready(proc);
        }
        

    }

    lock_hunter();

    restart();//start process

    while(1){}
}

void idle_task(){
    printf("idle\n");

    Message_t msg;

    in_outbox(&msg, &msg);
    
    send_rec(CLOCK_TASK, NULL);

    printf("send_rec, get type %d\n", msg.type);

    while(1){
        level0(halt);
    }
}


void panic(
        _CONST char* msg,        /* 错误消息 */
        int error_no            /* 错误代码 */
){
    /* 当flyanx发现无法继续运行下去的故障时将调用它。典型的如无法读取一个很关键的数据块、
     * 检测到内部状态不一致、或系统的一部分使用非法参数调用系统的另一部分等。
     * 这里对printf的调用实际上是调用printk,这样当正常的进程间通信无法使用时核心仍能够
     * 在控制台上输出信息。
     */

    /* 有错误消息的话，请先打印 */
    if(msg != NIL_PTR){
        printf("\n!***** Flyanx kernel panic: %s *****!\n", msg);
        if(error_no != NO_NUM){
            printf("!*****     error no: 0x%x     *****!", error_no);
        }
        printf("\n");
    }
    /* 好了，可以宕机了 */
    down_run();
}