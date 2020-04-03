


start_read_file:
    ;reset floppyDisk
    xor ah, ah
    xor dl, dl
    int 0x13

    ;search for loader.bin

    mov word[wSector], SectorNoOfRootDirectory
    jmp search_file_in_root_dir_begin

search_file_in_root_dir_begin:

    cmp word[wRootDirSizeLoop], 0

    jz no_file ; no file found

    dec word [wRootDirSizeLoop]

    

    mov ax, FILE_SEG
    mov es, ax
    mov bx,FILE_OFFSET

    mov ax, [wSector]
    mov cl, 1

    call readSect

    mov si, filename; ds:si
    mov di, FILE_OFFSET; es:di

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

    mov si, filename
    jmp search_for_file; search next dictory item

next_sector_in_root_dir:
    inc word[wSector]
    jmp search_file_in_root_dir_begin


    
filename_found:

    and di, 0xfff0
    mov eax, [es:di + 0x1c]     ; FAT目录项第0x1c处偏移是文件大小

    mov dword [fileSize], eax; fix me

    cmp eax, FILE_HAVE_SPACE

    ja FILE_TOO_LARGE

    mov bp, FoundMessage
    call DispStr
    
    mov ax, RootDirSectors
    
    add di, 0x1a

    mov cx, word [es:di]; first cluster index of file

    
    push cx

    add cx, ax
    add cx, DeltaSectorNo; cluster_index + dictory_space + file_start_Sector= file_start_sector_index

    mov ax, FILE_SEG
    mov es, ax
    mov bx, FILE_OFFSET

    mov ax, cx; ax = file_start_sector_index

loading_file:

    mov cl, 1
    call readSect

    pop ax; recover first cluster index
    call get_fat_entry
    cmp ax, 0xff8
    jae file_loaded_callback

    ;load next one
    push ax
    add ax, RootDirSectors
    add ax, DeltaSectorNo
    add bx, [BPB_BytsPerSec]
    jc FILE_GREAT_64KB
    jmp loading_file

FILE_GREAT_64KB:
    ; es += 0x1000，es指向下一个段，准备继续加载
    push ax
    mov ax, es
    add ax, 0x1000
    mov es, ax
    pop ax
    jmp loading_file

FILE_TOO_LARGE:
    mov bp, KernelTooLargeMessage
    call DispStr                ; 打印"Too Large!"
    jmp $     



no_file:
    mov bp, NoFileMessage
    call DispStr
    jmp $


;si: logic index
readSect:
    push ax
    push dx
    push cx
    push bx

    mov si, cx
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
    mov ax, si
    mov ah, 2
    ;load data to es:bx
    int 0x13
; when int 0x13 failed, carry flag will be set as 1
;if failed, read again
    jc rp_read 

    ;reverse to push
    pop cx
    pop dx
    pop ax

    ret

;find a cluster index as ax, return its index in fat item in ax
get_fat_entry:
    push es
    push bx

    mov bx, FILE_SEG - 0x100
    mov es, bx

    ;calculate cluster offset in fat table. And the Parity
    ; offset = cluster_index * 3/ 2, because each item has 12bits
    mov byte [isOdd], 0
    mov bx, 3
    mul bx

    mov bx, 2
    div bx  ;ax result, dx mod
    
    cmp dx, 0

    je even
    mov byte[isOdd], 1

even:
    xor dx, dx
    mov bx, [BPB_BytsPerSec]
    div bx

    push dx

    xor bx, bx ;es:bx --> FILE_SEG-0x100:0

    add ax, SectorNoOfFAT1
    mov cl, 2
    call readSect

    pop dx

    add bx, dx

    mov ax, [es:bx]
    cmp byte [isOdd], 1
    jne EVEN_2
    shr ax, 4
    jmp get_fat_entry_ok

EVEN_2:
    and ax, 0x0FFF


get_fat_entry_ok: 
    pop bx
    pop es
    ret


%include "DispStr.inc"


wRootDirSizeLoop dw RootDirSectors
wSector dw 0
isOdd db 0
fileSize dd 0


FoundMessage:   db "Loading......"
NoFileMessage:  db "no file      "
FinishMessage:  db "loader finish"
KernelTooLargeMessage:  db "file to large"