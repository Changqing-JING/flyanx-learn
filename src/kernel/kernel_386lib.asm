extern display_position
global low_print
global phys_copy
global in_byte
global out_byte
global in_word
global out_word
global interrupt_lock
global interrupt_unlock
global disable_irq 
global enable_irq  
extern level0_func
global level0
global msg_copy
global cmos_read
%include "asm_const.inc"

low_print:
    push esi
    push edi
    push ebx
    push edx

    mov esi, [esp+4*5]

    mov edi, [display_position]
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
    mov dword [display_position], edi


    pop edx
    pop ebx
    pop edi
    pop esi
    ret

%include "memcpy.asm"

;============================================================================
;   从一个端口读取一字节数据
; 函数原型： u8_t in_byte(port_t port)
;----------------------------------------------------------------------------
align 16
in_byte:
    push edx
        mov edx, [esp + 8]      ; 得到端口号
        xor eax, eax
        in al, dx              ; port -> al
    pop edx
    nop                         ; 一点延迟
    ret
;============================================================================
;   向一个端口输出一字节数据
; 函数原型： void out_byte(port_t port, U8_t value)
;----------------------------------------------------------------------------
align 16
out_byte:
    push edx
        mov edx, [esp + 8]      ; 得到端口号
        mov al, [esp + 4 * 3]   ; 要输出的字节
        out dx, al              ; al -> port
    pop edx
    nop                         ; 一点延迟
    ret

    ;============================================================================
;   从一个端口读取一字数据
; 函数原型： u16_t in_word(port_t port)
;----------------------------------------------------------------------------
align 16
in_word:
    push edx
        mov edx, [esp + 8]      ; 得到端口号
        xor eax, eax
        in ax, dx              ; port -> ax
    pop edx
    nop                         ; 一点延迟
    ret
;============================================================================
;   向一个端口输出一字数据
; 函数原型： void out_word(port_t port, U16_t value)
;----------------------------------------------------------------------------
align 16
out_word:
    push edx
        mov edx, [esp + 8]      ; 得到端口号
        mov ax, [esp + 4 * 3]   ; 得到要输出的变量
        out dx, ax              ; ax -> port
    pop edx
    nop                         ; 一点延迟
    ret

align 16
interrupt_lock:
        cli
    ret
;============================================================================
;   打开中断响应，也称为解锁中断
; 函数原型： void interrupt_unlock(void)
;----------------------------------------------------------------------------
align 16
interrupt_unlock:
        sti
    ret

;============================================================================
;   屏蔽一个特定的中断
; 函数原型： int disable_irq(int int_request);
align 16
disable_irq:
    pushf                   ; 将标志寄存器 EFLAGS 压入堆栈，需要用到test指令，会改变 EFLAGS
    push ecx

        cli                     ; 先屏蔽所有中断
        mov ecx, [esp + 4*3]      ; ecx = int_request(中断向量)
        ; 判断要关闭的中断来自于哪个 8259A
        mov ah, 1               ; ah = 00000001b
        rol ah, cl              ; ah = (1 << (int_request % 8))，算出在int_request位的置位位图，例如2的置位位图是00000100b
        cmp cl, 7
        ja disable_slave        ; 0~7主，8~15从；> 7是从，跳转到 disable_slave 处理 从8259A 的中断关闭
disable_master:                 ; <= 7是主
        in al, INT_M_CTLMASK    ; 取出 主8259A 当前的屏蔽位图
        test al, ah
        jnz disable_already     ; 该int_request的屏蔽位图不为0，说明已经被屏蔽了，没必要继续了
        ; 该int_request的屏蔽位图为0，还未被屏蔽
        or al, ah               ; 将该中断的屏蔽位置位，表示屏蔽它
        out INT_M_CTLMASK, al   ; 输出新的屏蔽位图，屏蔽该中断
        jmp disable_ok          ; 屏蔽完成
disable_slave:
        in al, INT_S_CTLMASK    ; 取出 从8259A 当前的屏蔽位图
        test al, ah
        jnz disable_already     ; 该int_request的屏蔽位图不为0，说明已经被屏蔽了，没必要继续了
        ; 该int_request的屏蔽位图为0，还未被屏蔽
        or al, ah               ; 将该中断的屏蔽位置位，表示屏蔽它
        out INT_S_CTLMASK, al   ; 输出新的屏蔽位图，屏蔽该中断
disable_ok:
    pop ecx
    popf
    and eax, 1              ; 等同于 mov eax, 1，即return 1；我只是想耍个帅！
    ret
disable_already:
    pop ecx
    popf                    ; 恢复标志寄存器
    xor eax, eax            ; return 0，表示屏蔽失败，因为该中断已经处于屏蔽状态
    ret
;============================================================================
;   启用一个特定的中断
; 函数原型： void enable_irq(int int_request);
;----------------------------------------------------------------------------
align 16
enable_irq:
    pushf                   ; 将标志寄存器 EFLAGS 压入堆栈，需要用到test指令，会改变 EFLAGS
    push ecx

        cli                     ; 先屏蔽所有中断
        mov ecx, [esp + 4*3]      ; ecx = int_request(中断向量)
        mov ah, ~1              ; ah = 11111110b
        rol ah, cl              ; ah = ~(1 << (int_request % 8))，算出在int_request位的复位位位图，例如2的置位位图是11111011b
        cmp cl, 7
        ja enable_slave         ; 0~7主，8~15从；> 7是从，跳转到 disable_slave 处理 从8259A 的中断关闭
enable_master:                  ; <= 7是主
        in al, INT_M_CTLMASK    ; 取出 主8259A 当前的屏蔽位图
        and al, ah              ; 将该中断的屏蔽位复位，表示启用它
        out INT_M_CTLMASK, al   ; 输出新的屏蔽位图，启用该中断
        jmp enable_ok
enable_slave:
        in al, INT_S_CTLMASK    ; 取出 从8259A 当前的屏蔽位图
        and al, ah              ; 将该中断的屏蔽位复位，表示启用它
        out INT_S_CTLMASK, al   ; 输出新的屏蔽位图，启用该中断
enable_ok:
      pop ecx
      popf
      ret

align 16
level0:
    mov eax, [esp+4]; eax printer to PRIVILEGE function
    mov [level0_func], eax
    int 0x66
    ret


align 16
msg_copy:
    push esi
    push edi
    push ecx

      mov esi, [esp + 4 * 4]  ; msg_phys
      mov edi, [esp + 4 * 5]  ; dest_phys

      ; 开始拷贝消息
      cld
      mov ecx, MESSAGE_SIZE   ; 消息大小(dword)
      rep movsd

    pop ecx
    pop edi
    pop esi
    ret

cmos_read:
    push edx
        mov al, [esp + 4 * 2]   ; 要输出的字节
        out CLK_ELE, al         ; al -> CMOS ELE port
        nop                     ; 一点延迟
        xor eax, eax
        in al, CLK_IO           ; port -> al
        nop                     ; 一点延迟
    pop edx
    ret