[bits 16]

org 0x100
StackBase equ 0x100

jmp start

start:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, StackBase

    mov bp, Message
    call DispStr

    jmp $




%include "DispStr.inc"

Message: db "Hello Loader!"
