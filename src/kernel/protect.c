#include "kernel.h"
#include "protect.h"
#include "prototype.h"
#include "global.h"

/* 全局描述符表GDT */
PUBLIC SegDescriptor_t gdt[GDT_SIZE];
/* 中断描述符表IDT */
PRIVATE Gate_t idt[IDT_SIZE];
/* 任务状态段TSS(Task-State Segment) */
PUBLIC Tss_t tss;

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


    memset((void*)vir2phys(&tss), 0, sizeof(tss));
    tss.ss0 = SELECTOR_KERNEL_DS;
    init_segment_desc(&gdt[TSS_INDEX], vir2phys(&tss), sizeof(tss)-1, DA_386TSS);
    tss.iobase = sizeof(tss);
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