/* Copyright (C) 2007 Free Software Foundation, Inc.
 * See the copyright notice in the file /usr/LICENSE.
 * Created by flyan on 2021/2/15.
 * QQ: 1341662010
 * QQ-Group:909830414
 * gitee: https://gitee.com/flyanh/
 *
 * PC 和 AT键盘系统任务（驱动程序）
 */
#include "kernel.h"
#include <flyanx/keymap.h>
#include "keymaps/us-std.h"

/* 标准键盘和AT键盘 */
#define KEYBOARD_DATA       0x60    /* 键盘数据的I/O端口，用于和键盘控制器的底层交互。 */

/* AT键盘 */
#define KEYBOARD_COMMAND    0x64    /* AT上的命令I/o端口 */
#define KEYBOARD_STATUS     0x64    /* AT上的状态I/O端口 */
#define KEYBOARD_ACK        0xFA    /* 键盘相应确认 */

#define KEYBOARD_OUT_FULL   0x01    /* 字符按键按下时该状态位被设置 */
#define KEYBOARD_IN_FULL    0x02    /* 未准备接收字符时该状态位被设置 */
#define LED_CODE            0xED    /* 设置键盘灯的命令 */
#define MAX_KEYBOARD_ACK_RETRIES    0x1000  /* 等待键盘响应的最大等待时间 */
#define MAX_KEYBOARD_BUSY_RETRIES   0x1000  /* 键盘忙时循环的最大时间 */
#define KEY_BIT             0x80    /* 将字符打包传输到键盘的位 */
#define KEY                 0x7f 
/* 它们用于滚屏操作 */
#define SCROLL_UP       0	            /* 前滚，用于滚动屏幕 */
#define SCROLL_DOWN     1	            /* 后滚 */

/* 锁定键激活位，应该要等于键盘上的LED灯位 */
#define SCROLL_LOCK	    0x01    /* 二进制：0001 */
#define NUM_LOCK	    0x02    /* 二进制：0010 */
#define CAPS_LOCK	    0x04    /* 二进制：0100 */
#define DEFAULT_LOCK    0x02    /* 默认：小键盘也是打开的 */

/* 键盘缓冲区 */
#define KEYBOARD_IN_BYTES	  32	/* 键盘输入缓冲区的大小 */

/* 其他用途 */
#define ESC_SCAN	        0x01	/* 重启键，当宕机时可用 */
#define SLASH_SCAN	        0x35	/* 识别小键盘区的斜杠 */
#define RSHIFT_SCAN	        0x36	/* 区分左移和右移 */
#define HOME_SCAN	        0x47	/* 数字键盘上的第一个按键 */
#define INS_SCAN	        0x52	/* INS键，为了使用 CTRL-ALT-INS 重启快捷键 */
#define DEL_SCAN	        0x53	/* DEL键，为了使用 CTRL-ALT-DEL 重启快捷键 */

/* 当前键盘所处的各种状态，解释一个按键需要使用这些状态 */
PRIVATE bool_t esc = FALSE;		            /* 是一个转义扫描码？收到一个转义扫描码时，被置位 */
PRIVATE bool_t alt_left = FALSE;		    /* 左ALT键状态 */
PRIVATE bool_t alt_right = FALSE;		    /* 右ALT键状态 */
PRIVATE bool_t alt = FALSE;		            /* ALT键状态，不分左右 */
PRIVATE bool_t ctrl_left = FALSE;		    /* 左CTRL键状态 */
PRIVATE bool_t ctrl_right = FALSE;		    /* 右CTRL键状态 */
PRIVATE bool_t ctrl = FALSE;		        /* CTRL键状态，不分左右 */
PRIVATE bool_t shift_left = FALSE;		    /* 左SHIFT键状态 */
PRIVATE bool_t shift_right = FALSE;         /* 右SHIFT键状态 */
PRIVATE bool_t shift = FALSE;		        /* SHIFT键状态，不分左右 */
PRIVATE bool_t num_down = FALSE;		    /* 数字锁定键(数字小键盘锁定键)按下 */
PRIVATE bool_t caps_down = FALSE;		    /* 大写锁定键按下 */
PRIVATE bool_t scroll_down = FALSE;	        /* 滚动锁定键按下 */
PRIVATE u8_t locks[NR_CONSOLES] = {         /* 每个控制台的锁定键状态 */
        DEFAULT_LOCK, DEFAULT_LOCK, DEFAULT_LOCK
};

PRIVATE char numpad_map[] =
        {'H', 'Y', 'A', 'B', 'D', 'C', 'V', 'U', 'G', 'S', 'T', '@'};

static u8_t input_buff[KEYBOARD_IN_BYTES];
static int input_count;
static u8_t* input_free = input_buff;
u8_t* input_todo = input_buff;

#define map_key0(scan_code)\
        (u16_t)keymap[(scan_code * MAP_COLS)]

static int keyboard_wait(){
        int retries = 10;

        u8_t status;
        while(retries-->0 && (status = in_byte(KEYBOARD_STATUS))&(1|2)!=0){
                if((status & KEYBOARD_OUT_FULL) != 0){
                        in_byte(KEYBOARD_DATA);
                }
        }
        return retries;
}

static int keyboard_ack(){
        int retries = 10;

        while(retries-->0 && in_byte(KEYBOARD_DATA)!=KEYBOARD_ACK){

        }

        return retries;
}

static void setting_led(){
        keyboard_wait();

        out_byte(KEYBOARD_DATA, LED_CODE);
        
        keyboard_ack();

        keyboard_wait();

        out_byte(KEYBOARD_DATA, locks[0]);

        keyboard_ack();
}

static u8_t scan_key(){
    u8_t scan_code = in_byte(KEYBOARD_DATA);

    //clean keyboard controller buffer
    int val = in_byte(PORT_B);
    out_byte(PORT_B, val|KEY_BIT);
    return scan_code;
}


static u32_t map_key(u8_t scan_code){

        u16_t* keys_row = &keymap[scan_code*MAP_COLS];

        u8_t lock = locks[0];
        bool_t caps = shift;

        if((lock & CAPS_LOCK)!=0 && (keys_row[0] & HASCAPS) ){
                caps = !caps;
        }

        int col = 0;

        if(alt){
                col = 2; //alt + *
                if(ctrl || alt_right){
                        col = 3;
                }
                if(caps){
                        col = 4;
                }

        }else{
                if(caps){
                        col = 1;
                }
                if(ctrl){
                        col = 5;
                }
                
        }

        u16_t current_key = keys_row[col];
        return (current_key & ~HASCAPS);

}

static u32_t make_break(u8_t scan_code){
        bool_t is_make = (scan_code & KEY_BIT) ==0;
        scan_code &= KEY;
        u32_t ch = map_key(scan_code);

        bool_t escape = esc;
        esc = FALSE;

        switch (ch)
        {
        case CTRL:{
               if(escape){
                       ctrl_right = is_make;
               }else{
                       ctrl_left = is_make;
               }
               ctrl = ctrl_left | ctrl_right;
                break;
        }
         case SHIFT:{
               if(shift == RSHIFT_SCAN){
                  shift_right = is_make;   
               }else{
                   shift_left = is_make;
               }
               shift = shift_left | shift_right;
                break;
        }
         case ALT:{
                 if(escape){
                         alt_right = is_make;
                 }else{
                         alt_left = is_make;
                 }

                 alt = alt_left | alt_right;

                
                break;
        }
         case NLOCK:{
                if(is_make){
                        locks[0] ^= NUM_LOCK;
                        setting_led();
                }
                break;
        }
         case SLOCK:{
                 if(is_make){
                        locks[0] ^= SCROLL_LOCK;
                        setting_led();
                }
                
                break;
        }
         case CALOCK:{
                locks[0] ^= CAPS_LOCK;
                break;
        }

         case EXTKEY:{
                esc = TRUE;
                break;
         }
                
        
                default:{
                if(is_make){
                        return ch;
                }
                 break;
                }
               
        }

        return -1;
}

static int keyboard_handler(int irq){

        u8_t scan_code = scan_key();

        u32_t ch = make_break(scan_code);

        if(ch!=-1){
                printf("%c ", ch);
        }
        

        return ENABLE;
}





void keyboard_init(){

        input_count = 0;
        setting_led();
        scan_key();
        put_irq_handler(KEYBOARD_IRQ, keyboard_handler);

        enable_irq(KEYBOARD_IRQ);
}