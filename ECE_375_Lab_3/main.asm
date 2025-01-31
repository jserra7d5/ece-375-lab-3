;***********************************************************
;*	This code will hopefully run an LCD and display my name.
;*
;*	 Author: Joseph Serra
;*	   Date: 1/30/2025
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register is required for LCD Driver
.def	mpr2 = r24

.def	waitcnt = r17				; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter

.equ	WTime = 25				; Time to wait in wait loop
.equ clear_button = 4 ; clear screen button input bit
.equ display_button = 5 ; display button input bit
.equ scroll_button = 7 ; scroll button input bit

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp INIT				; Reset interrupt

.org	$0056					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:							; The initialization routine
		; initialize our stack pointer
		ldi mpr, low(RAMEND)
		out SPL, mpr
		ldi mpr, high(RAMEND)
		out SPH, mpr

		; initialize Port D for input
		ldi mpr, $00
		out DDRD, mpr
		ldi mpr, $FF
		out PORTD, mpr

		; Initialize LCD Display
		rcall LCDInit
		rcall CLEAR


		; NOTE that there is no RET or RJMP from INIT,
		; this is because the next instruction executed is the
		; first instruction of the main program

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:							; The Main program
		; first lets grab our inputs
		in mpr, PIND
		andi mpr, (1<<clear_button | 1<<display_button | 1<<scroll_button)

		; check if our clear button is pressed, if so, clear the screen
		sbrs mpr, clear_button
		rcall CLEAR

		; check if our display button is pressed, if so, display the lines
		sbrs mpr, display_button
		rcall DISPLAY

		; check if our scroll button is pressed, if so, call the scroll subroutine
		sbrs mpr, scroll_button
		rcall SCROLL
		rjmp	MAIN			; jump back to main and create an infinite
								; while loop.  Generally, every main program is an
								; infinite while loop, never let the main program
								; just run off

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
FUNC:							; Begin a function with a label
		; Save variables by pushing them to the stack

		; Execute the function here

		; Restore variables by popping them from the stack,
		; in reverse order

		ret						; End a function with RET


;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------



;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly
;		waitcnt*10ms.  Just initialize wait for the specific amount
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			(((((3*ilcnt)-1+4)*olcnt)-1+4)*waitcnt)-1+16
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait
		brne	Loop			; Continue Wait loop

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine

;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
DISPLAY:
		rcall LCDClr
		ldi ZL, low(STRING_ONE * 2)
		ldi ZH, high(STRING_ONE * 2)

		ldi YL, low(0x0100)
		ldi YH, high(0x0100)
		rcall COPY_LOOP

		ldi ZL, low(STRING_TWO * 2)
		ldi ZH, high(STRING_TWO * 2)

		ldi YL, low(0x0110)
		ldi YH, high(0x0110)
		rcall COPY_LOOP
		rcall LCDWrite
		ret


;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
COPY_LOOP:
		lpm
		tst r0
		breq END_COPY

		st Y+, r0
		adiw ZL, 1
		RJMP COPY_LOOP

;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
END_COPY:							; Begin a function with a label
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
CLEAR:
		rcall LCDClr
		ldi ZL, low(STRING_ONE * 2)
		ldi ZH, high(STRING_ONE * 2)

		ldi YL, low(0x0100)
		ldi YH, high(0x0100)
		rcall COPY_LOOP

		ldi ZL, low(STRING_TWO * 2)
		ldi ZH, high(STRING_TWO * 2)

		ldi YL, low(0x0110)
		ldi YH, high(0x0110)
		rcall COPY_LOOP
		ret


SCROLL:                          ; begin function with a label
    ; step 1: store last character of line 2 (0x011F)
    ldi ZL, low(0x011F)           
    ldi ZH, high(0x011F)
    ld mpr, Z                    ; store last character in mpr BEFORE shifting

    ; step 2: initialize pointers for shifting
    ldi YL, low(0x0120)           ; start ONE PAST last char (Y)
    ldi YH, high(0x0120)

    ; step 3: shift all characters right by 1 (going backwards)
    ldi mpr2, 32                  ; loop counter (32 shifts)

SHIFT_LOOP:
    ld mpr2, -Z                   ; pre-decrement Z, then load
    st -Y, mpr2                   ; pre-decrement Y, then store
    dec mpr2                      ; decrement counter
    brne SHIFT_LOOP               ; repeat until all 32 characters are shifted

    ; step 4: restore the saved last character to the first position (0x0100)
    ldi YL, low(0x0100)            ; set Y pointer to first char
    ldi YH, high(0x0100)
    st Y, mpr                      ; store saved last character

    ; step 5: wait to create smooth scrolling effect
    rcall LCDWrite
    ldi waitcnt, WTime
    rcall wait
    ret





;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING_ONE:
.DB	"Hello World", 0 ; Declaring data in ProgMem
STRING_TWO:
.DB "I wanna Die", 0

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
