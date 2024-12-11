SCREEN_COUNT EQU 2

.model small
.stack 100h

.data

Screens db 320 * 200 * SCREEN_COUNT dup (0)

DrawX dw ?
DrawY db ?
DrawWidth dw ?
DrawHeight db ?
DrawColor db ?

.code

;
;
; Setup
;
;

setup_graphics_mode MACRO
    mov ah, 0      ; Function to set video mode
    mov al, 13h    ; Mode 13h (320x200, 256 colors)
    int 10h        ; Call BIOS interrupt

    mov ax, seg Screens      ; Load video memory segment into AX
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



;
;
; Drawing
;
;

clear_screen MACRO
    mov al, DrawColor
    mov ah, DrawColor
    mov di, 0
    mov cx, 320 * 200 / 2
    rep stosw
ENDM

draw_rect MACRO unique_label
    mov bl, DrawY
    mov bh, 0

    unique_label:
    mov ax, bx
    mov dx, 320
    mul dx
    add ax, DrawX
    mov di, ax

    mov al, DrawColor
    mov ah, DrawColor

    mov cx, DrawWidth
    rep stosw

    inc bl
    mov dl, DrawY
    add dl, DrawHeight
    cmp bl, dl
    jne unique_label
ENDM



;
;
; Main
;
;

main proc
    setup_graphics_mode

    mov DrawColor, 0
    clear_screen

    mov DrawX, 30
    mov DrawY, 60
    mov DrawWidth, 60
    mov DrawHeight, 40
    mov DrawColor, 14
    draw_rect u58403

    ; Wait for a key press to exit
    mov ah, 0           ; Wait for user input
    int 16h             ; BIOS keyboard interrupt

    quit
main endp
end main