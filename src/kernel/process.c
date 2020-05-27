#include "kernel.h"
#include "process.h"
#include "flyanx/common.h"

bool_t switching = 0;

/*
pich one process for next dispatch
*/

static void hunter(){
    register Process_t *prey;
    prey = ready_head[TASK_QUEUE];
    if(prey!=NIL_PROC){
        curr_proc = prey;
        return;
    }

    prey = ready_head[SERVER_QUEUE];
    if(prey!=NIL_PROC){
        curr_proc = prey;
        return;
    }

    prey = ready_head[USER_QUEUE];
    if(prey!=NIL_PROC){
        bill_proc = curr_proc = prey;
        return;
    }

    bill_proc = prey = proc_addr(IDLE_TASK);

    curr_proc = prey;
}

void ready(register Process_t* proc){
    if(is_task_proc(proc)){
        if(ready_head[TASK_QUEUE]!= NIL_PROC){
            ready_tail[TASK_QUEUE]->next_ready = proc;

        }else{
            ready_head[TASK_QUEUE] = proc;
            curr_proc = proc;
        }
        ready_tail[TASK_QUEUE] = proc;
        proc->next_ready = NIL_PROC;
        return;
    }

    if(is_serv_proc(proc)){
        if(ready_head[SERVER_QUEUE]!= NIL_PROC){
            ready_tail[SERVER_QUEUE]->next_ready = proc;

        }else{
            ready_head[SERVER_QUEUE] = proc;
            curr_proc = proc;
        }
        ready_tail[SERVER_QUEUE] = proc;
        proc->next_ready = NIL_PROC;
        return;
    }

    
        if(ready_head[USER_QUEUE]!= NIL_PROC){
            ready_tail[USER_QUEUE] = proc;
        }

        proc->next_ready = ready_head[USER_QUEUE];
        ready_head[USER_QUEUE] = proc;


        return;
    
}

void unready(register Process_t* proc){
    register Process_t *xp;

    if(is_task_proc(proc)){
        xp = ready_head[TASK_QUEUE];

        if(xp == NIL_PROC){
            return;
        }else{
            if(xp == proc){
                ready_head[TASK_QUEUE] = proc->next_ready;
                if(xp==curr_proc){
                    hunter();
                }
                return;
            }

            while (xp!=NIL_PROC)
            {
                xp = xp->next_ready;
                if(xp == proc){
                    break;
                }
            }
            if(xp!=NIL_PROC){
                xp->next_ready = xp->next_ready->next_ready;
            }
            
            if(ready_tail[TASK_QUEUE]==proc){
                ready_tail[TASK_QUEUE] = xp;
            }
            return;
        }
    }

    if(is_serv_proc(proc)){
        xp = ready_head[SERVER_QUEUE];

        if(xp == NIL_PROC){
            return;
        }else{
            if(xp == proc){
                ready_head[SERVER_QUEUE] = proc->next_ready;
                if(xp==curr_proc){
                    hunter();
                }
                return;
            }

            while (xp!=NIL_PROC)
            {
                xp = xp->next_ready;
                if(xp == proc){
                    break;
                }
            }
            if(xp!=NIL_PROC){
                xp->next_ready = xp->next_ready->next_ready;
            }
            
            if(ready_tail[SERVER_QUEUE]==proc){
                ready_tail[SERVER_QUEUE] = xp;
            }
            return;
        }
    }

        xp = ready_head[USER_QUEUE];

        if(xp == NIL_PROC){
            return;
        }else{
            if(xp == proc){
                ready_head[USER_QUEUE] = proc->next_ready;
                if(xp==curr_proc){
                    hunter();
                }
                return;
            }

            while (xp!=NIL_PROC)
            {
                xp = xp->next_ready;
                if(xp == proc){
                    break;
                }
            }
            if(xp!=NIL_PROC){
                xp->next_ready = xp->next_ready->next_ready;
            }
            
            if(ready_tail[USER_QUEUE]==proc){
                ready_tail[USER_QUEUE] = xp;
            }
            return;
        }

}

static void schedule(){
    if(ready_head[USER_QUEUE]==NIL_PROC){
        return;
    }

    Process_t *tmp;

    tmp = ready_head[USER_QUEUE]->next_ready;

    ready_tail[USER_QUEUE]->next_ready = ready_head[USER_QUEUE];
    ready_tail[USER_QUEUE] = ready_head[USER_QUEUE];
    ready_head[USER_QUEUE] = tmp;
    ready_tail[USER_QUEUE]->next_ready = NIL_PROC;

    hunter();
}

void schedule_stop(){
    ready_head[USER_QUEUE] = NIL_PROC;
}

/*==========================================================================*
 *				    lock_hunter				    *
 *				    加锁的，安全的进程狩猎例程
 *==========================================================================*/
PUBLIC void lock_hunter(void){
    switching = TRUE;
    hunter();
    switching = FALSE;
}

/*==========================================================================*
 *				    lock_ready				    *
 *				    加锁的，安全的进程就绪例程
 *==========================================================================*/
PUBLIC void lock_ready(Process_t* proc){
    switching = TRUE;
    ready(proc);
    switching = FALSE;
}

/*==========================================================================*
 *				lock_unready				    *
 *				加锁的，安全的进程堵塞例程
 *==========================================================================*/
PUBLIC void lock_unready(Process_t* proc){
    switching = TRUE;
    unready(proc);
    switching = FALSE;
}

/*==========================================================================*
 *				lock_schedule				    *
 *				加锁的进程调度方法
 *==========================================================================*/
PUBLIC void lock_schedule(void)
{
    switching = TRUE;
    schedule();
    switching = FALSE;
}