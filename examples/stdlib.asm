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
