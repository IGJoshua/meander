;;; stdlib.asm

;;; Calling Convention:
;;; Arguments are passed on the stack after the return address
;;; Returns from functions are treated like arguments, but without a return address
;;; rbx is a pointer like rbp that refers to the last prompt
;;; Stack Frame
;;; | align 16               |
;;; |------------------------|
;;; | return address         |
;;; | previous base pointer  |
;;; | previous r12           |
;;; |------------------------| <- r12
;;; | argn                   |
;;; | argn type              |
;;; | ...                    |
;;; | arg1                   |
;;; | arg1 type              |
;;; | arg count              |
;;; |------------------------| <- base pointer
;;;
;;; Callee-saved:
;;; - rbp
;;; - rsp
;;; - r13-r15
;;;
;;; Caller-saved:
;;; - rax
;;; - rcx
;;; - rdx
;;; - r8-r11
;;;
;;; Prompt Pointer:
;;; rbx
;;; The prompt pointer register should not be modified except to set a new
;;; prompt.
;;;
;;; Return Pointer:
;;; r12
;;; The return pointer register should not be modified except to mark a new
;;; return, which makes it caller-saved.

    default rel

%include "stdtypes.asm"

    ;; entrypoint
    global  _start

    ;; stdlib functions
    global  std__exit
    global  std__println
    global  std__add_int
    global  std__sub_int

    ;; main function of the executable
    extern  main

    ;; syscalls
    sys_exit    equ 60
    sys_write   equ 1
    sys_brk     equ 12

    ;; compile-time constants
    stdin   equ 0
    stdout  equ 1
    stderr  equ 2

    section .text
_start:
    push    rbp                 ; save the base pointer for the prompt
    push    0                   ; set the prompt index to 0, which is the whole program
    push    0                   ; store the base prompt pointer to zero, to indicate this is the last prompt
    mov     rbx, rsp            ; store the current stack pointer as the prompt base
    sub     rsp, 8              ; align the stack pointer

    lea     rax, [exit_cleanly]
    push    rax
    push    rbp
    push    r12
    mov     r12, rsp

    ;; TODO(Joshua): Parse command line arguments and pass them

    push    0                   ; no arguments

    mov     rbp, rsp            ; set the base pointer for argument indexing

    jmp     [main wrt ..got]    ; call the program

exit_cleanly:
    mov     rsp, r12
    pop     r12
    pop     rbp
    add     rsp, 8              ; ignore the return address

    mov     rdi, 0
    mov     rax, sys_exit       ; sys_exit(0)
    syscall

;;; std__println(args...)
std__println:
    cmp     qword [rbp+arg_ct], 1
    jne     error
    cmp     qword [rbp+arg1_t], string_t
    jne     error
    mov     rdi, stdout
    mov     rax, [rbp+arg1]
    lea     rsi, [rax]
    xor     rdx, rdx
    mov     dl, byte [rsi]
    add     rsi, 8

    mov     rax, 1              ; syscall write
    syscall

    mov     rsp, r12            ; pop args
    pop     r12                 ; restore r12 and rbp
    pop     rbp
    pop     rax                 ; ready return address

    sub     rsp, 8              ; continuation, no ret address
    push    rbp
    push    r12
    mov     r12, rsp
    push    0
    push    nil_t
    push    1
    mov     rbp, rsp
    jmp     rax                 ; call continuation with nil

;;; std__add_int(args...)
std__add_int:
    mov     rax, 0              ; accumulator
    mov     rcx, 0              ; arg index
add_loop:
    cmp     rcx, [rbp+arg_ct]   ; check if we've read the last argument
    jge     plus_return         ; if there's none left to add, return
    mov     r8, rcx
    imul    r8, 16
    mov     r9, [rbp+r8+arg1_t]
    cmp     r9, int_t           ; is this an int?
    jne     error               ; if not, exit with an error
    add     rax, [rbp+r8+arg1]  ; add the argument
    add     rcx, 1              ; increment the argument index
    jmp     add_loop            ; loop for the next arg
plus_return:
    mov     rbp, r12
    push    rax
    push    int_t
    push    1
    mov     rbp, rsp
    mov     rax, [r12+ret_addr]
    jmp     rax

;;; std__sub_int(args...)
;;; acts as unary negation, or subtracts later elements from former
std__sub_int:
    mov     r8, [rbp+arg_ct]
    cmp     r8, 1               ; check for exactly 1 arg
    je      unary_neg           ; unary negate for one argument
    mov     rcx, 1              ; arg index, start at 1 to not negate the first
negate_loop:
    mov     r8, [rbp+arg_ct]
    cmp     rcx, r8             ; check if we're at the last argument
    jge     std__add_int        ; if so, add them together
    mov     r8, rcx
    imul    r8, 16
    mov     r9, [rbp+r8+arg1_t]
    cmp     r9, int_t           ; check if it's an int
    jne     error               ; if not, error
    mov     rax, [rbp+r8+arg1]  ; grab the value to negate
    neg     rax                 ; negate it
    mov     [rbp+r8+arg1], rax  ; store it back
    add     rcx, 1              ; increment the arg index
    jmp     negate_loop         ; loop for the next arg

unary_neg:
    mov     r8, [rbp+arg1_t]    ; grab the arg type
    cmp     r8, int_t           ; check if it's int
    jne     error               ; if not, error
    mov     rcx, [rbp+arg1]     ; grab the first arg
    neg     rcx                 ; negate it
    mov     [rbp+arg1], rcx     ; save the negated arg
    mov     rax, [r12+ret_addr] ; grab return addr
    jmp     rax                 ; return

;;; std__exit(exit_code: int_t) -> !
;;; terminates the program
std__exit:
    cmp     qword [rbp+arg_ct], 1 ; test the number of arguments
    jne     error
    cmp     qword [rbp+arg1_t], int_t ; test the type of the argument
    jne     error
    mov     rdi, [rbp+arg1]
    mov     rsp, r12
    pop     r12
    pop     rbp
    add     rsp, 8              ; ignore the return address

    mov     rax, sys_exit
    syscall                     ; _exit(exit_code)

;; ;;; std__call_cc(rdi: prompt_id) -> (rdi: cont_ptr)
;; ;;; Allocates a section of memory for a continuation up to the specified delimiter
;; std__call_cc:
;;     Save all callee-save registers
;;     Search for prompt_id on the stack
;;     Allocate a stack
;;     Copy the stack to the allocation
;;     set the stack pointer to the prompt_id

;; std__invoke_cont:

;;; Internal error function
;;; Aligns the stack pointer to 16 bytes (assuming it's already 8-byte aligned)
;;; and calls _exit.
error:
    mov     rax, rsp
    mov     rdx, 0
    mov     rcx, 16
    div     rcx
    cmp     rdx, 0
    je      error__exit
    sub     rsp, 8

error__exit:
    mov     rdi, -1
    mov     rax, sys_exit
    syscall
