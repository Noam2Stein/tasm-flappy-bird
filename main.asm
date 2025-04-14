.model small
.stack 100h

; INFO:

; * uses graphics mode 13h.

; * loads all sprites as one large buffer layed out sprite after sprite,
;   where each sprite is 16x16.
;   the sprites are loaded at runtime into a reserved data-segment variable from a binary file.

; * positions are stored in subpixels. subpixel = 1/16 pixels.

; ***************************************************
; ***************************************************
; ***************************************************
; ***************************************************
; ***************************************************
; ******************** CONSTANTS ********************
; ***************************************************
; ***************************************************
; ***************************************************
; ***************************************************
; ***************************************************

; DIMENSIONS

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200

SPRITE_WIDTH equ 16
SPRITE_HEIGHT equ 16
SPRITE_COUNT equ 8 * 8
SPRITES_BUF_SIZE equ SPRITE_WIDTH * SPRITE_HEIGHT * SPRITE_COUNT

; COLORS

BACKGROUND_COLOR equ 53

; GAMEPLAY

INITIAL_PLAYER_POSITION_Y equ SCREEN_HEIGHT / 2 * 16
PLAYER_POSITION_X equ SCREEN_WIDTH / 5 * 16

; **********************************************
; **********************************************
; **********************************************
; **********************************************
; **********************************************
; ******************** DATA ********************
; **********************************************
; **********************************************
; **********************************************
; **********************************************
; **********************************************

.data

;
;
;
; GAME LOOP
;
;
;

ExitGame db 0

;
;
;
; SPRITES
;
;
;

    SpritesFileName db "Sprites.bin"
    SpritesFileHandle     dw ?

    Sprites db SPRITES_BUF_SIZE dup(?) ; reserve memory for sprite palette which has 256 8x8 sprites.

;
;
;
; GAMEPLAY
;
;
;

    PlayerPositionY dw INITIAL_PLAYER_POSITION_Y
    PlayerVelocityY dw 0

; **********************************************
; **********************************************
; **********************************************
; **********************************************
; **********************************************
; ******************** CODE ********************
; **********************************************
; **********************************************
; **********************************************
; **********************************************
; **********************************************

.code

;
;
;
;
; INITIALIZATION
;
;
;
;

magic MACRO
    mov ax, 'a' + 'x'
    mov bx, 'b' + 'x'
    mov cx, 'c' + 'x'
    mov dx, 'd' + 'x'
ENDM

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

; changes `ax`, `bx`, `cx` and `dx`.
load_sprites PROC
    ; open file (INT 21h, AH = 3Dh)
    mov ah, 3Dh            ; open file
    mov al, 0              ; read-only mode
    mov dx, offset SpritesFileName
    int 21h
    jc load_failed         ; jump if failed
    mov [SpritesFileHandle], ax   ; store file handle

    ; read file (INT 21h, AH = 3Fh)
    mov ah, 3Fh            ; read from file
    mov bx, [SpritesFileHandle]   ; file handle
    mov cx, 36864          ; number of bytes to read
    mov dx, offset Sprites
    int 21h
    jc load_failed         ; jump if failed

    ; close file (INT 21h, AH = 3Eh)
    mov ah, 3Eh
    mov bx, [SpritesFileHandle]
    int 21h

    ret

    load_failed:

    ret
load_sprites ENDP

;
;
;
;
; RENDERING
;
;
;
;

; changes `ax`, `cx`, and `di`.
clear_screen MACRO
    mov al, BACKGROUND_COLOR
    mov ah, BACKGROUND_COLOR
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

; draws a sprite with the constant size of `SPRITE_WIDTH` and `SPRITE_HEIGHT`.
; put x coordinate in `ax` and y coordinate in `bx`.
; put sprite data-segment offset in `si`.
; changes `ax`, `bx`, `cx`, `dx`, `si`, and `di`.
draw_sprite PROC
    call set_di_from_xy_ax_bx

    mov cx, SPRITE_HEIGHT

    draw_row:
    push cx
    mov cx, SPRITE_WIDTH
    rep movsb
    add di, SCREEN_WIDTH - SPRITE_WIDTH
    pop cx

    loop draw_row

    ret
draw_sprite ENDP

; clears a sprite with the constant size of `SPRITE_WIDTH` and `SPRITE_HEIGHT`.
; put x coordinate in `ax` and y coordinate in `bx`.
; changes `ax`, `bx`, `cx`, `dx`, `si`, and `di`.
clear_sprite PROC
    call set_di_from_xy_ax_bx

    mov cx, SPRITE_HEIGHT

    clear_row:
    push cx
    mov cx, SPRITE_WIDTH / 2
    mov al, BACKGROUND_COLOR
    mov ah, BACKGROUND_COLOR
    rep stosw
    add di, SCREEN_WIDTH - SPRITE_WIDTH
    pop cx

    loop clear_row

    ret
clear_sprite ENDP

;
;
;
;
; GAMEPLAY
;
;
;
;

; doesn't return, instead jumps to `update_loop`.
; meant to be jumped to, and not to be called.
reset_game PROC
    mov PlayerPositionY, INITIAL_PLAYER_POSITION_Y
    mov PlayerVelocityY, 0

    jmp update_loop
reset_game ENDP

apply_player_position MACRO
    mov ax, PLAYER_POSITION_X / 16
    mov bx, PlayerPositionY
    shr bx, 4 ; divide by 16
    mov bh, 0 ; reset overflowed bits
ENDM

update_player_movement PROC
    ; clear at old position
    apply_player_position
    call clear_sprite

    ; update velocity and position
    inc PlayerVelocityY
    mov ax, PlayerVelocityY
    add PlayerPositionY, ax

    ; check if player fell
    cmp PlayerPositionY, (SCREEN_HEIGHT - SPRITE_HEIGHT) * 16
    jae reset_game

    ; draw at new position
    apply_player_position
    mov si, offset Sprites
    call draw_sprite

    ret
update_player_movement ENDP

;
;
;
;
; GAME LOOP
;
;
;
;

wait_milliseconds MACRO milliseconds
    mov ah, 86h
    mov cx, 0 ; high word of time to wait is 0
    mov dx, milliseconds * 1000
    int 15h
ENDM

;

initialize PROC
    magic
    init_video_mode
    init_ds_as_data_segment
    call load_sprites

    clear_screen

    ret
initialize ENDP

;

update PROC
    call update_player_movement

    wait_milliseconds 20

    ret
update ENDP

;

clean_up PROC
    ; set video mode to 3h (text mode 80x25)
    mov ah, 0
    mov al, 3
    int 10h

    ; clear screen
    mov ah, 06h      ; scroll up function
    mov al, 0        ; entire screen
    mov bh, 07h      ; attribute (light gray on black)
    mov cx, 0        ; upper-left corner (row 0, col 0)
    mov dx, 184FH    ; lower-right corner (row 24, col 79)
    int 10h

    ; return control to DOS
    mov ax, 4C00h
    int 21h

    ret
clean_up ENDP

;
;
;
;
; MAIN
;
;
;
;

main PROC
    call initialize

    update_loop:
    call update

    cmp ExitGame, 0
    je update_loop

    call clean_up
main ENDP

end main