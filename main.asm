.model small
.stack 100h

;
;
;
;
;
; CONSTANTS
;
;
;
;
;

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200

TEXTURE_WIDTH equ 8
TEXTURE_HEIGHT equ 8

;
;
;
;
;
; DATA
;
;
;
;
;

.data
    Texture db 0, 0, 4, 4, 4, 4, 0, 0, \
               0, 4, 4, 4, 4, 4, 4, 0, \
               4, 4, 4, 4, 4, 4, 4, 4, \
               4, 4, 4, 4, 4, 4, 4, 4, \
               4, 4, 4, 4, 4, 4, 4, 4, \
               4, 4, 4, 4, 4, 4, 4, 4, \
               0, 4, 4, 4, 4, 4, 4, 0, \
               0, 0, 4, 4, 4, 4, 0, 0

;
;
;
;
;
; CODE
;
;
;
;
;

.code

; changes `ax`, and `ds`.
init_ds_as_data_segment MACRO
    mov ax, @data
    mov ds, ax
ENDM

; changes `ax`, and `es`.
init_video_mode MACRO
    ; Set VGA Mode 13h (320x200, 256 colors)
    mov ax, 13h       ; Set video mode to 13h (320x200, 256 colors)
    int 10h           ; Call video BIOS interrupt

    ; Set video memory location (0xA0000 -> Mode 13h framebuffer)
    mov ax, 0A000h       ; Load the base address of video memory into AX
    mov es, ax           ; Set ES to point to video memory
ENDM

; put the clear color in `al`.
; changes `ax`, `cx`, and `di`.
clear_screen_to_al MACRO
    mov ah, al
    mov cx, SCREEN_WIDTH * SCREEN_HEIGHT / 2
    mov di, 0
    rep stosw
ENDM

; put x coordinate in `ax` and y coordinate in `bx`.
; sets `di` to the screen memory offset.
; changes `ax`, `bx`, `cx`, and `di`.
set_di_from_xy_ax_bx PROC
    mov di, bx ; di = y
    shl di, 6 ; di = y * 64

    mov cx, bx ; cx = y
    shl cx, 8 ; cx = y * 256

    add di, cx ; di = y * 320 = y * 64 + y * 256
    
    add di, ax ; di = y * 320 + x

    ret
set_di_from_xy_ax_bx ENDP

; put x coordinate in `ax` and y coordinate in `bx`.
; put texture width in `dx` and texture height in `cx`.
; put texture data-segment offset in `si`.
; changes `ax`, `bx`, `cx`, `dx`, `si`, and `di`.
draw_sprite PROC
    push cx ; `set_di_from_xy_ax_bx` changes `cx`
    call set_di_from_xy_ax_bx
    pop cx

    draw_line:
    push cx
    mov cx, dx
    rep movsb
    add di, SCREEN_WIDTH
    sub di, dx
    pop cx

    loop draw_line

    ret
draw_sprite ENDP

;
;
;
; MAIN
;
;
;

main PROC
    init_ds_as_data_segment
    init_video_mode

    mov al, 1
    clear_screen_to_al

    mov ax, SCREEN_WIDTH / 2 - TEXTURE_WIDTH / 2
    mov bx, SCREEN_HEIGHT / 2 - TEXTURE_HEIGHT / 2
    mov dx, TEXTURE_WIDTH
    mov cx, TEXTURE_HEIGHT
    mov si, offset Texture
    call draw_sprite
main ENDP

end main