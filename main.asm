BLACK EQU 0
GREEN EQU 10
WHITE EQU 15

.model small
.stack 100h

.data

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
ENDM

setup_draw_es MACRO
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



;
;
; Drawing
;
;

apply_draw_di MACRO
    mov al, DrawY
    mov ah, 0
    mov dx, 320
    mul dx
    add ax, DrawX
    mov di, ax
ENDM

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

    mov ax, DrawWidth
    mov dx, 2
    div dx
    mov cx, ax

    mov al, DrawColor
    mov ah, DrawColor

    rep stosw

    inc bl
    mov dl, DrawY
    add dl, DrawHeight
    cmp bl, dl
    jne unique_label
ENDM



;
;
; Sprites
;
;


draw_block MACRO unique_label
    mov DrawWidth, 7
    mov DrawHeight, 7
    draw_rect unique_label

    apply_draw_di
    mov [es:di], WHITE
    add di, 321
    mov [es:di], WHITE
    add di, 1
    mov [es:di], WHITE
ENDM


;
;
; Main
;
;

main proc
    setup_graphics_mode
    setup_draw_es

    mov DrawColor, BLACK
    clear_screen

    mov DrawX, 30
    mov DrawY, 60
    mov DrawColor, GREEN
    draw_block u58403

    ; Wait for a key press to exit
    mov ah, 0           ; Wait for user input
    int 16h             ; BIOS keyboard interrupt

    quit
main endp
end main