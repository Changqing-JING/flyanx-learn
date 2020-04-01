[bits 16]
org 0x7c00

;Loader address
LOADER_SEG equ 0x9000
LOADER_OFFSET equ 0x100


global boot
boot:
    jmp start
    nop

    %include "fat12hdr.inc"

StackBase equ 0x7c00

start:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, StackBase

    mov bp, BootMessage
    call DispStr

    jmp start_read_file


%include "DispStr.inc"



FILE_SEG equ LOADER_SEG
FILE_OFFSET equ LOADER_OFFSET
%include "readFileFAT12.asm"

file_loaded_callback:
    mov bp, FinishMessage
    call DispStr
    jmp FILE_SEG:FILE_OFFSET; jump to loader

filename db "LOADER  BIN", 0

times 510 - ($-$$) db 0

dw 0xAA55