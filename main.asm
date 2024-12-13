BLACK EQU 0
GREEN EQU 2
RED EQU 4
PINK EQU 5
ORANGE EQU 6
WHITE EQU 15
PURPLE EQU 34
YELLOW EQU 43
CYAN EQU 55

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

;                                | O                              | I                                       | S                                     | Z                                     | L                                      | J                                    | T                                    |
PieceColors                   db   YELLOW,                          CYAN,                                     RED,                                    GREEN,                                  ORANGE,                                  PINK,                                  PURPLE
PieceDrawJumps                dw   0, BLOCK_R, BLOCK_DL, BLOCK_R,   0, BLOCK_D, BLOCK_D, BLOCK_D,             BLOCK_D, BLOCK_R, BLOCK_DLL, BLOCK_R,   BLOCK_D, BLOCK_R, BLOCK_D, BLOCK_R,     0, BLOCK_D, BLOCK_D, BLOCK_R,            BLOCK_R, BLOCK_D, BLOCK_DL, BLOCK_R,   BLOCK_DL, BLOCK_R, BLOCK_R, BLOCK_DL
PieceDrawJumps90DegClockwise  dw   0, BLOCK_R, BLOCK_DL, BLOCK_R,   BLOCK_DDDLL, BLOCK_R, BLOCK_R, BLOCK_R,   0, BLOCK_D, BLOCK_R, BLOCK_D,           BLOCK_R, BLOCK_DL, BLOCK_R, BLOCK_DL,   BLOCK_DL, BLOCK_R, BLOCK_R, BLOCK_DLL,   BLOCK_DL, BLOCK_D, BLOCK_R, BLOCK_R,   0, BLOCK_DL, BLOCK_R, BLOCK_D
PieceDrawJumps180Deg          dw   0, BLOCK_R, BLOCK_DL, BLOCK_R,   0, BLOCK_D, BLOCK_D, BLOCK_D,             BLOCK_D, BLOCK_R, BLOCK_DLL, BLOCK_R,   BLOCK_D, BLOCK_R, BLOCK_D, BLOCK_R,     0, BLOCK_R, BLOCK_D, BLOCK_D,            0, BLOCK_R, BLOCK_DL, BLOCK_D,         BLOCK_D, BLOCK_DL, BLOCK_R, BLOCK_R
PieceDrawJumps270DegClockwise dw   0, BLOCK_R, BLOCK_DL, BLOCK_R,   BLOCK_DDDLL, BLOCK_R, BLOCK_R, BLOCK_R,   0, BLOCK_D, BLOCK_R, BLOCK_D,           BLOCK_R, BLOCK_DL, BLOCK_R, BLOCK_DL,   BLOCK_DR, BLOCK_DLL, BLOCK_R, BLOCK_R,   BLOCK_DL, BLOCK_R, BLOCK_R, BLOCK_D,   0, BLOCK_D, BLOCK_R, BLOCK_DL

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

draw_block MACRO
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

    add di, 320 - 7
    stosw
    stosw
    stosw
    stosb

    add di, 320 - 7
    stosw
    stosw
    stosw
    stosb

    add di, 320 - 7
    stosw
    stosw
    stosw
    stosb

    add di, 320 - 7
    stosw
    stosw
    stosw
    stosb

    sub di, 320 * 6 + 7
ENDM

clear_block MACRO
    mov ah, al

    stosw
    stosw
    stosw
    stosw

    add di, 320 - 8
    stosw
    stosw
    stosw
    stosw

    add di, 320 - 8
    stosw
    stosw
    stosw
    stosw

    add di, 320 - 8
    stosw
    stosw
    stosw
    stosw

    add di, 320 - 8
    stosw
    stosw
    stosw
    stosw

    add di, 320 - 8
    stosw
    stosw
    stosw
    stosw

    add di, 320 - 8
    stosw
    stosw
    stosw
    stosw

    sub di, 320 * 6 + 8
ENDM

draw_piece MACRO
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
    draw_block
    add si, 2
    add di, [si]
    draw_block
    add si, 2
    add di, [si]
    draw_block
    add si, 2
    add di, [si]
    draw_block
ENDM

clear_piece MACRO
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
    clear_block
    add si, 2
    add di, [si]
    clear_block
    add si, 2
    add di, [si]
    clear_block
    add si, 2
    add di, [si]
    clear_block
ENDM



;
;
; Gameplay
;
;

rotate_clockwise MACRO
    add ActivePieceRot, 1
    mov al, ActivePieceRot
    mov ah, 4
    div ah
    mov ActivePieceRot, ah
ENDM
rotate_counter_clockwise MACRO
    add ActivePieceRot, 3
    mov al, ActivePieceRot
    mov ah, 4
    div ah
    mov ActivePieceRot, ah
ENDM



;
;
; Main
;
;

main proc
    setup_data_segment
    setup_graphics_mode
    setup_draw_es

    mov al, BLACK
    clear_screen

    mov ActivePiece, PIECE_S
    mov ActivePiecePos, 320 * 8 * 8 + 40
    mov ActivePieceRot, 0
    draw_piece

    funny:
    ; Wait for a key press to exit
    mov ah, 0           ; Wait for user input
    int 16h             ; BIOS keyboard interrupt

    mov al, BLACK
    clear_piece
    rotate_clockwise
    draw_piece

    jmp funny

    quit
main endp
end main