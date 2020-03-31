DispStr:
    ; call bios to show string in bp
    pusha
    push es

    mov al, 1
    xor bh, bh
    mov bl, 0x7 ;black white
    mov cx, 13 ;string length
    xor dx, dx

    mov ax, ds
    mov es, ax   
    
    xor ax, ax
    mov ah, 0x13
    int 0x10

    pop es
    popa

    ret