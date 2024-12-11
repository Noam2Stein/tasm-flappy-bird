IFNDEF SETUP_INCLUDED
SETUP_INCLUDED EQU 1

setup_graphics_mode MACRO
    mov ah, 0      ; Function to set video mode
    mov al, 13h    ; Mode 13h (320x200, 256 colors)
    int 10h        ; Call BIOS interrupt

    mov ax, 0A000h      ; Load video memory segment into AX
    mov es, ax          ; Move AX into ES
ENDM

setup_text_mode MACRO
    mov ah, 0           ; Function to set video mode
    mov al, 03h         ; Mode 03h (80x25, 16 colors)
    int 10h             ; Call BIOS interrupt
ENDM

quit MACRO
    setup_text_mode
    mov ah, 4Ch         ; Terminate the program
    int 21h
ENDM