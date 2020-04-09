

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

SetupPaging:
    pusha
    xor edx, edx            ; edx = 0
    mov eax, [ddMemSize]    ; eax = 内存大小
    mov ebx, 0x400000       ; 0x400000 = 4M = 4096 * 1024，即一个页表对于的内存大小
    div ebx                 ; 内存大小 / 4M
    mov ecx, eax            ; ecx = 需要的页表的个数，即 PDE 应该的页数
    test edx, edx
    jz .no_remainder        ; if(edx == 0) jmp .no_remainder，没有余数
    inc ecx                 ; else ecx++，有余数则需要多一个 PDE 去映射它
.no_remainder:
    push ecx                ; 保存页表个数
    ; flyanx 0.11为了简化处理，所有线性地址对应相等的物理地址，并且暂不考虑内存空洞

    ; 首先初始化页目录
    mov ax, SelectorData
    mov es, ax
    mov edi, PAGE_DIR_BASE  ; edi = 页目录存放的首地址
    xor eax, eax
    ; eax = PDE，PG_P（该页存在）、PG_US_U（用户级页）、PG_RW_W（可读、写、执行）
    mov eax, PAGE_TABLE_BASE | PG_P | PG_US_U | PG_RW_W
.SetupPDE:  ; 设置 PDE
    stosd                   ; 将ds:eax中的一个dword内容拷贝到ds:edi中，填充页目录项结构
    add eax, 4096           ; 所有页表在内存中连续，PTE 的高20基地址指向下一个要映射的物理内存地址
    loop .SetupPDE           ; 直到ecx = 0，才退出循环，ecx是需要的页表个数

    ; 现在开始初始化所有页表
    pop eax                 ; 取出页表个数
    mov ebx, 1024           ; 每个页表可以存放 1024 个 PTE
    mul ebx                 ; 页表个数 * 1024，得到需要多少个PTE
    mov ecx, eax            ; eax = PTE个数，放在ecx里是因为准备开始循环设置 PTE
    mov edi, PAGE_TABLE_BASE; edi = 页表存放的首地址
    xor eax, eax
    ; eax = PTE，页表从物理地址 0 开始映射，所以0x0 | 后面的属性，该句可有可无，但是这样看着比较直观
    mov eax, 0x0 | PG_P | PG_US_U | PG_RW_W
.SetupPTE:  ; 设置 PTE
    stosd                   ; 将ds:eax中的一个dword内容拷贝到ds:edi中，填充页表项结构
    add eax, 4096           ; 每一页指向 4K 的内存空间
    loop .SetupPTE          ; 直到ecx = 0，才退出循环，ecx是需要的PTE个数

    ; 最后设置 cr3 寄存器和 cr0，开启分页机制
    mov eax, PAGE_DIR_BASE
    mov cr3, eax            ; cr3 -> 页目录表
    mov eax, cr0
    or eax, 0x80000000      ; 将 cr0 中的 PG位（分页机制）置位
    mov cr0, eax
    jmp short .SetupPGOK    ; 和进入保护模式一样，一个跳转指令使其生效，标明它是一个短跳转，其实不标明也OK
.SetupPGOK:
     nop                    ; 一个小延迟，给一点时间让CPU反应一下
     nop                    ; 空指令
     push strSetupPaging
     call Print
     add esp, 4
     popa
     ret

%include "memcpy.asm"

;copy Kernel.bin to kernel physical address
InitKernelFile:
    xor esi, esi 
    xor ecx, ecx
    mov cx, word [KERNEL_PHY_ADDR + 44] ;number of sections in elf header
    mov esi, [KERNEL_PHY_ADDR + 28] ;offset in file
    add esi, KERNEL_PHY_ADDR ;offset in memory = offset in file + memory start address
.Begin:
    mov eax, [esi + 0] ; eax = e_type, section type
    cmp eax, 0
    je .NoAction; invalid section

    push dword[esi + 16] ;section length
    mov eax, [esi + 4] 
    add eax, KERNEL_PHY_ADDR ; eax->address of section in memory
    push eax
    push dword [esi + 8]
    call memcpy
    add esp, 4*3


.NoAction:
    add esi, 32 ;esi += Program_header_length
    dec ecx
    cmp ecx, 0
    jnz .Begin

    ret