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
END_OF_FRAME_WAIT equ 5

SP_INITIAL_PLAYER_YPOS equ SP_SCREEN_HEIGHT / 2
SP_PLAYER_XPOS equ SP_SCREEN_WIDTH / 7
SP_PLAYER_JUMP_VELOCITY equ 40
SP_PLAYER_GRAVITY_SCALE equ 6

PIPEPAIR_COUNT equ 4
T_PIPE_WIDTH equ 2
T_PIPEPAIR_XDISTANCE equ 4
T_PIPEPAIR_YDISTANCE equ 3
T_MIN_PIPE_HEIGHT equ 2
SP_PIPE_VELOCITY equ -16
P_PIPE_CLEAR_OFFSET equ 2

; DEATH
SP_DEATH_PLAYER_JUMP_VELOCITY equ 100
SP_DEATH_PLAYER_GRAVITY_SCALE equ 7

; GRAPHICS
BACKGROUND_COLOR equ 53

P_SPRITE_SIZE equ 16 ; 16x16
P_SPRITE_SIZE_LOG2 equ 4
SPRITE_COUNT equ 256 / P_SPRITE_SIZE

PLAYER_SPRITE        equ 0
PLAYER_FLAP_SPRITE   equ 1
PLAYER_DEAD_SPRITE   equ 2
PIPE_L_TOP_SPRITE    equ 3
PIPE_L_SPRITE        equ 5
PIPE_L_BOTTOM_SPRITE equ 7
PIPE_R_TOP_SPRITE    equ 4
PIPE_R_SPRITE        equ 6
PIPE_R_BOTTOM_SPRITE equ 8

PLAYER_ANIM_FRAME_DURATION equ 3
PLAYER_FLAP_ANIM_MIN_VELOCITY equ -5


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
P_SCREEN_AREA equ P_SCREEN_WIDTH * P_SCREEN_HEIGHT

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
    
    PlayerYPos        dw SP_INITIAL_PLAYER_YPOS
    PlayerAnimTime dw 0
    PlayerYVelocity   dw 0

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

loop_start MACRO label_, end_label
    label_:
    cmp cx, 0
    jle end_label
ENDM

loop_end MACRO label_, end_label
    dec cx
    jmp label_
    end_label:
ENDM

;
;
;
;
; GRAPHICS (HELPERS)
; 
;
;
;

; input:
; `ax` -> x coordinate,
; `bx` -> y coordinate.
;
; effects:
; `di` -> ptr to screen coordinate.
set_draw_di PROC
    push cx

    mov di, bx ; di = y
    shl di, 6 ; di = y * 64

    mov cx, bx ; cx = y
    shl cx, 8 ; cx = y * 256

    add di, cx ; di = y * 320 = y * 64 + y * 256
    
    add di, ax ; di = y * 320 + x

    pop cx
    ret
set_draw_di ENDP

; input:
; `ax` -> width,
; `bx` -> height.
; `si` -> sprite src-pos.
; `di` -> sprite dst-pos.
draw_sprite_row MACRO
    cmp ax, 0
    jle post_draw_sprite_row

    push cx
    mov cx, ax
    rep movsb
    pop cx

    ; revert `si` and `di` progression caused by `movsb`
    sub si, ax
    sub di, ax

    add si, P_SPRITE_SIZE
    add di, P_SCREEN_WIDTH

    post_draw_sprite_row:
ENDM

; input:
; `ax` -> width,
; `bx` -> height.
; `di` -> sprite dst-pos.
clear_sprite_row MACRO
    cmp ax, 0
    jle post_clear_sprite_row

    push cx
    push ax
    mov cx, ax
    mov ax, BACKGROUND_COLOR
    rep stosb
    pop ax
    pop cx

    sub di, ax ; revert the `di` progression caused by `stosb`
    add di, P_SCREEN_WIDTH

    post_clear_sprite_row:
ENDM

; clips the sprite rect, removing offscreen parts.
;
; input:
; `ax` -> x,
; `bx` -> y,
; `cx` -> width,
; `dx` -> height,
; `si` -> sprite origin.
;
; effects:
; `ax` -> new x,
; `bx` -> new y,
; `cx` -> new width,
; `dx` -> new height,
; `si` -> new sprite origin.
clip_draw_rect PROC
    cmp ax, 0
    jge post_clip_left
    ; clip left
    add cx, ax
    sub si, ax
    mov ax, 0 ; clip left always leaves the xpos at `0`
    post_clip_left:

    cmp bx, 0
    jge post_clip_top
    ; clip top
    add dx, bx
    sal bx, P_SPRITE_SIZE_LOG2 ; now `bx` contains `unclipped_ypos * P_SPRITE_SIZE`
    sub si, bx
    mov bx, 0 ; top left always leaves the ypos at `0`
    post_clip_top:

    add cx, ax ; now `cx` contains the rect's right edge
    cmp cx, P_SCREEN_WIDTH
    jle post_clip_right
    ; clip right
    mov cx, P_SCREEN_WIDTH
    post_clip_right:
    sub cx, ax ; now `cx` contains the rect's width again

    add dx, bx ; now `dx` contains the rect's bottom edge
    cmp dx, P_SCREEN_HEIGHT
    jle post_clip_bottom
    ; clip bottom
    mov dx, P_SCREEN_HEIGHT
    post_clip_bottom:
    sub dx, bx ; now `dx` contains the rect's height again

    ret
clip_draw_rect ENDP

;
;
;
;
; GRAPHICS
; 
;
;
;

; effects:
; `SpritesBuf` -> init,
; `ax` -> ?,
; `bx` -> ?,
; `cx` -> ?,
; `dx` -> ?,
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

; effects:
; `ax` -> ?,
; `cx` -> ?,
; `di` -> ?.
clear_screen MACRO color
    mov al, color
    mov ah, color
    mov cx, P_SCREEN_AREA / 2
    mov di, 0
    rep stosw
ENDM

; affects the draw x which is stored in `ax`.
set_draw_x MACRO x
    mov ax, x
ENDM

; affects the draw y which is stored in `bx`.
set_draw_y MACRO y
    mov bx, y
ENDM

; affects the draw width which is stored in `cx`.
set_draw_width MACRO width
    mov cx, width
ENDM

; affects the draw height which is stored in `dx`.
set_draw_height MACRO height
    mov dx, height
ENDM

; affects the drawpos which is stored using `ax` as X and `bx` as Y.
move_draw_right MACRO amount
    add ax, amount
ENDM

; affects the drawpos which is stored using `ax` as X and `bx` as Y.
move_draw_left MACRO amount
    sub ax, amount
ENDM

; affects the drawpos which is stored using `ax` as X and `bx` as Y.
move_drawpos_up MACRO amount
    sub bx, amount
ENDM

; affects the drawpos which is stored using `ax` as X and `bx` as Y.
move_draw_down MACRO amount
    add bx, amount
ENDM

; sets the sprite for the next `draw_sprite` (is stored in `si`).
set_draw_sprite MACRO sprite
    mov si, offset SpritesBuf + sprite * SPRITE_BUF_SIZE
ENDM

; draws a sprite with a configurable rect.
;
; input:
; `ax` -> x (use `set_draw_x`),
; `bx` -> y (use `set_draw_y`),
; `cx` -> width (use `set_draw_width`),
; `dx` -> height (use `set_draw_height`),
; `si` -> sprite ptr (use `set_draw_sprite`).
;
; effects:
; `ax` -> ?,
; `bx` -> ?,
; `cx` -> ?,
; `dx` -> ?,
; `si` -> ?,
; `di` -> ?.
draw_sprite PROC
    call clip_draw_rect
    call set_draw_di
    mov ax, cx
    mov bx, dx

    ; when calling this proc `ax` and `bx` store the drawpos which is now unused.
    ; from this point they hold the drawsize which is affected by clipping.
    ; moving the drawsize to `ax` and `bx` leaves `cx` and `dx` unused for `draw_sprite_row`.

    mov cx, bx
    loop_start draw_sprite_loop, draw_sprite_loop_end
    draw_sprite_row
    loop_end draw_sprite_loop, draw_sprite_loop_end

    ret
draw_sprite ENDP

; clears a configurable rect.
;
; input:
; `ax` -> x (use `set_draw_x`),
; `bx` -> y (use `set_draw_y`),
; `cx` -> width (use `set_draw_width`),
; `dx` -> height (use `set_draw_height`).
;
; effects:
; `ax` -> ?,
; `bx` -> ?,
; `cx` -> ?,
; `dx` -> ?,
; `si` -> ?,
; `di` -> ?.
clear_rect PROC
    call clip_draw_rect
    call set_draw_di
    mov ax, cx
    mov bx, dx

    ; when calling this proc `ax` and `bx` store the drawpos which is now unused.
    ; from this point they hold the drawsize which is affected by clipping.
    ; moving the drawsize to `ax` and `bx` leaves `cx` and `dx` unused for `clear_sprite_row`.

    mov cx, bx
    loop_start clear_sprite_loop, clear_sprite_loop_end
    clear_sprite_row
    loop_end clear_sprite_loop, clear_sprite_loop_end

    ret
clear_rect ENDP

; variation of `draw_sprite` that leaves more registers unchanged and requires a constant size.
;
; input:
; `ax` x (use `set_draw_x`),
; `bx` y (use `set_draw_y`),
; `si` sprite ptr (use `set_draw_sprite`).
;
; effects:
; `di` -> ?.
draw_sprite_pushed MACRO width, height
    push ax
    push bx
    push cx
    push dx
    push si
    set_draw_width width
    set_draw_height height
    call draw_sprite
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
ENDM

; variation of `clear_rect` that leaves more registers unchanged.
;
; input:
; `ax` x (use `set_draw_x`),
; `bx` y (use `set_draw_y`),
;
; effects:
; `di` -> ?.
clear_rect_pushed MACRO width, height
    push ax
    push bx
    push cx
    push dx
    push si
    set_draw_width width
    set_draw_height height
    call clear_rect
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
ENDM

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

set_player_draw_rect PROC
    ; x
    mov ax, SP_PLAYER_XPOS / PIXELS_TO_SUBPIXELS

    ; y
    mov bx, PlayerYPos
    sar bx, 4 ; divide by 16 (subpixels -> pixels)

    ; width
    set_draw_width P_SPRITE_SIZE

    ; height
    set_draw_height P_SPRITE_SIZE

    ret
set_player_draw_rect ENDP

player_jump_check PROC
    detect_key_trigger SPACE_MAKECODE
    jne skip_jump

    mov PlayerYVelocity, -SP_PLAYER_JUMP_VELOCITY

    skip_jump:
    ret
player_jump_check ENDP

move_player MACRO gravity_scale
    add PlayerYVelocity, gravity_scale

    mov ax, PlayerYVelocity
    add PlayerYPos, ax
ENDM

jmp_kill_player PROC
    jmp jmp_gameloop_death
jmp_kill_player ENDP

player_out_of_bounds_check PROC
    ; check if the player fell to the bottom of the screen
    cmp PlayerYPos, (P_SCREEN_HEIGHT - P_SPRITE_SIZE) * 16
    jg jmp_kill_player

    ; check if the player flew to the top of the screen
    cmp PlayerYPos, 0
    jl jmp_kill_player

    ret
player_out_of_bounds_check ENDP

player_collision_check PROC
    call set_player_draw_rect

    ; check top left corner
    move_draw_left 1
    move_drawpos_up 1
    call set_draw_di
    cmp byte ptr es:[di], BACKGROUND_COLOR
    jne jmp_kill_player

    ; check top right corner
    move_draw_right P_SPRITE_SIZE + 1
    call set_draw_di
    cmp byte ptr es:[di], BACKGROUND_COLOR
    jne jmp_kill_player

    ; check bottom right corner
    move_draw_down P_SPRITE_SIZE + 1
    call set_draw_di
    cmp byte ptr es:[di], BACKGROUND_COLOR
    jne jmp_kill_player

    ; check bottom left corner
    move_draw_left P_SPRITE_SIZE + 1
    call set_draw_di
    cmp byte ptr es:[di], BACKGROUND_COLOR
    jne jmp_kill_player

    ret
player_collision_check ENDP

draw_player_anim PROC
    inc PlayerAnimTime

    cmp PlayerYVelocity, -PLAYER_FLAP_ANIM_MIN_VELOCITY
    jl select_frame
    mov PlayerAnimTime, 0
    jmp player_anim_frame_b

    select_frame:

    cmp PlayerAnimTime, PLAYER_ANIM_FRAME_DURATION * 2
    jge player_anim_frame_a_reset
    cmp PlayerAnimTime, PLAYER_ANIM_FRAME_DURATION
    jge player_anim_frame_b
    jmp player_anim_frame_a

    player_anim_frame_a:
    set_draw_sprite PLAYER_FLAP_SPRITE
    jmp draw_player

    player_anim_frame_b:
    set_draw_sprite PLAYER_SPRITE
    jmp draw_player

    player_anim_frame_a_reset:
    sub PlayerAnimTime, PLAYER_ANIM_FRAME_DURATION * 2
    set_draw_sprite PLAYER_SPRITE
    jmp draw_player

    draw_player:
    call set_player_draw_rect
    call draw_sprite

    ret
draw_player_anim ENDP

update_player PROC
    call set_player_draw_rect
    call clear_rect

    call player_jump_check

    move_player SP_PLAYER_GRAVITY_SCALE

    call player_collision_check
    call player_out_of_bounds_check

    call draw_player_anim

    ret
update_player ENDP

;
;
;
;
; PIPES (HELPERS)
;
;
;
;

; declares a loop label that runs `PIPEPAIR_COUNT` times and sets up `dx` as the pipe index.
;
; * don't modify `cx` inside the loop.
;
; input:
; none.
pipepair_loop MACRO loop_label
    mov cx, PIPEPAIR_COUNT

    loop_label:

    mov dx, cx
    dec dx
ENDM

; input:
; `dx` -> pipepair index.
set_pipepair_si MACRO
    mov si, dx
    shl si, 1
ENDM

; input:
; `dx` -> pipepair index,
; `si` -> pipepair ptr.
;
; effects:
; `ax` -> ?,
; `bx` -> ?.
init_pipepair_xpos PROC
    push dx
    mov bx, dx
    mov ax, SP_PIPEPAIR_XDISTANCE + SP_PIPE_WIDTH
    mul bx
    pop dx

    mov [PipePairXPoses + si], ax

    ret
init_pipepair_xpos ENDP

; input:
; `dx` -> pipepair index,
; `si` -> pipepair ptr.
;
; effects:
; `ax` -> ?,
; `bx` -> ?.
init_pipepair_ypos PROC
    ; randomize `bx` with unique values
    add bx, dx
    add bx, PlayerYVelocity
    add bx, PlayerYPos

    ; constraint `bx` to `0..16`
    shl bx, 1
    and bx, 000Fh

    ; scale `bx` to `T_MIN_PIPE_HEIGHT..=T_MAX_PIPE_HEIGHT`
    mov al, T_MAX_PIPE_HEIGHT - T_MIN_PIPE_HEIGHT
    mul bl
    mov bx, ax
    shr bx, 4
    add bx, T_MIN_PIPE_HEIGHT

    mov [PipePairBottomHeights + si], bx

    ret
init_pipepair_ypos ENDP

; input:
; `dx` -> pipepair index,
; `si` -> pipepair ptr.
;
; effects:
; `ax` -> x-drawpos.
set_pipepair_xdrawpos MACRO
    mov ax, [PipePairXPoses + si]
    sar ax, 4 ; divide by 16 (subpixels -> pixels)
ENDM

; input:
; `dx` -> pipepair index,
; `si` -> pipepair ptr.
;
; effects:
; `ax` -> x-drawpos,
; `bx` -> y-drawpos.
set_bottom_pipe_drawpos MACRO
    set_pipepair_xdrawpos

    mov bx, P_SCREEN_HEIGHT - P_SPRITE_SIZE
ENDM

; input:
; `dx` -> pipepair index,
; `si` -> pipepair ptr.
;
; effects:
; `ax` -> x-drawpos,
; `bx` -> y-drawpos.
set_top_pipe_drawpos MACRO
    set_pipepair_xdrawpos

    mov bx, T_SCREEN_HEIGHT - T_PIPEPAIR_YDISTANCE - 1
    sub bx, [PipePairBottomHeights + si]
    shl bx, P_SPRITE_SIZE_LOG2
ENDM

; input:
; `dx` -> pipepair index,
; `si` -> pipepair ptr.
;
; effects:
; `cx` -> bottom pipe height.
set_bottom_pipe_height_cx MACRO
    mov cx, [PipePairBottomHeights + si]
ENDM

; input:
; `dx` -> pipepair index,
; `si` -> pipepair ptr.
;
; effects:
; `ax` -> ?,
; `cx` -> top pipe height.
set_top_pipe_height_cx MACRO
    mov cx, P_SCREEN_HEIGHT / P_SPRITE_SIZE - T_PIPEPAIR_YDISTANCE
    mov ax, [PipePairBottomHeights + si]
    sub cx, ax
ENDM

; draws and clears in proportion to the pipe speed.
;
; input:
; a set-up drawpos.
;
; effects:
; `bx` -> moved 1 tile up,
; `di` -> ?.
draw_pipe_row MACRO left_sprite, right_sprite
    push si

    set_draw_sprite left_sprite
    draw_sprite_pushed P_SPRITE_SIZE, P_SPRITE_SIZE

    move_draw_right P_SPRITE_SIZE

    move_draw_right P_SPRITE_SIZE + P_PIPE_CLEAR_OFFSET
    clear_rect_pushed P_PIPE_CLEAR_OFFSET, P_SPRITE_SIZE
    move_draw_left P_SPRITE_SIZE + P_PIPE_CLEAR_OFFSET

    set_draw_sprite right_sprite
    draw_sprite_pushed P_SPRITE_SIZE, P_SPRITE_SIZE

    move_draw_left P_SPRITE_SIZE
    move_drawpos_up P_SPRITE_SIZE

    pop si
ENDM

; draws and clears in proportion to the pipe speed.
;
; input:
; `dx` -> pipepair index,
; `si` -> pipepair ptr.
;
; effects:
; `ax` -> ?,
; `bx` -> ?,
; `cx` -> ?,
; `di` -> ?.
draw_bottom_pipe PROC
    set_bottom_pipe_drawpos

    set_bottom_pipe_height_cx
    dec cx
    loop_start draw_bottom_pipe_loop, draw_bottom_pipe_loop_end
    draw_pipe_row PIPE_L_SPRITE, PIPE_R_SPRITE
    loop_end draw_bottom_pipe_loop, draw_bottom_pipe_loop_end

    draw_pipe_row PIPE_L_TOP_SPRITE, PIPE_R_TOP_SPRITE

    ret
draw_bottom_pipe ENDP

; draws and clears in proportion to the pipe speed.
;
; input:
; `dx` -> pipepair index,
; `si` -> pipepair ptr.
;
; effects:
; `ax` -> ?,
; `bx` -> ?,
; `cx` -> ?,
; `di` -> ?.
draw_top_pipe PROC
    set_top_pipe_height_cx
    dec cx

    set_top_pipe_drawpos
    draw_pipe_row PIPE_L_BOTTOM_SPRITE, PIPE_R_BOTTOM_SPRITE

    loop_start draw_top_pipe_loop, draw_top_pipe_loop_end
    draw_pipe_row PIPE_L_SPRITE, PIPE_R_SPRITE
    loop_end draw_top_pipe_loop, draw_top_pipe_loop_end

    ret
draw_top_pipe ENDP

;
;
;
;
; PIPES
;
;
;
;

; effects:
; `ax` -> ?,
; `bx` -> ?,
; `dx` -> ?,
; `si` -> ?.
init_pipepairs PROC
    pipepair_loop init_pipepairs_loop

    set_pipepair_si
    call init_pipepair_ypos
    call init_pipepair_xpos

    loop init_pipepairs_loop

    ret
init_pipepairs ENDP

; draws and clears in proportion to the pipe speed.
;
; effects:
; `ax` -> ?,
; `bx` -> ?,
; `cx` -> ?,
; `dx` -> ?,
; `si` -> ?,
; `di` -> ?.
draw_pipes PROC
    pipepair_loop draw_pipes_loop

    push cx
    set_pipepair_si
    call draw_top_pipe
    call draw_bottom_pipe
    pop cx

    loop draw_pipes_loop

    ret
draw_pipes ENDP

; effects:
; `ax` -> ?,
; `bx` -> ?,
; `cx` -> ?,
; `dx` -> ?,
; `si` -> ?,
; `di` -> ?.
update_pipes PROC
    pipepair_loop update_pipes_loop
    set_pipepair_si
    
    add [PipePairXPoses + si], SP_PIPE_VELOCITY

    cmp [PipePairXPoses + si], -(SP_PIPE_WIDTH + 16)
    jg post_teleport_pipepair
    add [PipePairXPoses + si], (SP_PIPE_WIDTH + SP_PIPEPAIR_XDISTANCE) * PIPEPAIR_COUNT
    post_teleport_pipepair:

    loop update_pipes_loop

    call draw_pipes

    ret
update_pipes ENDP

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
    call update_player
    call update_pipes

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
    clear_screen BACKGROUND_COLOR

    mov PlayerYPos, SP_INITIAL_PLAYER_YPOS
    mov PlayerYVelocity, 0
    
    call init_pipepairs

    mov GameLoopUpdateFn, offset gameloop_wait_update

    jmp main_loop
jmp_gameloop_wait ENDP

gameloop_wait_update PROC
    call set_player_draw_rect
    set_draw_sprite PLAYER_SPRITE
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
; DEATH GAME-STATE
;
;
;
;

; * doesn't return, meant to be used with `jmp` and not `call`.
jmp_gameloop_death PROC
    mov PlayerYVelocity, -SP_DEATH_PLAYER_JUMP_VELOCITY

    mov GameLoopUpdateFn, offset gameloop_death_update

    jmp main_loop
jmp_gameloop_death ENDP

gameloop_death_update PROC
    call set_player_draw_rect
    call clear_rect
    move_player SP_DEATH_PLAYER_GRAVITY_SCALE
    call set_player_draw_rect
    set_draw_sprite PLAYER_DEAD_SPRITE
    call draw_sprite

    call draw_pipes

    cmp PlayerYPos, SP_SCREEN_HEIGHT
    jge jmp_gameloop_wait

    ret
gameloop_death_update ENDP

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

    clear_screen BACKGROUND_COLOR

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