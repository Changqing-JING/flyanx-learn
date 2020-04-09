
extern flyanx_main
extern gdt_ptr
extern idt_ptr
extern cstart
global _start

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

[section .data]
bits 32
    nop


[section .bss]
StackBase: resb 4*1024
StackTop:

