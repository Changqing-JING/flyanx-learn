[bits 16]
org 0x7c00
global boot
boot:
    jmp start
    nop

StackBase equ 0x7c00

start:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, StackBase

    ; call bios to show string
    mov al, 1
    mov bl, 0x7 ;black white
    mov cx, 13 ;string length
    xor dl, dl
    xor dh, dh

    mov ax, ds
    mov es, ax

    mov bp, BootMessage
    
    xor ax, ax
    mov ah, 0x13
    int 0x10


BootMessage: db "Booting......"

    jmp $

times 510 - ($-$$) db 0

dw 0xAA55