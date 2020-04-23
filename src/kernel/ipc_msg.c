#include "kernel.h"
#include "flyanx/common.h"
#include "process.h"
#include "assert.h"

INIT_ASSERT



int sys_call(int op, int src_dest_msgp, Message_t *msg_ptr){
    register Process_t *caller;
    Message_t *msg_phys;
    vir_bytes msg_vir;
    int rs;

    caller = curr_proc;
    printf("#sys_call->{caller: %d, op: 0x%x, src_dest: %d, msg_ptr: 0x%p}\n",
           caller->logic_nr , op, src_dest_msgp, msg_ptr);
    if(op==IN_OUTBOX){
        msg_vir = (vir_bytes)msg_ptr;
        if(msg_vir !=0){
            caller->inbox = (Message_t*)msg_vir;

        }

        if(msg_ptr!=NIL_MESSAGE){
            caller->outbox = msg_ptr;
        }
        return OK;
    }

    if(!is_ok_src_dest(src_dest_msgp)){
        return ERROR_BAD_SRC;
    }

    if(is_user_proc(caller) && op!=SEND_REC){
        return ERROR_NO_PERM;
    }

    if(msg_ptr == NIL_MESSAGE){
        msg_phys = (Message_t*) proc_vir2phys(caller, caller->outbox);

    }else{
        msg_phys = (Message_t*) proc_vir2phys(caller, msg_ptr);
    }

    if(op&SEND){
        assert(caller->logic_nr!= src_dest_msgp);

        msg_phys->source = caller->logic_nr;

        int rs = flyanx_send(caller, src_dest_msgp, msg_phys);

        if(op == SEND){
            return rs;
        }

        if(rs!=OK){
            return rs;
        }
    }

    return flyanx_receive(caller, src_dest_msgp, msg_phys);
}

int flyanx_send(Process_t* caller, int dest, Message_t* msg_phys){
    printf("flynax send");
    return OK;
}

int flyanx_receive(Process_t* caller, int dest, Message_t* msg_phys){
    printf("flynax receive");
    return OK;
}