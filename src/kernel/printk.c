#include "printk.h"

static unsigned int cursor_pos = 0;
static unsigned int row = 0;

static void outb(unsigned int port, unsigned int data){
    __asm __volatile("outb %0, %w1"::"r"(data), "r"(port));
}

static void set_cursor(){
    outb(0x3d4, 0xe);
    outb(0x3d5, (cursor_pos>>8)&0xFF);

    outb(0x3d4, 0xf);
    outb(0x3d5, cursor_pos&0xFF);
}

static void printc(char c){

     if(c!='\n'){
        char *show = (char*)0xb8000 + row * 160 + (cursor_pos<<1); //Display memory, every char take two bytes, pos = 0xb8000 + 2 * (row * 80 + col)

        *show = c;

        cursor_pos = (cursor_pos)+1;

        set_cursor();
    }else{
        cursor_pos = 0;
        row++;
    }
    
}

typedef enum NumOutPutType{
    dec = 10,
    hex = 16
}NumOutPutType;

static void printNum(char* buf, char* args, unsigned int* ptr, NumOutPutType numOutPutType){
    int value = *(int*)args;
    unsigned char base = (int)numOutPutType;
               
    if(value>0){
        char stack[10];
        int length = 0;
        while(value>0){
            char outPut;
            int rest = value%base;

            switch (numOutPutType)
            {
            case(dec):{
                outPut = rest + '0';
                break;
            }
            case(hex):{
                if(rest<10){
                    outPut = rest + '0';
                }else{
                    outPut = (rest-9) + 'A';
                }

                break;
            }
            default:
                outPut= 0;
                break;
            }

            stack[length] =  outPut;
            length++;

            
            value/=base;
        }

        for(int i = length-1;i>=0;i--){
            buf[*ptr] = stack[i];
            *ptr= *ptr+1;
        }

    }else{
        buf[*ptr] = '0';
        ptr++;
    }
}

void printk(const char* fmt, ...){
    char buf[512];
    unsigned int ptr = 0;
    char *s = (char*)fmt;

    //every argument is 4 Byte, stack base right(high address), top left(low address)
    char *args = (char *)(&fmt) + 4;
    

    while(*s!='\0'){
        

        if(*s!='%'){
            buf[ptr] = *s;
            ptr++;
           
        }else{
            s++;
            switch (*s)
            {
            case ('c'):{
                buf[ptr] = *args;
                
                ptr++;
                break;
            }
            case ('d'):{
                
                printNum(buf, args, &ptr, dec);
                break;
            }
            case('x'):{
                printNum(buf, args, &ptr, hex);

                break;
            }
            case ('s'):{
                char* subChar = *((char**)args);

                while(*subChar!='\0'){
                    buf[ptr] = *subChar;
                
                    ptr++;
                    subChar++;
                }

                break;
            }
               
            
            default:
                break;
            }

            args += 4;
        }

        
        s++;
    }

    for(int i=0;i<ptr;i++){
        printc(buf[i]);
    }
}