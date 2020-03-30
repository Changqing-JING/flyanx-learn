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

    ;reset floppyDisk
    xor ah, ah
    xor dl, dl
    int 0x13

    ;search for loader.bin

    mov word[wSector], SectorNoOfRootDirectory

search_file_in_root_dir_begin:

    cmp word[wRootDirSizeLoop], 0

    jz no_file ; no file found

    dec word [wRootDirSizeLoop]

    mov si, [wSector]
    ;mov cl, 1; fix me

    mov ax, LOADER_SEG
    mov es, ax
    mov bx,LOADER_OFFSET

    call readSect

    mov si, loader_filename; ds:si
    mov di, LOADER_OFFSET; es:di

    cld

    mov dx, 16; every segment has 16 dirtory elements

search_for_file:
    cmp dx, 0
    jz next_sector_in_root_dir ;no such file, load next segment
    dec dx
    ;compair file name

    mov cx, 11

cmp_filename:
    cmp cx, 0
    jz filename_found; found the file

    dec cx

    lodsb ;load string byte ds:si->al, si++
    cmp al, byte[es: di]; cmp char

    je GO_ON; char same, prepare for next
    jmp different


GO_ON:
    inc di
    jmp cmp_filename

different:
    and di, 0xfff0 ;reset di which is changed by inc

    add di, 32 ;point di to next dictory item

    mov si, loader_filename
    jmp search_for_file; search next dictory item

next_sector_in_root_dir:
    add word[wSector], 1
    jmp search_file_in_root_dir_begin


    
filename_found:
    mov bp, FoundMessage
    call DispStr
    jmp $

no_file:
    mov bp, NoFileMessage
    call DispStr
    jmp $

wRootDirSizeLoop dw RootDirSectors
wSector dw 0

DispStr:
    ; call bios to show string
    push ax
    push bx
    push cx
    push dx

    mov al, 1
    mov bl, 0x7 ;black white
    mov cx, 13 ;string length
    xor dx, dx

    mov ax, ds
    mov es, ax   
    
    xor ax, ax
    mov ah, 0x13
    int 0x10

    pop dx
    pop cx
    pop bx
    pop ax

    ret

;si: logic index
readSect:
    push ax
    push cx
    push dx
    push bx

    mov ax, si
    xor dx, dx
    mov bx, 18
    div bx  ; ax % bx = dx ax/bx = ax
    inc dx
    mov cl, dl

    mov dl, al ; save quotient

    and al, 1
    mov dh, al

    mov al, dl; recover quotient
    shr al, 1

    mov ch, al
    xor dl, dl; device number
    pop bx
rp_read:

    mov ah, 2
    mov al, 1
    ;load data to es:bx
    int 0x13
; when int 0x13 failed, carry flag will be set as 1
;if failed, read again
    jc rp_read 

    ;reverse to push
    pop dx
    pop cx
    
    pop ax

    ret

loader_filename db "LOADER  BIN", 0
BootMessage:    db "Booting......"
FoundMessage:   db "found     it!"
NoFileMessage:  db "no loader    "

times 510 - ($-$$) db 0

dw 0xAA55