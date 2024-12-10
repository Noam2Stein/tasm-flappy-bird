.model small
.stack 100h

.data
    msg  db 'Hello, world!$', 0    ; Message to be printed

    RectX dw ?
    RectY dw ?
    RectWidth dw ?
    RectHeight dw ?
    RectColor db ?

.code

graphics_mode MACRO
                                mov           ah, 0       ; Function to set video mode
                                mov           al, 13h     ; Mode 13h (320x200, 256 colors)
                                int           10h         ; Call BIOS interrupt
ENDM

draw_rect MACRO x, y, width, height, color, label0
    mov bx, y

    label0:
    mov ax, bx
    mov dx, 320
    mul dx
    add ax, x
    mov di, ax

    mov al, color
    mov ah, color

    mov cx, width
    rep stosw

    inc bx
    mov dx, y
    add dx, height
    cmp bx, dx
    jne label0
ENDM

main proc
                  graphics_mode

    ; Set up registers for the screen memory
                  mov           ax, 0A000h      ; Load video memory segment into AX
                  mov           es, ax          ; Move AX into ES

                  mov           di, 0
                  mov           al, 0
                  mov           ah, 0
                  mov           cx, 32000
                  rep           stosw           ; Clear the screen by writing AX (two pixels per iteration)

        mov RectX, 30
        draw:

        draw_rect RectX, RectY, RectWidth, RectHeight, 0, loop_draw0

        inc RectX

        mov RectY, 30
        mov RectWidth, 100
        mov RectHeight, 100
        mov RectColor, 15
        draw_rect RectX, RectY, RectWidth, RectHeight, RectColor, loop_draw

        jmp draw
                  


    ; Wait for a key press to exit
                  mov           ah, 0           ; Wait for user input
                  int           16h             ; BIOS keyboard interrupt

    quit:         
    ; Switch back to text mode (mode 03h)
                  mov           ah, 0           ; Function to set video mode
                  mov           al, 03h         ; Mode 03h (80x25, 16 colors)
                  int           10h             ; Call BIOS interrupt

    ; Exit the program
                  mov           ah, 4Ch         ; Terminate the program
                  int           21h

main endp
end main