extern display_position
global low_print

low_print:
    push esi
    push edi
    push ebx
    push ecx
    push edx

    mov esi, [esp+4*6]

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
    pop ecx
    pop ebx
    pop edi
    pop esi
    ret