BLACK EQU 0
GREEN EQU 2
RED EQU 4
PINK EQU 5
ORANGE EQU 6
WHITE EQU 15
PURPLE EQU 34
YELLOW EQU 43
CYAN EQU 55

KEY_RIGHT    EQU 4Dh
KEY_LEFT     EQU 4Bh
KEY_UP       EQU 48h
KEY_DOWN     EQU 50h
KEY_D        EQU 20h
KEY_A        EQU 1Eh
KEY_W        EQU 11h
KEY_S        EQU 1Fh
KEY_ESC      EQU 1

PIECE_O EQU 0
PIECE_I EQU 1
PIECE_S EQU 2
PIECE_Z EQU 3
PIECE_L EQU 4
PIECE_J EQU 5
PIECE_T EQU 6
PIECE_COUNT EQU 7

BLOCK_R EQU 8
BLOCK_L EQU -8
BLOCK_D EQU 320 * 8
BLOCK_DR EQU BLOCK_D + BLOCK_R
BLOCK_DL EQU BLOCK_D + BLOCK_L
BLOCK_DLL EQU BLOCK_D + BLOCK_L * 2
BLOCK_DDDLL EQU BLOCK_D * 3 + BLOCK_L * 2

.model small
.stack 100h

.data

;
;
; Imutable
;
;

;                                | O                              | I                                       | S                                     | Z                                     | L                                      | J                                    | T                                    |
PieceColors                   db   YELLOW,                          CYAN,                                     RED,                                    GREEN,                                  ORANGE,                                  PINK,                                  PURPLE
PieceDrawJumps                dw   0, BLOCK_R, BLOCK_DL, BLOCK_R,   0, BLOCK_D, BLOCK_D, BLOCK_D,             BLOCK_D, BLOCK_R, BLOCK_DLL, BLOCK_R,   BLOCK_D, BLOCK_R, BLOCK_D, BLOCK_R,     0, BLOCK_D, BLOCK_D, BLOCK_R,            BLOCK_R, BLOCK_D, BLOCK_DL, BLOCK_R,   BLOCK_DL, BLOCK_R, BLOCK_R, BLOCK_DL
PieceDrawJumps90DegClockwise  dw   0, BLOCK_R, BLOCK_DL, BLOCK_R,   BLOCK_DDDLL, BLOCK_R, BLOCK_R, BLOCK_R,   0, BLOCK_D, BLOCK_R, BLOCK_D,           BLOCK_R, BLOCK_DL, BLOCK_R, BLOCK_DL,   BLOCK_DL, BLOCK_R, BLOCK_R, BLOCK_DLL,   BLOCK_DL, BLOCK_D, BLOCK_R, BLOCK_R,   0, BLOCK_DL, BLOCK_R, BLOCK_D
PieceDrawJumps180Deg          dw   0, BLOCK_R, BLOCK_DL, BLOCK_R,   0, BLOCK_D, BLOCK_D, BLOCK_D,             BLOCK_D, BLOCK_R, BLOCK_DLL, BLOCK_R,   BLOCK_D, BLOCK_R, BLOCK_D, BLOCK_R,     0, BLOCK_R, BLOCK_D, BLOCK_D,            0, BLOCK_R, BLOCK_DL, BLOCK_D,         BLOCK_D, BLOCK_DL, BLOCK_R, BLOCK_R
PieceDrawJumps270DegClockwise dw   0, BLOCK_R, BLOCK_DL, BLOCK_R,   BLOCK_DDDLL, BLOCK_R, BLOCK_R, BLOCK_R,   0, BLOCK_D, BLOCK_R, BLOCK_D,           BLOCK_R, BLOCK_DL, BLOCK_R, BLOCK_DL,   BLOCK_DR, BLOCK_DLL, BLOCK_R, BLOCK_R,   BLOCK_DL, BLOCK_R, BLOCK_R, BLOCK_D,   0, BLOCK_D, BLOCK_R, BLOCK_DL



;
;
; Mutable
;
;

;                HELD, NOT_HELD_OLD, PRESSED_DOWN
ButtonRight db   0,    0,            0
ButtonLeft  db   0,    0,            0
ButtonUp    db   0,    0,            0
ButtonDown  db   0,    0,            0

ActivePiece db ?
ActivePiecePos dw ?
ActivePieceRot db ?

.code

;
;
; Setup
;
;

setup_data_segment MACRO
    mov ax, @data
    mov ds, ax
ENDM

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

clear_screen MACRO
    mov ah, al
    mov di, 0
    mov cx, 320 * 200 / 2
    rep stosw
ENDM



;
;
; Sprites
;
;

draw_block PROC
    mov ah, al

    mov al, WHITE
    stosb
    mov al, ah
    stosw
    stosw
    stosw

    add di, 320 - 7
    stosb
    mov al, WHITE
    stosb
    stosb
    mov al, ah
    stosw
    stosw

    add di, 320 - 7
    stosb
    mov al, WHITE
    stosb
    mov al, ah
    stosw
    stosw
    stosb

    mov cx, 4

    draw_row:
    add di, 320 - 7
    stosw
    stosw
    stosw
    stosb

    loop draw_row

    sub di, 320 * 6 + 7

    ret
ENDP

clear_block PROC
    mov ah, al
    mov cx, 7

    clear_row:
    stosw
    stosw
    stosw
    stosw
    add di, 320 - 8

    loop clear_row

    sub di, 320 * 7 + 8

    ret
ENDP

draw_piece PROC
    mov di, ActivePiecePos

    mov al, ActivePieceRot
    mov ah, 0
    mov dx, 2 * 4 * PIECE_COUNT
    mul dx
    mov si, ax
    mov al, ActivePiece
    mov ah, 0
    mov dx, 2 * 4
    mul dx
    add si, ax
    mov dx, si

    lea si, PieceColors
    mov al, ActivePiece
    mov ah, 0
    add si, ax
    mov al, [si]

    lea si, PieceDrawJumps
    add si, dx
    add di, [si]
    call draw_block
    add si, 2
    add di, [si]
    call draw_block
    add si, 2
    add di, [si]
    call draw_block
    add si, 2
    add di, [si]
    call draw_block

    ret
ENDP

clear_piece PROC
    mov bl, al
    mov di, ActivePiecePos

    lea si, PieceDrawJumps
    mov al, ActivePieceRot
    mov ah, 0
    mov dx, 2 * 4 * PIECE_COUNT
    mul dx
    add si, ax
    mov al, ActivePiece
    mov ah, 0
    mov dx, 2 * 4
    mul dx
    add si, ax

    mov al, bl
    mov ah, bl

    add di, [si]
    call clear_block
    add si, 2
    add di, [si]
    call clear_block
    add si, 2
    add di, [si]
    call clear_block
    add si, 2
    add di, [si]
    call clear_block

    ret
ENDP



;
;
; Input
;
;

check_key_into_al MACRO key
    mov ah, 02h
    mov al, key
    int 16h
ENDM

update_button MACRO button, key0, key1
    mov al, button
    mov [button + 1], al

    not [button + 1]

    check_key_into_al key0
    mov button, al

    check_key_into_al key1
    or button, al

    mov al, button
    mov [button + 2], al
    mov al, [button + 1]
    and [button + 2], al
ENDM

update_buttons PROC
    update_button ButtonRight, KEY_RIGHT, KEY_D
    update_button ButtonLeft,  KEY_LEFT,  KEY_A
    update_button ButtonUp,    KEY_UP,    KEY_W
    update_button ButtonDown,  KEY_DOWN,  KEY_S

    ret
ENDP

cmp_button_to_0 MACRO button
    cmp button, 0
ENDM
cmp_button_down_to_0 MACRO button
    cmp [button + 2], 0
ENDM



;
;
; Gameplay
;
;

rotate_clockwise MACRO
    add ActivePieceRot, 1
    mov al, ActivePieceRot
    mov bl, 4
    div bl
    mov ActivePieceRot, ah
ENDM

rotate_counter_clockwise MACRO
    add ActivePieceRot, 3
    mov al, ActivePieceRot
    mov bl, 4
    div bl
    mov ActivePieceRot, ah
ENDM



;
;
; Main
;
;

game_start MACRO
    setup_data_segment
    setup_graphics_mode
    setup_draw_es

    mov al, BLACK
    clear_screen

    mov ActivePiece, PIECE_T
    mov ActivePiecePos, 320 * 8 * 8 + 40
    mov ActivePieceRot, 0
    call draw_piece
ENDM

game_update MACRO
    call update_buttons

    call clear_piece

    cmp_button_down_to_0 ButtonUp
    je after_rotation
    rotate_clockwise
    after_rotation:

    call draw_piece
ENDM

game_end MACRO
    quit
ENDM

main proc
    game_start

    update:
    game_update

    check_key_into_al KEY_ESC
    cmp al, 0
    je update

    game_end
main endp
end main