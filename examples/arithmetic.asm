;;; arithmetic.asm

;;; Example test program for the following lisp-ish code
;;; (exit (+ (- 2 3) 4))
;;; (- 2 3 (fn [x] (+ x 4 (fn [ret-code] (syscall-exit ret-code)))))

%include "stdtypes.asm"

    default rel

    global  main

    extern  std__exit
    extern  std__add_int
    extern  std__sub_int
    extern  std__println

    section .text
main:
    lea     rax, [main__sum]
    push    rax
    push    rbp
    push    r12
    mov     r12, rsp
    push    3
    push    int_t
    push    2
    push    int_t
    push    2
    mov     rbp, rsp
    jmp     [std__sub_int wrt ..got] ; std__sub_int(2, 3) -> main__sum
main__sum:
    mov     r8, [rbp+arg_ct]
    cmp     r8, 1
    jne     error
    mov     r8, [rbp+arg1_t]
    cmp     r8, int_t
    jne     error
    mov     rax, [rbp+arg1]
    mov     rsp, r12
    push    4
    push    int_t
    push    rax
    push    int_t
    push    2
    mov     rbp, rsp
    lea     r8, [main__exit]
    mov     [r12+ret_addr], r8
    jmp     [std__add_int wrt ..got] ; std__add_int(x, 4) -> exit
main__exit:
    mov     r8, [rbp+arg_ct]
    cmp     r8, 1
    jne     error
    mov     r8, [rbp+arg1_t]
    cmp     r8, int_t
    jne     error
    jmp     [std__exit wrt ..got]

error:
    mov     rax, rsp            ; align the stack if it's misaligned
    mov     rdx, 0
    mov     rcx, 16
    div     rcx
    cmp     rdx, 0
    je      error__print
    sub     rsp, 8
error__print:
    lea     rax, [error__exit]
    push    rax
    push    rbp
    push    r12
    mov     r12, rsp
    push    error_msg
    push    string_t
    push    1
    mov     rbp, rsp
    jmp     [std__println wrt ..got] ; std__println(error_msg) -> error__exit
error__exit:
    ;; ignore arguments
    mov     rsp, r12
    push    69
    push    int_t
    push    1
    mov     rbp, rsp
    jmp     [std__exit wrt ..got] ; std__exit(-1) -> !

    section .data
    align 16
error_msg: dq 21                ; size of message
    db "Encountered an error", 10 ; message
