#include "kernel.h"
#include "process.h"
#include "sys/times.h"

#define SCHEDULE_MILLISECOND    130         /* 用户进程调度的频率（毫秒），根据喜好设置就行 */
#define SCHEDULE_TICKS          (SCHEDULE_MILLISECOND / ONE_TICK_MILLISECOND)  /* 用户进程调度的频率（滴答） */


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

static unsigned int ticks=0;

PRIVATE Message_t msg;

PRIVATE time_t realtime;        /* 时钟运行的时间(s)，也是开机后时钟运行的时间 */

/* 由中断处理程序更改的变量 */
PRIVATE clock_t schedule_ticks = SCHEDULE_TICKS;    /* 用户进程调度时间，当为0时候，进行程序调度 */
PRIVATE Process_t *last_proc;                       /* 最后使用时钟任务的用户进程 */
time_t boot_time;
clock_t next_alarm = ULONG_MAX;
clock_t delay_alarm = ULONG_MAX;


#define MINUTES 60	                /* 1 分钟的秒数。 */
#define HOURS   (60 * MINUTES)	    /* 1 小时的秒数。 */
#define DAYS    (24 * HOURS)		/* 1 天的秒数。 */
#define YEARS   (365 * DAYS)	    /* 1 年的秒数。 */

PRIVATE int month_map[12] = {
        0,
        DAYS * (31),
        DAYS * (31 + 29),
        DAYS * (31 + 29 + 31),
        DAYS * (31 + 29 + 31 + 30),
        DAYS * (31 + 29 + 31 + 30 + 31),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31 + 31),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31 + 31 + 30),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + 30)
};

/*Only avalible after timmer driver start*/

void milli_delay(time_t delay_ms){
    /*busy wait*/
    delay_alarm = ticks + delay_ms / ONE_TICK_MILLISECOND;
    while (delay_alarm != ULONG_MAX)
    {

    }
    
}

void do_clock_int(){
    printf("I am clock int\n");
    next_alarm = ULONG_MAX;
}

void do_get_uptime(){
    msg.CLOCK_TIME = ticks;

}
void do_get_time(){
    msg.CLOCK_TIME = (long)(boot_time + realtime);
}
void do_set_time(){
    boot_time = msg.CLOCK_TIME - realtime;
}


static int clock_handler(int irq){

    register Process_t *target;

    //get current process which using timmer
    if(kernel_reenter){ //if reenter a interrupt, current in in kernel. Set current proc as virtual hardware
        target = proc_addr(HARDWARE);
    }else{
        target = curr_proc;
    }

    ticks++;

    //start billing
    target->user_time++;
    if(target != curr_proc && target != proc_addr(HARDWARE)){
        //current proc is not billing proc. It should be a user process which call system kernel
        //add system time of this process
        bill_proc->sys_time++;
    }

    if(next_alarm<=ticks){
        interrupt(CLOCK_TASK);
        return ENABLE;
    }

    if(delay_alarm<=ticks){
        delay_alarm = ULONG_MAX;
    }

    schedule_ticks--;
    if(schedule_ticks==0){
        schedule_ticks = SCHEDULE_TICKS;
        last_proc = bill_proc;
    }

    
    
   
    return ENABLE;
}


//convert to unix timestamp
static time_t mktime(RTCTime_t* p_time){
    time_t now;
    u16_t year = p_time->year;
    u8_t month = p_time->month;
    u16_t day = p_time->day;
    u8_t hour = p_time->hour;
    u8_t minute = p_time->minute;
    u8_t second = p_time->second;

    year-=1970;

    now = YEARS * year + DAYS *((year+1)/4);

    now += month_map[month-1];

    if(month-1>0 && (year+2)%4){
        now -= DAYS;
    }

    now += DAYS * (day-1);

    now += HOURS * hour;

    now += MINUTES * minute;

    now += second;

    return now;
}


static void clock_init(){
    out_byte(TIMER_MODE, RATE_GENERATOR);

    out_byte(TIMER0, (u8_t)TIMER_COUNT);
    out_byte(TIMER0,  (u8_t)(TIMER_COUNT>>8));

    put_irq_handler(CLOCK_IRQ, clock_handler);
    enable_irq(CLOCK_IRQ);

    RTCTime_t now;
    get_rtc_time(&now);
    boot_time = mktime(&now);
    printf("#{CLOCK}-> now is %d-%d-%d %d:%d:%d\n", now.year, now.month, now.day, now.hour, now.minute, now.second);
    printf("#{CLOCK}-> boot startup time is %ld\n", boot_time);
}


void clock_task(){
    clock_init();

    io_box(&msg);

    while (TRUE)
    {
        receive(ANY, NIL_MESSAGE);
        //calibrate time before service.
        do_clock_int();
        interrupt_lock();
        realtime = ticks/HZ;
        interrupt_unlock();

        switch (msg.type)
        {
            case(HARD_INT):{

                break;
            }
            case(GET_UPTIME):{
                do_get_uptime();
                break;
            }
            case(GET_TIME):{
                do_get_time();
                break;
            }
            case (SET_TIME):{
                do_set_time();
                break;
            }

        default:{
            panic("Clock got a bad message\n", msg.type);
            break;
        }

           
        }

        msg.type = OK;
        send(msg.source, NULL);
    }
    

}

PUBLIC void get_rtc_time(RTCTime_t *p_time) {
    /* 这个例程很简单，不断的从 CMOS 的端口中获取时间的详细数据 */
    u8_t status;

    p_time->year = cmos_read(YEAR);
    p_time->month = cmos_read(MONTH);
    p_time->day = cmos_read(DAY);
    p_time->hour = cmos_read(HOUR);
    p_time->minute = cmos_read(MINUTE);
    p_time->second = cmos_read(SECOND);

    /* 查看 CMOS 返回的 RTC 时间是不是 BCD 码？
     * 如果是，我们还需要手动将 BCD 码转换成十进制。
     */
    status = cmos_read(CLK_STATUS);
    if( (status & 0x4) == 0 ) {
        p_time->year = bcd2dec(p_time->year);
        p_time->month = bcd2dec(p_time->month);
        p_time->day = bcd2dec(p_time->day);
        p_time->hour = bcd2dec(p_time->hour);
        p_time->minute = bcd2dec(p_time->minute);
        p_time->second =bcd2dec(p_time->second);
    }
    p_time->year += 2000;   /* CMOS 记录的年是从 2000 年开始的，我们补上 */
}



