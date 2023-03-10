#include "kernel.h"
#include "protect.h"
#include "prototype.h"
#include "global.h"
#include "process.h"
/* 全局描述符表GDT */
PUBLIC SegDescriptor_t gdt[GDT_SIZE];
/* 中断描述符表IDT */
PRIVATE Gate_t idt[IDT_SIZE];
/* 任务状态段TSS(Task-State Segment) */
PUBLIC Tss_t tss;

struct gate_desc_s {
    u8_t vector;            /* 中断向量号 */
    int_handler_t handler;  /* 处理例程 */
    u8_t privilege;         /* 门权限 */
};


struct gate_desc_s int_gate_table[] = {
        /* ************* 异常 *************** */
        { INT_VECTOR_DIVIDE, divide_error, KERNEL_PRIVILEGE },
        { INT_VECTOR_DEBUG, single_step_exception, KERNEL_PRIVILEGE },
        { INT_VECTOR_NMI, nmi, KERNEL_PRIVILEGE },
        { INT_VECTOR_BREAKPOINT, breakpoint_exception, KERNEL_PRIVILEGE },
        { INT_VECTOR_OVERFLOW, overflow, KERNEL_PRIVILEGE },
        { INT_VECTOR_BOUNDS, bounds_check, KERNEL_PRIVILEGE },
        { INT_VECTOR_INVAL_OP, inval_opcode, KERNEL_PRIVILEGE },
        { INT_VECTOR_COPROC_NOT, copr_not_available, KERNEL_PRIVILEGE },
        { INT_VECTOR_DOUBLE_FAULT, double_fault, KERNEL_PRIVILEGE },
        { INT_VECTOR_COPROC_SEG, copr_seg_overrun, KERNEL_PRIVILEGE },
        { INT_VECTOR_INVAL_TSS, inval_tss, KERNEL_PRIVILEGE },
        { INT_VECTOR_SEG_NOT, segment_not_present, KERNEL_PRIVILEGE },
        { INT_VECTOR_STACK_FAULT, stack_exception, KERNEL_PRIVILEGE },
        { INT_VECTOR_PROTECTION, general_protection, KERNEL_PRIVILEGE },
        { INT_VECTOR_PAGE_FAULT, page_fault, KERNEL_PRIVILEGE },
        { INT_VECTOR_COPROC_ERR, copr_error, KERNEL_PRIVILEGE },
         /* ************* 硬件中断 *************** */
        { INT_VECTOR_IRQ0 + 0, hwint00, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ0 + 1, hwint01, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ0 + 2, hwint02, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ0 + 3, hwint03, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ0 + 4, hwint04, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ0 + 5, hwint05, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ0 + 6, hwint06, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ0 + 7, hwint07, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ8 + 0, hwint08, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ8 + 1, hwint09, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ8 + 2, hwint10, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ8 + 3, hwint11, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ8 + 4, hwint12, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ8 + 5, hwint13, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ8 + 6, hwint14, KERNEL_PRIVILEGE },
        { INT_VECTOR_IRQ8 + 7, hwint15, KERNEL_PRIVILEGE },
         { INT_VECTOR_LEVEL0, level0_sys_call, TASK_PRIVILEGE },
         { INT_VECTOR_SYS_CALL, flyanx_386_sys_call, USER_PRIVILEGE },
        /* ************* 软件中断 *************** */
};

PRIVATE void init_gate(
        u8_t vector,
        u8_t desc_type,
        int_handler_t  handler,
        u8_t privilege
)
{
    // 得到中断向量对应的门结构
    Gate_t* p_gate = &idt[vector];
    // 取得处理函数的基地址
    u32_t base_addr = (u32_t)handler;
    // 一一赋值
    p_gate->offset_low = base_addr & 0xFFFF;
    p_gate->selector = SELECTOR_KERNEL_CS;
    p_gate->dcount = 0;
    p_gate->attr = desc_type | (privilege << 5);
#if _WORD_SIZE == 4
    p_gate->offset_high = (base_addr >> 16) & 0xFFFF;
#endif
}
#define phys_copy( _src,  _dest,  _size) memcpy((void*)_dest, (void*)_src, _size)

void protect_init(){
    

    u32_t src = *((u32_t*)vir2phys(&gdt_ptr[2]));

    u32_t dist = vir2phys(&gdt);

    u16_t size = *((u16_t*)vir2phys(&gdt_ptr[0])) + 1;

    //copy old GDT in Loader to Kernel
    phys_copy(src, dist,size);
    //address in GDT ptr is still loader address, change address in GDT ptr
    u16_t* p_gdt_limit = (u16_t*)&gdt_ptr[0];
    u32_t* p_gdt_base = (u32_t*)&gdt_ptr[2];
    *p_gdt_limit = GDT_SIZE * DESCRIPTOR_SIZE -1;
    *p_gdt_base = vir2phys(&gdt);

    u16_t* p_idt_limit = (u16_t*)&idt_ptr[0];
    u32_t* p_idt_base = (u32_t*)&idt_ptr[2];
    *p_idt_limit = IDT_SIZE * sizeof(Gate_t) -1;
    *p_idt_base = vir2phys(&idt);

    // add interrupt gate into idt
     struct gate_desc_s* p_gate = &int_gate_table[0];

     for(; p_gate < &int_gate_table[sizeof(int_gate_table) / sizeof(struct gate_desc_s)]; p_gate++){
        init_gate(p_gate->vector, DA_386IGate, p_gate->handler, p_gate->privilege);
    }

    //for calling fucntion in different ring
    memset((void*)vir2phys(&tss), 0, sizeof(tss));
    tss.ss0 = SELECTOR_KERNEL_DS;
    init_segment_desc(&gdt[TSS_INDEX], vir2phys(&tss), sizeof(tss)-1, DA_386TSS);
    tss.iobase = sizeof(tss);


    //asign ldt for each process;
    Process_t *proc = proc_table;
    int ldt_idx = LDT_FIRST_INDEX;

    for(;proc<END_PROC_ADDR;proc++, ldt_idx++){
        memset(proc, 0, sizeof(Process_t));
        init_segment_desc(&gdt[ldt_idx], vir2phys(proc->ldt), sizeof(proc->ldt)-1, DA_LDT);
        proc->ldt_sel = ldt_idx * DESCRIPTOR_SIZE;
    }
}

phys_bytes seg2phys(U16_t seg)
{
    SegDescriptor_t* p_dest = &gdt[seg >> 3];
    return (p_dest->base_high << 24 | p_dest->base_middle << 16 | p_dest->base_low);
}

void init_segment_desc(
        SegDescriptor_t *p_desc,
        phys_bytes base,
        phys_bytes limit,
        u16_t attribute
)
{
    /* 初始化一个数据段描述符 */
    p_desc->limit_low	= limit & 0x0FFFF;         /* 段界限 1		(2 字节) */
    p_desc->base_low	= base & 0x0FFFF;          /* 段基址 1		(2 字节) */
    p_desc->base_middle	= (base >> 16) & 0x0FF;     /* 段基址 2		(1 字节) */
    p_desc->access		= attribute & 0xFF;         /* 属性 1 */
    p_desc->granularity = ((limit >> 16) & 0x0F) |  /* 段界限 2 + 属性 2 */
                          ((attribute >> 8) & 0xF0);
    p_desc->base_high	= (base >> 24) & 0x0FF;     /* 段基址 3		(1 字节) */
}