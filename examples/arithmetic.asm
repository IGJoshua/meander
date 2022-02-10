;;; arithmetic.asm

;;; Example test program for the following lisp-ish code
;;; (exit (+ (- 2 3) 4))
;;; (- 2 3 (fn [x] (+ x 4 (fn [ret-code] (syscall-exit ret-code)))))

%include "stdtypes.asm"

    default rel

    global  meander_main

    section .text
test_add:
    push    post_sub            ; return address
    push    rbp                 ; old base pointer
    mov     r12, rsp            ; save old base pointer
    sub     rsp, 8              ; empty
    push    3                   ; arg2
    push    int_t               ; arg2_t
    push    2                   ; arg1
    push    int_t               ; arg1_t
    push    2                   ; arg_ct
    mov     rbp, rsp            ; set base pointer
    jmp     [std__minus wrt ..got] ; std__minus(2, 3) -> post_sub

post_sub:
    cmp     [rbp+arg_ct], 1     ; test arguments match those needed
    jne     error
    cmp     [rbp+arg1_t], int_t
    jne     error
    mov     rax, [rbp + arg1]
    mov     rsp, r12
    pop     rbp
    add     rsp, 8              ; ignore the return address because this is a cont

    push    done
    push    rbp
    mov     r12, rsp
    sub     rsp, 8
    push    4
    push    int_t
    push    rax
    push    int_t
    push    2
    mov     rbp, rsp
    jmp     [std__plus wrt ..got] ; std__plus(rax, 4) -> done

done:
    mov     rsp, r12
    pop     rbp
    add     rsp, 8              ; ignore the args
    push    0                   ; no return address
    push    rbp                 ; base pointer
    mov     r12, rsp
    sub     rsp, 8
    push    0
    push    int_t
    push    1
    mov     rbp, rsp
    jmp     [std__exit wrt ..got]

error:
    push    0                   ; no valid return address
    push    rbp                 ; save the base pointer
    mov     r12, rsp
    sub     rsp, 8              ; empty
    push    1                   ; arg1
    push    int_t               ; arg1_t
    push    1                   ; arg_ct
    mov     rbp, rsp            ; set base pointer
    jmp     [std__exit wrt ..got] ; std__exit(2, 3) -> !
