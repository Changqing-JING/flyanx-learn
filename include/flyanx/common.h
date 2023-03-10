/* Copyright (C) 2007 Free Software Foundation, Inc. 
 * See the copyright notice in the file /usr/LICENSE.
 * Created by flyan on 2019/11/9.
 * QQ: 1341662010
 * QQ-Group:909830414
 * gitee: https://gitee.com/flyanh/
 *
 * 公共定义
 */

#ifndef _FLYANX_COMMON_H
#define _FLYANX_COMMON_H

#define CLOCK_TASK -3
#define IDLE_TASK -2
#define HARDWARE -1
#define HARD_INT -1

#define CLOCK_TASK          -3  
#define     GET_UPTIME      1   
#define     GET_TIME        2   
#define     SET_TIME        3  

/* 系统调用例程可以支持的操作 */
#define SEND            0x1    	/* 0001: 发送一条消息 */
#define RECEIVE         0x2    	/* 0010: 接收一条消息 */
#define SEND_REC        0x3    	/* 0011: 发送一条消息并等待对方响应一条消息 */
#define IN_OUTBOX       0x4   	/* 0100: 设置固定收发件箱  */
#define ANY             0x3ea   /* 魔数，它是一个不存在的进程逻辑编号，用于表示任何进程*/

/*===========================================================================*
 *				以下是所有需要的消息字段				     *
 *===========================================================================*/
/* 时钟任务消息中使用的消息字段 */
#define CLOCK_TIME      m6_l1	/* 时间值 */


#endif //_FLYANX_COMMON_H
