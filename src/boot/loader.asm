[bits 16]

org 0x100
StackBase equ 0x100

jmp start

start:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, StackBase

    call DispStr

    jmp $




DispStr:

    push ax
    push bx
    push cx
    push dx

    ; call bios to show string
    mov al, 1
    mov bl, 0x7 ;black white
    mov cx, 13 ;string length
    xor dl, dl
    xor dh, dh

    mov ax, ds
    mov es, ax

    mov bp, Message
    
    xor ax, ax
    mov ah, 0x13
    int 0x10

    pop dx
    pop cx
    pop bx
    pop ax
    ret 

Message: db "Hello Loader!"
