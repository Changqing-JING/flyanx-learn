

org 0x100
StackBase equ 0x100
FILE_HAVE_SPACE equ 0x2000 * 0x10
jmp start

%include "load.inc"
%include "fat12hdr.inc"

start:
    mov ax, cs
    mov es, ax
    mov ds, ax
    mov ss, ax
    mov sp, StackBase

    mov bp, Message
    call DispStr

    xor ebx, ebx ;start with 0
    mov di, _MemChkBUf
;save ARDS in es:di
MemChkLoop:
    mov eax, 0x0000e820
    mov ecx, 20
    mov edx, 0x0534d4150
    int 0x15
    jc MemChkFail  ;CF == 1
    ; CF == 0
    add di, 20
    inc dword [_ddMCRCount]

    cmp ebx, 0
    je MemChkFinish;ebx==0 mean last one
    jmp MemChkLoop

MemChkFail:
    mov dword [_ddMCRCount], 0
    mov bp, MessageMemChkFailed
    call DispStr
    jmp $
MemChkFinish:
    mov bp, MessageMemChkSuccess
    call DispStr

    jmp start_read_file



%include "DispStr.inc"


FILE_SEG equ KERNEL_SEG
FILE_OFFSET equ KERNEL_OFFSET
%include "readFileFAT12.asm"

file_loaded_callback:

    call KillMotor

    mov bp, MessageKernel
    call DispStr
    jmp $

KillMotor:
    push	dx
    push ax
 	mov	dx, 03F2h
 	xor	al, al
 	out	dx, al
    pop ax
 	pop	dx
    ret


filename: db "KERNEL  BIN", 0
Message: db "Hello Loader!"
MessageKernel: db "Hello Kernel!"
MessageMemChkSuccess: db "Mem Chk OK   "
MessageMemChkFailed: db "Mem Chk Fail "

;16bits data

_ddMCRCount dd 0 ;memory check result , how many ADRS is got
_ddMemSize dd 0

;Address Range Descriptor Struct
_ADRS:
    _addbaseAddLow dd 0
    _addbaseAddHigh dd 0
    _addbaseLengthLow dd 0
    _addbaseLengthHeigh dd 0
    _ddType dd 0

;256/20 = 12.8 can contain 12 ARDS
_MemChkBUf: times 256 db 0

;32bit data
[section data32]
align 32
data32:




