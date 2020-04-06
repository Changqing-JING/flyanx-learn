
KillMotor:
    push	dx
    push ax
 	mov	dx, 03F2h
 	xor	al, al
 	out	dx, al
    pop ax
 	pop	dx
    ret