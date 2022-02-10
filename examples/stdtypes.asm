;;; Types
;;; int and doubles are primitives
;;; all other types are references
;;; | Type     | Index |
;;; |----------|-------|
;;; | nil_t    |     0 |
;;; | int_t    |     1 |
;;; | double_t |     2 |
;;; | string_t |     3 |
;;; | cont_t   |     4 |

;;; Strings
;;; Strings act as fat pointers
;;; | length | data... |

    nil_t   equ 0
    int_t   equ 1
    double_t equ 2
    string_t equ 3
    cont_t  equ 4

    ;; Helpers for the calling convention to refer to arguments
    arg_ct  equ 0
    arg1_t  equ 8
    arg1    equ 16
    arg2_t  equ 24
    arg2    equ 32
    arg3_t  equ 40
    arg3    equ 48
    arg4_t  equ 56
    arg4    equ 64
    arg5_t  equ 72
    arg5    equ 80

    ;; Helpers for the calling convention to refer to stack pointers
    old_r12 equ 0
    old_rbp equ 8
    ret_addr equ 16
