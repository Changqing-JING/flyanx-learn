#include "kernel.h"

/* 时钟, 8253 / 8254 PIT (可编程间隔定时器)参数 */
#define TIMER0          0x40	/* 定时器通道0的I/O端口 */
#define TIMER1          0x41	/* 定时器通道1的I/O端口 */
#define TIMER2          0x42	/* 定时器通道2的I/O端口 */
#define TIMER_MODE      0x43	/* 用于定时器模式控制的I/O端口 */
#define RATE_GENERATOR  0x34    /* 00-11-010-0
                                 * Counter0 - LSB the MSB - rate generator - binary
                                 */
#define TIMER_FREQ		    1193182L    /* clock frequency for timer in PC and AT */
#define TIMER_COUNT  (TIMER_FREQ / HZ)  /* initial value for counter*/
#define CLOCK_ACK_BIT	    0x80		/* PS/2 clock interrupt acknowledge bit */
