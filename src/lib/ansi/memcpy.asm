;void *MemCpy(void *es:dest, void *ds:src, int size)
memcpy:
    push esi
    push edi
    push ecx

    mov edi, [esp + 4*4]
    mov esi, [esp + 4*5]
    mov ecx, [esp + 4*6]

.Copy:
    cld
    rep movsb

.CpyEnd:

    mov eax, [esp + 4*4]
    pop ecx
    pop edi
    pop esi

    ret