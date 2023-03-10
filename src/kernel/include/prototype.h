/* Copyright (C) 2007 Free Software Foundation, Inc. 
 * See the copyright notice in the file /usr/LICENSE.
 * Created by flyan on 2019/11/9.
 * QQ: 1341662010
 * QQ-Group:909830414
 * gitee: https://gitee.com/flyanh/
 *
 * 内核所需的所有函数原型
 * 所有那些必须在其定义所在文件外被感知的函数的原型都放在proto.h中。
 *
 * 它使用了_PROTOTYPE技术，这样，Flyanx核心便既可以使用传统的C编译器(由Kernighan和Richie定义)，
 * 例如Minix初始提供的编译器；又可以使用一个现代的ANSI标准C编译器。
 *
 * 这其中的许多函数原型是与系统相关的,包括中断和异常处理例程以及用汇编语言写的一些函数。
 */

#ifndef FLYANX_PROTOTYPE_H
#define FLYANX_PROTOTYPE_H

/* 结构体声明 */
#include "sys/times.h"
struct process_s;

/*================================================================================================*/
/* kernel.asm */
/*================================================================================================*/

/*================================================================================================*/
/* start.c */
/*================================================================================================*/
_PROTOTYPE( void cstart, (void) );

/*================================================================================================*/
/* protect.c */
/*================================================================================================*/
_PROTOTYPE( void init_segment_desc, (SegDescriptor_t *p_desc, phys_bytes base,phys_bytes limit, u16_t attribute) );
_PROTOTYPE( phys_bytes seg2phys, (U16_t seg) );
_PROTOTYPE( void protect_init, (void) );

/*================================================================================================*/
/* kernel_386lib.asm */
/*================================================================================================*/
#define phys_copy( _src,  _dest,  _size) memcpy((void*)_dest, (void*)_src, _size)
_PROTOTYPE( void low_print, (char* _str) );


/*================================================================================================*/
/* 异常处理入口例程 */
/*================================================================================================*/
_PROTOTYPE( void divide_error, (void) );
_PROTOTYPE( void single_step_exception, (void) );
_PROTOTYPE( void nmi, (void) );
_PROTOTYPE( void breakpoint_exception, (void) );
_PROTOTYPE( void overflow, (void) );
_PROTOTYPE( void bounds_check, (void) );
_PROTOTYPE( void inval_opcode, (void) );
_PROTOTYPE( void copr_not_available, (void) );
_PROTOTYPE( void double_fault, (void) );
_PROTOTYPE( void inval_tss, (void) );
_PROTOTYPE( void copr_not_available, (void) );
_PROTOTYPE( void segment_not_present, (void) );
_PROTOTYPE( void stack_exception, (void) );
_PROTOTYPE( void general_protection, (void) );
_PROTOTYPE( void page_fault, (void) );
_PROTOTYPE( void copr_seg_overrun, (void) );
_PROTOTYPE( void copr_error, (void) );
_PROTOTYPE( void divide_error, (void) );
_PROTOTYPE( u8_t in_byte, (port_t port) );
_PROTOTYPE( void out_byte, (port_t port, U8_t value) );
_PROTOTYPE( u16_t in_word, (port_t port) );
_PROTOTYPE( void out_word, (port_t port, U16_t value) );

/*================================================================================================*/
/*  硬件中断处理程序。 */
/*================================================================================================*/
_PROTOTYPE( void	hwint00, (void) );
_PROTOTYPE( void	hwint01, (void) );
_PROTOTYPE( void	hwint02, (void) );
_PROTOTYPE( void	hwint03, (void) );
_PROTOTYPE( void	hwint04, (void) );
_PROTOTYPE( void	hwint05, (void) );
_PROTOTYPE( void	hwint06, (void) );
_PROTOTYPE( void	hwint07, (void) );
_PROTOTYPE( void	hwint08, (void) );
_PROTOTYPE( void	hwint09, (void) );
_PROTOTYPE( void	hwint10, (void) );
_PROTOTYPE( void	hwint11, (void) );
_PROTOTYPE( void	hwint12, (void) );
_PROTOTYPE( void	hwint13, (void) );
_PROTOTYPE( void	hwint14, (void) );
_PROTOTYPE( void	hwint15, (void) );
_PROTOTYPE(  void interrupt_lock, (void) );
_PROTOTYPE(  void interrupt_unlock, (void) );
_PROTOTYPE( int disable_irq, (int int_request) );
_PROTOTYPE( void enable_irq, (int int_request) );
_PROTOTYPE( u8_t cmos_read, (u8_t addr) );

void interrupt_init();
void put_irq_handler(int irq, irq_handler_t handler);
void clock_task();
_PROTOTYPE( void restart, (void) );
_PROTOTYPE( void halt, (void) );
_PROTOTYPE( int k_printf, (const char* fmt, ...) );
_PROTOTYPE( int printk, (const char* fmt, ...) );
_PROTOTYPE( void down_run, (void) );
_PROTOTYPE( void panic, (const char* msg, int error_no ) );
_PROTOTYPE( void idle_task, (void) );
_PROTOTYPE( void level0_sys_call, (void) );
_PROTOTYPE( void level0, (flyanx_syscall_t level0_func) );

/* process.c */
/*================================================================================================*/
void lock_schedule(void);
void lock_unready(struct process_s* proc);
void lock_ready(struct process_s* proc);
void lock_hunter(void);
void schedule_stop();
void ready( struct process_s* proc);
void unready( struct process_s* proc);

_PROTOTYPE( void msg_copy, (phys_bytes msg_phys, phys_bytes dest_phys) );

_PROTOTYPE( void flyanx_386_sys_call, (void) );

int flyanx_send(struct process_s* caller, int dest, Message_t* msg_phys);
int flyanx_receive(struct process_s* caller, int dest, Message_t* msg_phys);

void proc_dump();
void map_dump();

void get_rtc_time(RTCTime_t *p_time);

void unhold();
void interrupt(int task);

void milli_delay(time_t delay_ms);

void keyboard_init();

#endif //FLYANX_PROTOTYPE_H
