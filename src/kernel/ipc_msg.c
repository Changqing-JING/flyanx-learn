#include "kernel.h"
#include "flyanx/common.h"
#include "process.h"
#include "assert.h"

INIT_ASSERT

PRIVATE Process_t *waiters[NR_TASKS + NR_SERVERS + NR_PROCS]; 

int sys_call(int op, int src_dest_msgp, Message_t *msg_ptr){
    register Process_t *caller;
    Message_t *msg_phys;
    vir_bytes msg_vir;
    int rs;

    caller = curr_proc;

    if(op==IN_OUTBOX){
        msg_vir = (vir_bytes)msg_ptr;
        if(msg_vir !=0){
            caller->inbox = (Message_t*)proc_vir2phys(caller, msg_vir);

        }

        if(msg_ptr!=NIL_MESSAGE){
            caller->outbox = (Message_t*)proc_vir2phys(caller, msg_vir);
        }
        return OK;
    }

    if(!is_ok_src_dest(src_dest_msgp)){
        return ERROR_BAD_SRC;
    }

    if(is_user_proc(caller) && op!=SEND_REC){
        return ERROR_NO_PERM;
    }

   

    if(op&SEND){
        assert(caller->logic_nr!= src_dest_msgp);

        if(msg_ptr == NIL_MESSAGE){
            msg_phys = (Message_t*)caller->outbox;
        }else{
            msg_phys =  (Message_t*) proc_vir2phys(caller, msg_ptr);
        }

        msg_phys->source = caller->logic_nr;

        int rs = flyanx_send(caller, src_dest_msgp, msg_phys);

        if(op == SEND){
            return rs;
        }

        if(rs!=OK){
            return rs;
        }
    }

    if(msg_ptr == NIL_MESSAGE){
        msg_phys = (Message_t*)caller->inbox;
    }else{
        msg_phys =  (Message_t*) proc_vir2phys(caller, msg_ptr);
    }

    int res = flyanx_receive(caller, src_dest_msgp, msg_phys);
    return res;
}

int flyanx_send(Process_t* caller, int dest, Message_t* msg_phys){

    register Process_t* target, next;

    if(is_user_proc(caller)&& !is_sys_server(dest)){
        return ERROR_BAD_DEST;
    }

    target = proc_addr(dest);

    if(is_empty_proc(target)){
        return ERROR_BAD_DEST;
    }

    if(target->flags&SENDING){
        Process_t* next = proc_addr(target->send_to);

        while (TRUE)
        {
            if(next == caller){
                return ERROR_LOCKED;
            }

            if(next->flags & SENDING){
                next = proc_addr(next->send_to);
            }else{
                break;
            }
            
        }

        if(target->flags == RECEIVING && 
        (target->get_form == caller->logic_nr || target->get_form == ANY)){
            msg_copy((phys_bytes)msg_phys, (phys_bytes)target->transfer);

            target->flags &= -RECEIVING;

            if(caller->flags == CLEAN_MAP){
                ready(target);
            }
        }else{
            if(caller->flags == CLEAN_MAP){
                unready(caller);
            }

            caller->flags |= SENDING;
            caller->send_to = dest;
            caller->transfer = msg_phys;

            next = waiters[dest];

            if(next == NIL_PROC){
                waiters[dest] = caller;
            }else{
                while (next->next_waiter!=NIL_PROC)
                {
                    next = next->next_waiter;

                }
                next->next_waiter = caller;
            }

            caller->next_waiter = NIL_PROC;
        }
        
    }

    return OK;
}

int flyanx_receive(Process_t* caller, int src, Message_t* msg_phys){
    
    register Process_t* sender, *prev;

    if(!(caller->flags & SENDING)){
        for(sender = waiters[caller->logic_nr];sender != NIL_PROC;
            prev = sender, sender=sender->next_waiter){

            if(sender->logic_nr == src || src == ANY){
                msg_copy((phys_bytes)sender->transfer, (phys_bytes)msg_phys);

                if(sender == waiters[caller->logic_nr]){
                    waiters[caller->logic_nr] = sender->next_waiter;
                }else{
                    prev->next_waiter = sender->next_waiter;
                }

                sender->flags &= -SENDING;
                if(sender->flags == CLEAN_MAP){
                    ready(sender);
                }
                return OK;

            }
        }
    }

    caller->get_form = src;
    caller->transfer = msg_phys;
    if(caller->flags == CLEAN_MAP){
        unready(caller);
    }
    caller->flags |= RECEIVING;

    return OK;
}