;***********************************************************
;*	This code will hopefully run an LCD and display my name.
;*
;*	 Authors: Joseph Serra, Darren Mai
;*	   Date: 1/30/2025
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register is required for LCD Driver

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
		rcall CLEAR ; clears garbage values

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
		rjmp MAIN			; jump back to main and create an infinite
								; while loop.  Generally, every main program is an
								; infinite while loop, never let the main program
								; just run off

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
; Func: DISPLAY
; Desc: Macro to call custom CLEAR subroutine as well as LCDWrite
;-----------------------------------------------------------
DISPLAY:
		rcall CLEAR
		rcall LCDWrite
		ret


;-----------------------------------------------------------
; Func: COPY_LOOP
; Desc: Copies from program memory to the memory pointed to by Y.
;-----------------------------------------------------------
COPY_LOOP:
		lpm ; loads the byte pointed to in Z register into r0
		tst r0 ; sets the flag if the byte in r0 is equal to 0 or negative
		breq END_COPY ; checks the flag, if set, then end copy

		st Y+, r0 ; stores r0 in y, then increment y
		adiw ZL, 1 ; increments ZL pointer
		RJMP COPY_LOOP ; repeat until 0

;-----------------------------------------------------------
; Func: END_COPY
; Desc: COPY_LOOP helper function
;-----------------------------------------------------------
END_COPY:							; Begin a function with a label
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: CLEAR
; Desc: Clears the screen, then copies back over our strings
;-----------------------------------------------------------
CLEAR:
		rcall LCDClr ; clear our LCD to get rid of any stray characters
		ldi ZL, low(STRING_ONE * 2) ; load the first 8 bits of our string_one ptr into ZL (r30)
		ldi ZH, high(STRING_ONE * 2) ; load the last 8 bits of our string_one ptr into ZH (r31)

		ldi YL, low(0x0100) ; load the first 8 bits of our SRAM upper 16 character ptr into YL (r28)
		ldi YH, high(0x0100) ; load the last 8 bits of our SRAM upper 16 character ptr into YL (r29)
		rcall COPY_LOOP ; call copy subroutine

		ldi ZL, low(STRING_TWO * 2) ; load the first 8 bits of our string_two ptr into ZL (r30)
		ldi ZH, high(STRING_TWO * 2) ; load the last 8 bits of our string_two ptr into ZH (r31)

		ldi YL, low(0x0110) ; load the first 8 bits of our SRAM lower 16 character ptr into YL (r28)
		ldi YH, high(0x0110) ; load the last 8 bits of our SRAM lower 16 character ptr into YL (r29)
		rcall COPY_LOOP ; call copy subroutine
		ret


;-----------------------------------------------------------
; Func: SCROLL and SHIFT_LOOP
; Desc: a function to shift the string on the LCD
;-----------------------------------------------------------
SCROLL:                          
    ; step 1: store last character of line 2 (0x011F)
    ldi ZL, low(0x011F)           
    ldi ZH, high(0x011F)
    ld mpr, Z                   ; store last character in mpr BEFORE shifting
	push mpr					; saving our last character value in the stack

    ; step 2: initialize pointers for shifting
    ldi YL, low(0x0120)           ; start ONE PAST last char (Y)
    ldi YH, high(0x0120)

    ; step 3: shift all characters right by 1 (going backwards)
	ldi mpr, 32
	SHIFT_LOOP:
		push mpr					; save our counter value
		ld mpr, -Z                   ; pre-decrement Z, then load
		st -Y, mpr					; shifting our value
		pop mpr                   ; pre-decrement Y, then store
		dec mpr                      ; decrement counter
		brne SHIFT_LOOP               ; repeat until all 32 characters are shifted

		; step 4: restore the saved last character to the first position (0x0100)
		ldi YL, low(0x0100)            ; set Y pointer to first char
		ldi YH, high(0x0100)
		pop mpr							; grab our last character value
		st Y, mpr                      ; store saved last character

		; step 5: wait to create scrolling effect
		rcall LCDWrite
		ldi waitcnt, WTime
		rcall wait
		ret





;***********************************************************
;*	Stored Program Data
;***********************************************************
STRING_ONE:
.DB	"Joseph Serra ", 0 ; Declaring data in ProgMem
STRING_TWO:
.DB "Darren Mai ", 0

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
