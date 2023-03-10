/* Copyright (C) 2007 Free Software Foundation, Inc. 
 * See the copyright notice in the file /usr/LICENSE.
 * Created by flyan on 2019/11/9.
 * QQ: 1341662010
 * QQ-Group:909830414
 * gitee: https://gitee.com/flyanh/
 *
 * 内核所需的类型定义
 */

#ifndef FLYANX_TYPE_H
#define FLYANX_TYPE_H

typedef _PROTOTYPE( void task_t, (void) );
typedef _PROTOTYPE( void (*WatchDog), (void) );

/* 任务表项定义
 * 一个表项可以存放一个系统任务，在这里我们和用户进程表项分开定义了
 * 因为他们特权级不同，待遇也不同，就这个理解就应该让我们区别对待。
 */
typedef struct tasktab_s {
    task_t *initial_pc;         /* 系统任务的处理句柄 */
    int     stack_size;         /* 系统任务的栈大小 */
    char    name[16];           /* 任务名称 */
} TaskTab;

/* 内存区域数据结构定义
 * 定义了唯一确定一片内存区域的两个数值
 */
typedef struct memory_s {
    phys_clicks base;
    phys_clicks size;
} Memory_t;

#if (CHIP == INTEL)
/* 端口数据类型，用于访问I/O端口 */
typedef unsigned port_t;

/* 寄存器数据类型，用于访问存储器段和CPU寄存器 */
typedef unsigned reg_t;

/* stackframe_s定义了如何将寄存器值保存到堆栈上的数据结构
 * 这个结构非常重要-在进程被投入运行状态或被脱开运行状态时,它被用来保
 * 存和恢复CPU的内部状态。将其定义成可以用汇编语言高速读写的格式,这将
 * 减少进程上下文切换的时间，进程指针必须指向这里。
 */
typedef struct stackframe_s {
    /* 低地址 */
    /* =========== 所有的特殊段寄存器，我们手动压入 =========== */
    reg_t	gs;
    reg_t	fs;
    reg_t	es;
    reg_t	ds;
    /* ============== 所有的普通寄存器，我们通过 pushad 手动压入 ============== */
    reg_t	edi;
    reg_t	esi;
    reg_t	ebp;
    reg_t	kernel_esp;	/* pushad 压入的 esp，这个时候已经自动从低特权级到了 0 特权级，
                         * 所以这个其实是从tss.esp0！而 popad 指令也会忽略这个，不会
                         * 恢复它。
                         */
    reg_t	ebx;
    reg_t	edx;
    reg_t	ecx;
    reg_t	eax;
    /* ======= call save()自动保存的返回地址 ======= */
    reg_t	ret_addr;
    /* ============ 中断自动压入的内容 ============= */
    reg_t	eip;        /* 中断门和调用门有一点点不同，那就是中断门还会压入一个eflags */
    reg_t	cs;
    reg_t	eflags;     /* 中断门自动压入 */
    reg_t	esp;
    reg_t   ss;
    /* =========================================== */
    /* 高地址 */
} Stackframe_t;

/* 受保护模式的段描述符
 * 段描述符是与Intel处理器结构相关的另一个结构,它是保证进程
 * 不会发生内存访问越限机制的一部分。
 */
typedef struct seg_descriptor_s {
    u16_t limit_low;        /* 段界限低16位 */
    u16_t base_low;         /* 段基址低16位 */
    u8_t base_middle;       /* 段基址中8位 */
    u8_t access;		    /* 访问权限：| P | DL | 1 | X | E | R | A | */
    u8_t granularity;		/* 比较杂，最重要的有段粒度以及段界限的高4位| G | X  | 0 | A | LIMIT HIGHT | */
    u8_t base_high;         /* 段基址高8位 */
} SegDescriptor_t;

/* 硬件（异常）中断处理函数原型 */
typedef _PROTOTYPE( void (*int_handler_t), (void) );
/* 中断请求处理函数原型 */
typedef _PROTOTYPE( int (*irq_handler_t), (int irq) );
/* 系统调用函数原型 */
typedef _PROTOTYPE( void (*flyanx_syscall_t),  (void) );

typedef struct sys_proc {
    task_t *initial_eip;        /* 系统进程的处理句柄，即 eip */
    int     stack_size;         /* 系统进程的栈大小 */
    char    name[16];           /* 系统进程名称 */
} SysProc_t;

#endif /* (CHIP == INTEL) */

#endif //FLYANX_TYPE_H
