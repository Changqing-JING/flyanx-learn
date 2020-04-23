

[section .lib]

global send
global in_outbox
global receive
global send_rec


SEND equ 1
REVEIVE equ 2
SEND_REC equ 3
IN_OUTBOX equ 4

SYS_VEC equ 0x94

send:
    push ebx
    push ecx
    mov ecx, SEND
    jmp com

receive:

    push ebx
    push ecx
    mov ecx, REVEIVE
    jmp com
    

send_rec:
     push ebx
    push ecx
    mov ecx, SEND_REC
    jmp com
    

in_outbox:
    push ebx
    push ecx
    mov ecx, IN_OUTBOX
    jmp com

com:
    mov eax, [esp + 12]
    mov ebx, [esp + 16]
    

    pop ecx
    pop ebx

    int SYS_VEC
    ret
