
extern flyanx_main
global _start

[section .text]
_start:
    ;es == fs ==ss == ds, in c compiler, they are equl
    mov ax, ds
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov esp, StackTop

    ;jmp to C main function
    jmp flyanx_main

[section .data]
bits 32
    nop


[section .bss]
StackBase: resb 4*1024
StackTop:

