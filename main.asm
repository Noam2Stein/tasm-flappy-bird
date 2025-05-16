.model small
.stack 100h

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

;
; unit info:
;
; `SP` = sub-pixels
; `P` = pixels
; `T` = tiles (1 tile is 1 sprite size)
;
; time unit is always frames.
; memory unit is always bytes.
;

;
;
; CONFIGURABLE
;
;

; GAMEPLAY
SP_INITIAL_PLAYER_YPOS equ SP_SCREEN_HEIGHT / 2
SP_PLAYER_XPOS equ SP_SCREEN_WIDTH / 5
SP_PLAYER_JUMP_VELOCITY equ -20

PIPEPAIR_COUNT equ 5
T_PIPE_WIDTH equ 2
T_PIPEPAIR_XDISTANCE equ 5
T_PIPEPAIR_YDISTANCE equ 5
T_MIN_PIPE_HEIGHT equ 3

; GRAPHICS
BACKGROUND_COLOR equ 53

P_SPRITE_SIZE equ 16 ; 16x16
P_SPRITE_SIZE_LOG2 equ 4
SPRITE_COUNT equ 256 / P_SPRITE_SIZE

PLAYER_SPRITE        equ 0
PIPE_L_TOP_SPRITE    equ 1
PIPE_L_SPRITE        equ 3
PIPE_L_BOTTOM_SPRITE equ 5
PIPE_R_TOP_SPRITE    equ 2
PIPE_R_SPRITE        equ 4
PIPE_R_BOTTOM_SPRITE equ 6

; GAMELOOP
END_OF_FRAME_WAIT equ 10

; UNITS
PIXELS_TO_SUBPIXELS equ 16

;
;
; NON CONFIGURABLE
;
;

; GAMEPLAY
T_MAX_PIPE_HEIGHT equ T_SCREEN_HEIGHT - T_MIN_PIPE_HEIGHT - T_PIPEPAIR_YDISTANCE

; GRAPHICS
P_SCREEN_WIDTH equ 320
P_SCREEN_HEIGHT equ 200

SPRITE_BUF_SIZE equ P_SPRITE_SIZE * P_SPRITE_SIZE
SPRITES_BUF_SIZE equ SPRITE_BUF_SIZE * SPRITE_COUNT

; INPUT
SPACE_MAKECODE equ 39h
ESCAPE_MAKECODE equ 01h

; UNITS
TILES_TO_PIXELS equ P_SPRITE_SIZE
TILES_TO_SUBPIXELS equ TILES_TO_PIXELS * PIXELS_TO_SUBPIXELS

;
;
; INTO TILES
;
;

; GRAPHICS
T_SCREEN_WIDTH  equ P_SCREEN_WIDTH / TILES_TO_PIXELS
T_SCREEN_HEIGHT  equ P_SCREEN_HEIGHT / TILES_TO_PIXELS

;
;
; INTO PIXELS
;
;

;
;
; INTO SUBPIXELS
;
;

; GAMEPLAY
SP_PIPE_WIDTH equ T_PIPE_WIDTH * TILES_TO_SUBPIXELS
SP_PIPEPAIR_XDISTANCE equ T_PIPEPAIR_XDISTANCE * TILES_TO_SUBPIXELS

; GRAPHICS
SP_SCREEN_WIDTH equ P_SCREEN_WIDTH * PIXELS_TO_SUBPIXELS
SP_SCREEN_HEIGHT equ P_SCREEN_HEIGHT * PIXELS_TO_SUBPIXELS

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

; SPRITES
    SpritesFileName   db "Sprites.bin"
    SpritesFileHandle dw ?

    SpritesBuf db SPRITES_BUF_SIZE dup(?)

; GAMELOOP STATE
    GameLoopUpdateFn dw ? ; changes based on game-state (wait / gameplay).

; GAMEPLAY
    PlayerYPos      dw SP_INITIAL_PLAYER_YPOS
    PlayerYVelocity dw 0

    PipePairXPoses        dw PIPEPAIR_COUNT dup (?)
    PipePairBottomHeights dw PIPEPAIR_COUNT dup (?)

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
; MATH
;
;
;
;

; sets `cx` to the signed minimum of `cx` and `dx`
set_min_cx PROC
    cmp cx, dx
    jl min_pick_dx

    min_pick_cx:
    ret

    min_pick_dx:
    mov cx, dx
    ret
set_min_cx ENDP

; sets `cx` to the signed maximum of `cx` and `dx`
set_max_cx PROC
    cmp cx, dx
    js max_pick_dx

    max_pick_cx:
    ret

    max_pick_dx:
    mov cx, dx
    ret
set_max_cx ENDP

;
;
;
;
; GRAPHICS
;
;
;
;

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
    mov dx, offset SpritesBuf
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

; changes `ax`, `cx`, and `di`.
clear_screen MACRO
    mov al, BACKGROUND_COLOR
    mov ah, BACKGROUND_COLOR
    mov cx, P_SCREEN_WIDTH * P_SCREEN_HEIGHT / 2
    mov di, 0
    rep stosw
ENDM

move_drawpos_right MACRO
    add ax, P_SPRITE_SIZE
ENDM
move_drawpos_left MACRO
    sub ax, P_SPRITE_SIZE
ENDM
move_drawpos_up MACRO
    sub bx, P_SPRITE_SIZE
ENDM
move_drawpos_down MACRO
    add bx, P_SPRITE_SIZE
ENDM

; put x coordinate in `ax` and y coordinate in `bx`.
; sets `di` to the screen memory offset.
; changes `ax`, `bx`, `cx`, and `di`.
set_drawpos_di PROC
    mov di, bx ; di = y
    shl di, 6 ; di = y * 64

    mov cx, bx ; cx = y
    shl cx, 8 ; cx = y * 256

    add di, cx ; di = y * 320 = y * 64 + y * 256
    
    add di, ax ; di = y * 320 + x

    ret
set_drawpos_di ENDP

set_sprite MACRO sprite
    mov si, offset SpritesBuf + sprite * SPRITE_BUF_SIZE
ENDM

; draws a sprite with the constant size of `SPRITE_WIDTH` and `SPRITE_HEIGHT`.
; put x coordinate in `ax` and y coordinate in `bx`.
; put sprite data-segment offset in `si`.
; changes `ax`, `bx`, `cx`, `dx`, `si`, and `di`.
draw_sprite PROC
    call set_drawpos_di

    mov cx, P_SPRITE_SIZE
    mov dx, P_SCREEN_HEIGHT
    sub dx, bx ; dx is now `P_SCREEN_HEIGHT - Y_POS`
    call set_min_cx ; don't draw out of bounds rows

    draw_row:
    push cx

    mov cx, P_SPRITE_SIZE
    mov dx, P_SCREEN_WIDTH
    sub dx, ax ; dx is now `P_SCREEN_WIDTH - X_POS`
    call set_min_cx ; don't draw out of bounds columns
    rep movsb
    add di, P_SCREEN_WIDTH - P_SPRITE_SIZE

    pop cx
    loop draw_row

    ret
draw_sprite ENDP

; clears a sprite with the constant size of `SPRITE_WIDTH` and `SPRITE_HEIGHT`.
; put x coordinate in `ax` and y coordinate in `bx`.
; changes `ax`, `bx`, `cx`, `dx`, `si`, and `di`.
clear_sprite PROC
    call set_drawpos_di

    mov cx, P_SPRITE_SIZE

    clear_row:
    push cx
    mov cx, P_SPRITE_SIZE / 2
    mov al, BACKGROUND_COLOR
    mov ah, BACKGROUND_COLOR
    rep stosw
    add di, P_SCREEN_WIDTH - P_SPRITE_SIZE
    pop cx

    loop clear_row

    ret
clear_sprite ENDP

; calls draw but pushes and pops the values of `ax`, `bx`, `cx` and `dx`.
draw_sprite_pushed PROC
    push ax
    push bx
    push cx
    push dx
    call draw_sprite
    pop dx
    pop cx
    pop bx
    pop ax

    ret
draw_sprite_pushed ENDP

;
;
;
;
; INPUT
;
;
;
;

; `eq` flag represents whether or not the key was just triggered.
; changes `al`.
detect_key_trigger MACRO makecode
    in al, 60h
    cmp al, makecode
ENDM

;
;
;
;
; PLAYER
;
;
;
;

; dont call, use jmp stuff
on_player_hit_bottom PROC
    jmp jmp_gameloop_wait
on_player_hit_bottom ENDP

set_player_drawpos MACRO
    mov ax, SP_PLAYER_XPOS / 16

    mov bx, PlayerYPos
    shr bx, 4 ; divide by 16 (subpixels -> pixels)
    and bx, 0FFFh ; reset overflowed bits
ENDM

player_jump_check MACRO params
    detect_key_trigger SPACE_MAKECODE
    jne skip_jump

    mov PlayerYVelocity, SP_PLAYER_JUMP_VELOCITY

    skip_jump:
ENDM

update_player_movement PROC
    ; clear old player sprite
    set_player_drawpos
    call clear_sprite

    ; update velocity
    inc PlayerYVelocity
    player_jump_check

    ; update pposition
    mov ax, PlayerYVelocity
    add PlayerYPos, ax

    ; check if player fell to the bottom of the screen
    cmp PlayerYPos, (P_SCREEN_HEIGHT - P_SPRITE_SIZE) * 16
    jae on_player_hit_bottom

    ; draw new player sprite
    set_player_drawpos
    set_sprite PLAYER_SPRITE
    call draw_sprite

    ret
update_player_movement ENDP

;
;
;
;
; PIPES
;
;
;
;

; expects `dx` to contain the pipe index.
set_pipepair_si MACRO
    mov si, dx
    shl si, 1
ENDM

pipepair_loop MACRO loop_label
    mov cx, PIPEPAIR_COUNT

    loop_label:

    mov dx, cx
    dec dx
ENDM

; expects `dx` to contain the pipe index.
init_pipepair_x_pos PROC
    push dx

    mov bx, dx
    mov ax, 1170;SP_PIPEPAIR_XDISTANCE + SP_PIPE_WIDTH
    mul bx
    
    pop dx
    set_pipepair_si
    mov [PipePairXPoses + si], ax

    ret
init_pipepair_x_pos ENDP

; expects `dx` to contain the pipe index.
; changes `bx`.
init_pipepair_bottom_height PROC
    set_pipepair_si

    ; randomize `bx` with unique values
    add bx, dx
    add bx, PlayerYVelocity
    and bx, PlayerYPos

    ; constraint `bx` to `0..16`
    and bx, 000Fh

    ; scale `bx` to `T_MIN_PIPE_HEIGHT..=T_MAX_PIPE_HEIGHT`
    mov al, T_MAX_PIPE_HEIGHT - T_MIN_PIPE_HEIGHT
    mul bl
    mov bx, ax
    shr bx, 4
    and bx, 0FFFh
    add bx, T_MIN_PIPE_HEIGHT

    mov [PipePairBottomHeights + si], bx

    ret
init_pipepair_bottom_height ENDP

init_pipepairs PROC
    pipepair_loop init_pipepairs_loop
    
    call init_pipepair_bottom_height
    call init_pipepair_x_pos

    loop init_pipepairs_loop

    ret
init_pipepairs ENDP

set_pipepair_x_drawpos MACRO
    mov ax, [PipePairXPoses + si]
    shr ax, 4 ; divide by 16 (subpixels -> pixels)
    and ax, 0FFFh ; reset overflowed bits
ENDM

; expects `dx` to contain the pipe index.
; changes `si`.
set_bottom_pipe_drawpos MACRO
    set_pipepair_si

    set_pipepair_x_drawpos

    mov bx, P_SCREEN_HEIGHT - P_SPRITE_SIZE
ENDM

; expects `dx` to contain the pipe index.
; changes `si`.
set_top_pipe_drawpos MACRO
    set_pipepair_si
    
    set_pipepair_x_drawpos

    mov bx, T_SCREEN_HEIGHT - T_PIPEPAIR_YDISTANCE - 1
    sub bx, [PipePairBottomHeights + si]
    shl bx, P_SPRITE_SIZE_LOG2
ENDM

; expects `dx` to contain the pipe index.
draw_pipe_row MACRO left_sprite, right_sprite
    set_sprite left_sprite
    call draw_sprite_pushed

    move_drawpos_right

    set_sprite right_sprite
    call draw_sprite_pushed

    move_drawpos_left
    move_drawpos_up
ENDM

; expects `dx` to contain the pipe index.
set_bottom_pipe_height_cx MACRO params
    set_pipepair_si
    mov cx, [PipePairBottomHeights + si]
ENDM

; expects `dx` to contain the pipe index.
set_top_pipe_height_cx MACRO
    set_pipepair_si
    mov ax, [PipePairBottomHeights + si]
    mov cx, P_SCREEN_HEIGHT / P_SPRITE_SIZE - T_PIPEPAIR_YDISTANCE
    sub cx, ax
ENDM

; expects `dx` to contain the pipe index.
draw_bottom_pipe PROC
    set_bottom_pipe_drawpos

    set_bottom_pipe_height_cx
    dec cx
    draw_bottom_pipe_rows:
    draw_pipe_row PIPE_L_SPRITE, PIPE_R_SPRITE
    loop draw_bottom_pipe_rows

    draw_pipe_row PIPE_L_TOP_SPRITE, PIPE_R_TOP_SPRITE

    ret
draw_bottom_pipe ENDP

; expects `dx` to contain the pipe index.
draw_top_pipe PROC
    set_top_pipe_height_cx
    dec cx

    set_top_pipe_drawpos
    draw_pipe_row PIPE_L_BOTTOM_SPRITE, PIPE_R_BOTTOM_SPRITE

    draw_top_pipe_rows:
    draw_pipe_row PIPE_L_SPRITE, PIPE_R_SPRITE
    loop draw_top_pipe_rows

    ret
draw_top_pipe ENDP

; sets the `zero-flag` to false if the pipepair should be culled.
; expects `dx` to contain the pipe index.
pipepair_cull_check PROC
    ; move x drawpos into `ax`
    set_pipepair_si
    set_pipepair_x_drawpos

    mov bx, -SP_PIPE_WIDTH ; minimum visible pipe x-pos
    cmp ax, bx
    jle not_in_range

    mov bx, SP_SCREEN_WIDTH ; maximum visible pipe x-pos
    cmp ax, bx
    jge not_in_range

    jmp in_range

    not_in_range:
    mov ax, 0
    mov bx, 1
    cmp ax, bx
    ret

    in_range:
    mov ax, 0
    cmp ax, ax
    ret
pipepair_cull_check ENDP

draw_pipes PROC
    pipepair_loop draw_pipes_loop

    push cx
    call pipepair_cull_check
    jne skip_pipepair_draw

    call draw_bottom_pipe
    call draw_top_pipe

    skip_pipepair_draw:
    pop cx

    loop draw_pipes_loop

    ret
draw_pipes ENDP

;
;
;
;
; GAMEPLAY GAME-STATE
;
;
;
;

; * doesn't return, meant to be used with `jmp` and not `call`.
jmp_gameloop_gameplay PROC
    mov GameLoopUpdateFn, offset gameloop_gameplay_update

    jmp main_loop
jmp_gameloop_gameplay ENDP

gameloop_gameplay_update PROC
    call update_player_movement
    call draw_pipes

    ret
gameloop_gameplay_update ENDP

;
;
;
;
; WAIT GAME-STATE
;
;
;
;

; * doesn't return, meant to be used with `jmp` and not `call`.
jmp_gameloop_wait PROC
    mov PlayerYPos, SP_INITIAL_PLAYER_YPOS
    mov PlayerYVelocity, 0
    
    call init_pipepairs

    mov GameLoopUpdateFn, offset gameloop_wait_update

    jmp main_loop
jmp_gameloop_wait ENDP

gameloop_wait_update PROC
    set_player_drawpos
    set_sprite PLAYER_SPRITE
    call draw_sprite

    call draw_pipes

    detect_key_trigger SPACE_MAKECODE
    je jmp_gameloop_gameplay

    ret
gameloop_wait_update ENDP

;
;
;
;
; INITIALIZATION
;
;
;
;

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

initialize PROC
    ; fix a dosbox emulation error by moving random values into these registers.
    mov ax, 'a' + 'x'
    mov bx, 'b' + 'x'
    mov cx, 'c' + 'x'
    mov dx, 'd' + 'x'

    init_video_mode
    init_ds_as_data_segment
    call load_sprites

    clear_screen

    call jmp_gameloop_wait

    ret
initialize ENDP

;
;
;
;
; UPDATE
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

update PROC
    mov ax, GameLoopUpdateFn
    call ax

    wait_milliseconds END_OF_FRAME_WAIT

    ret
update ENDP

;
;
;
;
; CLEAN UP
;
;
;
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

    main_loop:
    call update

    detect_key_trigger ESCAPE_MAKECODE
    jne main_loop ; repeat update if escape wasn't pressed

    call clean_up
main ENDP

end main