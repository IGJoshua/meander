    default rel

%include "stdtypes.asm"

    global  main

    extern  std__exit
    extern  std__println

    section .text
main:
    mov     rsp, r12
    pop     rbp                 ; pop the argument stack

    ;; top of stack has return address
    sub     rsp, 8              ; align stack pointer
    lea     rax, [post_println] ; set continuation
    push    rax
    push    rbp                 ; save rbp and r12
    push    r12
    mov     r12, rsp            ; set new r12
    lea     rax, [message]
    push    rax
    push    string_t
    push    1
    mov     rbp, rsp
    jmp     [std__println wrt ..got] ; std__println(message)

post_println:
    mov     rsp, r12            ; ignore args
    pop     r12
    pop     rbp
    add     rsp, 8              ; ignore ret

    add     rsp, 8              ; un-align stack pointer
    push    rbp
    push    r12
    mov     r12, rsp
    push    0
    push    int_t
    push    1
    mov     rbp, rsp
    jmp     [std__exit wrt ..got] ; std__exit(0)


    section .data
message:
    dq 14
    db "Hello, world!", 10
