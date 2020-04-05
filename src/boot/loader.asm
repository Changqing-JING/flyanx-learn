

org 0x100
StackBase equ 0x100
FILE_HAVE_SPACE equ 0x2000 * 0x10
jmp start

%include "load.inc"
%include "fat12hdr.inc"
%include "pm.inc"

;GDT
LABEL_GDT: Descriptor 0, 0, 0
LABEL_DESC_CODE:	Descriptor	0,          0xfffff,    DA_32 | DA_CR | DA_LIMIT_4K	; 0~4G，32位可读代码段，粒度为4KB
LABEL_DESC_DATA:    Descriptor  0,          0xfffff,    DA_32 | DA_DRW | DA_LIMIT_4K; 0~4G，32位可读写数据段，粒度为4KB
LABEL_DESC_VIDEO:   Descriptor  0xb8000,    0xfffff,    DA_DRW | DA_DPL3            ; 视频段，特权级3（用户特权级）

GDTLen equ $-LABEL_GDT
GDTPtr dw GDTLen-1
       dd LOADER_PHY_ADDR + LABEL_GDT

SelectorCode equ LABEL_DESC_CODE - LABEL_GDT
SelectorData equ LABEL_DESC_DATA - LABEL_GDT
SelectorVideo equ (LABEL_DESC_VIDEO - LABEL_GDT) | SA_RPL3

start:
    mov ax, cs
    mov es, ax
    mov ds, ax
    mov ss, ax
    mov sp, StackBase

    mov bp, Message
    call DispStr

    xor ebx, ebx ;start with 0
    mov di, _MemChkBuf
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
    
    lgdt [GDTPtr]
    
    cli

    mov al, 0xdf
    out 0x64, al

    mov eax, cr0
    or eax, 1

    mov cr0, eax

    ;enter 32bit code
    jmp dword SelectorCode:PM_32_start+LOADER_PHY_ADDR
    

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

;_ddMCRCount dd 0 ;memory check result , how many ARDS is got
;_ddMemSize dd 0

;Address Range Descriptor Struct
;_ADRS:
  ;  _addbaseAddLow dd 0
  ;  _addbaseAddHigh dd 0
  ;  _addbaseLengthLow dd 0
   ; _addbaseLengthHeigh dd 0
  ;  _ddType dd 0

;256/20 = 12.8 can contain 12 ARDS
;_MemChkBUf: times 256 db 0


;32bit code
[section .code32]
align 32
[bits 32]

PM_32_start:
    mov ax, SelectorData
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax

    mov esp,TopOfStack

    mov ax, SelectorVideo
    mov gs, ax

    ;print "PM"
    mov edi, (80*9+0)*2
    mov ah, 0xC
    mov al, 'P'
    mov word[gs:edi], ax

    add edi, 2
    mov al, 'M'
    mov word[gs:edi], ax

    call calMemSize
    ;print Memory size
    call PrintMemSize

    jmp $

;calculate memory size based on ARDS
calMemSize:

    push esi
    push ecx
    push edx
    push edi

    mov esi, MemChkBuf
    mov ecx, [ddMCRCount] ;i

.loopi:
    mov edx, 5 ;ARDS has 5 members, j
    mov edi, ARDS ;ds:edi->ARDS

.1:
    ;mov number i ARDS in buffer into ds:edi
    mov eax, dword [esi]

    stosd   ;copy ds:eax to ds:edi

    add esi, 4

    dec edx

    cmp edx, 0
    jnz .1

    cmp dword [ddType], 1
    jne .2 ; not valid address for os

    ; eax = base_address_low + length_low
    ; 32bits CPU only have low part, the High part is only for 64bits cpu
    mov eax, [ddBaseAddrLow]
    add eax, [ddLengthLow]

    cmp eax, [ddMemSize]
    jb .2

    mov dword [ddMemSize], eax


    
.2:
    loop .loopi

    pop edi
    pop edx
    pop ecx
    pop esi

    ret

PrintMemSize:
    push ebx
    push ecx

    mov eax, [ddMemSize]
    shr eax, 10 ;memory/1024 to kb

    push eax
    ;print "Memory size %d"
    push strMemSize
    call Print
    add esp, 4

    call PrintInt
    add esp, 4

    ;print "KB"
    push strKB
    call Print
    add esp, 4

    pop ecx
    pop ebx
    ret

;print(void* ds:ptr), ptr: a string end with '/0'
Print:
    push esi
    push edi
    push ebx
    push ecx
    push edx

    mov esi, [esp+4*6]

    mov edi, [ddDispPosition]
    mov ah, 0xf
.1:
    lodsb; ds:esi->al, esi++
    test al, al
    jz .PrintEnd
    cmp al, 10
    je .2
    ;if not 0 and not '\n', print it
    mov [gs:edi], ax
    add edi, 2
    jmp .1

.2:
    push eax
    mov eax, edi
    mov bl, 160
    div bl
    inc eax; row++
    mov bl, 160
    mul bl
    mov edi, eax

    pop eax
    jmp .1

.PrintEnd:
    mov dword [ddDispPosition], edi


    pop edx
    pop ecx
    pop ebx
    pop edi
    pop esi
    ret

PrintAl:
	push ecx
	push edx
	push edi
	push eax

	mov edi, [ddDispPosition]	; 得到显示位置

	mov ah, 0Fh		; 0000b: 黑底	1111b: 白字
	mov dl, al
	shr al, 4
	mov ecx, 2
.begin:
	and al, 01111b
	cmp al, 9
	ja	.1
	add al, '0'
	jmp	.2
.1:
	sub al, 10
	add al, 'A'
.2:
	mov [gs:edi], ax
	add edi, 2

	mov al, dl
	loop .begin

	mov [ddDispPosition], edi	; 显示完毕后，设置新的显示位置

    pop eax
	pop edi
	pop edx
	pop ecx

	ret
;============================================================================
;   显示一个整形数
;----------------------------------------------------------------------------
PrintInt:
    mov	ah, 0Fh			; 0000b: 黑底    1111b: 白字
    mov	al, '0'
    push	edi
    mov	edi, [ddDispPosition]
    mov	[gs:edi], ax
    add edi, 2
    mov	al, 'x'
    mov	[gs:edi], ax
    add	edi, 2
    mov	[ddDispPosition], edi	; 显示完毕后，设置新的显示位置
    pop edi

	mov	eax, [esp + 4]
	shr	eax, 24
	call	PrintAl

	mov	eax, [esp + 4]
	shr	eax, 16
	call	PrintAl

	mov	eax, [esp + 4]
	shr	eax, 8
	call	PrintAl

	mov	eax, [esp + 4]
	call	PrintAl

	ret

;32bit data
[section data32]
align 32
data32:
;----------------------------------------------------------------------------
;   16位实模式下的数据地址符号
;----------------------------------------------------------------------------
_ddMCRCount:        dd 0        ; 检查完成的ARDS的数量，为0则代表检查失败
_ddMemSize:         dd 0        ; 内存大小
; 地址范围描述符结构(Address Range Descriptor Structure)
_ARDS:
    _ddBaseAddrLow:  dd 0        ; 基地址低32位
    _ddBaseAddrHigh: dd 0        ; 基地址高32位
    _ddLengthLow:    dd 0        ; 内存长度（字节）低32位
    _ddLengthHigh:   dd 0        ; 内存长度（字节）高32位
    _ddType:         dd 0        ; ARDS的类型，用于判断是否可以被OS使用
; 内存检查结果缓冲区，用于存放没存检查的ARDS结构，256字节是为了对齐32位，256/20=12.8
; ，所以这个缓冲区可以存放12个ARDS。
_MemChkBuf:          times 256 db 0
_ddDispPosition: dd (80*4 + 0)*2 ; row 4 column 0
_strMemSize: dd "Memory size:", 0
_strKB: dd " KB", 0

ddMCRCount equ LOADER_PHY_ADDR + _ddMCRCount
ddMemSize equ LOADER_PHY_ADDR + _ddMemSize
ARDS equ LOADER_PHY_ADDR + _ARDS
    ddBaseAddrLow equ LOADER_PHY_ADDR + _ddBaseAddrLow
    ddBaseAddrHigh equ LOADER_PHY_ADDR + _ddBaseAddrHigh
    ddLengthLow equ LOADER_PHY_ADDR + _ddLengthLow
    ddLengthHigh equ LOADER_PHY_ADDR + _ddLengthHigh
    ddType equ LOADER_PHY_ADDR + _ddType

MemChkBuf equ LOADER_PHY_ADDR + _MemChkBuf
ddDispPosition equ LOADER_PHY_ADDR + _ddDispPosition
strMemSize equ LOADER_PHY_ADDR + _strMemSize
strKB equ LOADER_PHY_ADDR + _strKB
StackSpace: times 0x1000 db 0
TopOfStack: equ $ + LOADER_PHY_ADDR




