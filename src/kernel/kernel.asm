
extern flyanx_main
extern gdt_ptr
extern idt_ptr
extern cstart
extern exception_handler
extern irq_handler_table
extern curr_proc
extern kernel_reenter
extern unhold
global _start
global restart
global down_run
global halt
global level0_sys_call
extern sys_call
global flyanx_386_sys_call

; export all exception handler functions
global divide_error
global single_step_exception
global nmi
global breakpoint_exception
global overflow
global bounds_check
global inval_opcode
global copr_not_available
global double_fault
global copr_seg_overrun
global inval_tss
global segment_not_present
global stack_exception
global general_protection
global page_fault
global copr_error
extern tss
extern level0_func

; 所有中断处理入口，一共16个(两个8259A)
global	hwint00
global	hwint01
global	hwint02
global	hwint03
global	hwint04
global	hwint05
global	hwint06
global	hwint07
global	hwint08
global	hwint09
global	hwint10
global	hwint11
global	hwint12
global	hwint13
global	hwint14
global	hwint15

%include "asm_const.inc"

[section .text]
_start:
    ;es == fs ==ss == ds, in c compiler, they are equl
    mov ax, ds
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov esp, StackTop

    ;copy gdt to kernel
    sgdt [gdt_ptr]

    call cstart

    lgdt [gdt_ptr] ;reload gdt after move gdt to kernel
    lidt [idt_ptr]

    jmp csinit

csinit:

    xor eax, eax
    mov ax, SELECTOR_TSS
    ltr ax

    ;jmp to C main function
    jmp flyanx_main
;----------------exception handler-------------------------
divide_error:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	0		    ; 中断向量号	= 0
	jmp	exception
single_step_exception:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	1		    ; 中断向量号	= 1
	jmp	exception
nmi:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	2		    ; 中断向量号	= 2
	jmp	exception
breakpoint_exception:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	3		    ; 中断向量号	= 3
	jmp	exception
overflow:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	4		    ; 中断向量号	= 4
	jmp	exception
bounds_check:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	5		    ; 中断向量号	= 5
	jmp	exception
inval_opcode:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	6		    ; 中断向量号	= 6
	jmp	exception
copr_not_available:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	7		    ; 中断向量号	= 7
	jmp	exception
double_fault:
	call save
	push	8		    ; 中断向量号	= 8
	jmp	exception
copr_seg_overrun:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	9		    ; 中断向量号	= 9
	jmp	exception
inval_tss:
	call save
	push	10		    ; 中断向量号	= 10
	jmp	exception
segment_not_present:
	call save
	push	11		    ; 中断向量号	= 11
	jmp	exception
stack_exception:
	call save
	push	12		    ; 中断向量号	= 12
	jmp	exception
general_protection:
	call save
	push	13		    ; 中断向量号	= 13
	jmp	exception
page_fault:
	call save
	push	14		    ; 中断向量号	= 14
	jmp	exception
copr_error:
	call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	16		    ; 中断向量号	= 16
	jmp	exception

exception:
	call	exception_handler
	add	esp, 4 * 2	    ; 让栈顶指向 EIP，堆栈中从顶向下依次是：EIP、CS、EFLAGS
	ret
.down:
	hlt                 ; CPU停止运转，宕机
    jmp .down

;============================================================================
;   硬件中断处理
;----------------------------------------------------------------------------
; 为 主从两个8259A 各定义一个中断处理模板
;----------------------------------------------------------------------------
%macro  hwint_master 1
	call save
    in al, INT_M_CTLMASK ;load 8259 shield mask map
    or al, (1<<%1)
	out INT_M_CTLMASK, al

	
    mov al, EOI
    out INT_M_CTL, al
    nop
    sti

    push %1
    call [irq_handler_table + 4*%1]
    add esp, 4

    cli
    cmp eax, 0
    je .0
    in al, INT_M_CTLMASK
    and al, ~(1<<%1)
    out INT_M_CTLMASK, al

.0:
    sti
    ret

%endmacro
align	16
hwint00:		; Interrupt routine for irq 0 (the clock)，时钟中断
 	hwint_master	0

align	16
hwint01:		; Interrupt routine for irq 1 (keyboard)，键盘中断
 	hwint_master	1

align	16
hwint02:		; Interrupt routine for irq 2 (cascade!)
 	hwint_master	2

align	16
hwint03:		; Interrupt routine for irq 3 (second serial)
 	hwint_master	3

align	16
hwint04:		; Interrupt routine for irq 4 (first serial)
 	hwint_master	4

align	16
hwint05:		; Interrupt routine for irq 5 (XT winchester)
 	hwint_master	5

align	16
hwint06:		; Interrupt routine for irq 6 (floppy)，软盘中断
 	hwint_master	6

align	16
hwint07:		; Interrupt routine for irq 7 (printer)，打印机中断
 	hwint_master	7
;----------------------------------------------------------------------------
%macro  hwint_slave 1

	call save ;save stack when switch process
    ; 1 在调用对于中断的处理例程前，先屏蔽当前中断，防止短时间内连续发生好几次同样的中断
    in al, INT_M_CTLMASK    ; 取出 主8259A 当前的屏蔽位图
    or al, (1 << (%1 - 8)) ; 将该中断的屏蔽位置位，表示屏蔽它
    out INT_M_CTLMASK, al   ; 输出新的屏蔽位图，屏蔽该中断

    ; 2 重新启用 主从8259A 和中断响应；因为 从8259A 的中断会级联导致 主8259A也被关闭，所以需要两个都重新启用
    mov al, EOI
    out INT_M_CTL, al       ; 设置 EOI 位，重新启用 主8259A
    nop
    out INT_S_CTL, al       ; 设置 EOI 位，重新启用 从8259A
    sti                     ; 重新启动中断响应

    ; 3 现在调用中断处理例程
    push %1                 ; 压入中断向量号作为参数
    call [irq_handler_table + (4 * %1)] ; 调用中断处理程序表中的相应处理例程，返回值存放在 eax 中
    add esp, 4              ; 清理堆栈

    ; 4 最后，判断用户的返回值，如果是DISABLE(0)，我们就直接结束；如果不为0，那么我们就重新启用当前中断
    cli                     ; 先将中断响应关闭，这个时候不允许其它中断的干扰
    cmp eax, DISABLE
    je .0                   ; 返回值 == DISABLE，直接结束中断处理
    ; 返回值 != DISABLE，重新启用当前中断
    in al, INT_M_CTLMASK    ; 取出 主8259A 当前的屏蔽位图
    and al, ~(1 <<(%1 - 8))      ; 将该中断的屏蔽位复位，表示启用它
    out INT_M_CTLMASK, al   ; 输出新的屏蔽位图，启用该中断

.0:
    sti
    ret
%endmacro
;----------------------------------------------------------------------------
align	16
hwint08:		; Interrupt routine for irq 8 (realtime clock).
 	hwint_slave	8

align	16
hwint09:		; Interrupt routine for irq 9 (irq 2 redirected)
 	hwint_slave	9

align	16
hwint10:		; Interrupt routine for irq 10
 	hwint_slave	10

align	16
hwint11:		; Interrupt routine for irq 11
 	hwint_slave	11

align	16
hwint12:		; Interrupt routine for irq 12
 	hwint_slave	12

align	16
hwint13:		; Interrupt routine for irq 13 (FPU exception)
 	hwint_slave	13

align	16
hwint14:		; Interrupt routine for irq 14 (AT winchester)
 	hwint_slave	14

align	16
hwint15:		; Interrupt routine for irq 15
 	hwint_slave	15

[section .data]
bits 32
    nop

;save stack when switch process
save:

	;push to curr_proc
	;general registers
	;return address 
	;auto save interrupt 
	

	pushad

	push ds
	push es
	push fs
	push gs

	;recover kernel data segment

	mov dx, ss
	mov ds, dx
	mov es, dx

	mov esi, esp

	;check if current context is already kernel
	inc byte [kernel_reenter]
	cmp byte [kernel_reenter], 0
	jnz .reenter
	mov esp, StackTop ;switch to kernel stack
	push restart
	jmp .return
.reenter:
	push restart_reenter
	

.return:
	jmp [esi + RETADDR] ; return process return address

flyanx_386_sys_call:
	call save

	push ebx
	push eax
	push ecx

	call sys_call

	add esp, 4*3

	ret



restart:
	call unhold
over_unhold:
	mov esp, [curr_proc]; ;exit kernel esp->process stack

	lldt [esp + P_LDT_SEL] ; each process has its ldt

	;save ldt_sel to tss.sp0 as the stack top of next save
	lea eax, [esp + P_STACKTOP]
	mov dword[tss + TSS3_S_SP0], eax

restart_reenter:
	;kernel_reenter-1
	dec byte[kernel_reenter]

	pop gs
	pop fs
	pop es
	pop ds
	popad

	add esp, 4;scap ret_addr

	iretd; return interrupt

down_run:
    hlt
    jmp down_run

halt:
	sti
	hlt
	cli
	ret

;Task PRIVILEGE to kernel
level0_sys_call:
    call save
	jmp [level0_func]
	ret

[section .bss]
StackSpace: resb 4*1024
StackTop:

