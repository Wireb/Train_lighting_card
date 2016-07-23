;#############################################################################################################################################
;#Copyright (c) 2015 Peter Shabino
;#
;#Permission is hereby granted, free of charge, to any person obtaining a copy of this hardware, software, and associated documentation files
;#(the "Product"), to deal in the Product without restriction, including without limitation the rights to use, copy, modify, merge, publish,
;#distribute, sublicense, and/or sell copies of the Product, and to permit persons to whom the Product is furnished to do so, subject to the
;#following conditions:
;#
;#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Product.
;#
;#THE PRODUCT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;#MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
;#FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
;#WITH THE PRODUCT OR THE USE OR OTHER DEALINGS IN THE PRODUCT.
;#############################################################################################################################################

; This is the Train lighting micro code
; 04DEC15 V00.00 PJS New
; 10JUN16 V00.01 PJS Added support for flashers, turn signal blinking, state inputs and started eeprom support
; 15JUL16 V00.02 PJS Started EEPROM support. 

VerHigh	    equ	    0x00
VerLow	    equ	    0x02
#define	CODE_VER_STRING "Peter Shabino 15JUL2016 Train Lighting V00.02" ;Just in ROM

;****************************************************************************************
; port list
; Vss(20)[3]		GND
; Vdd(1)[2]		+V
; RA0(19)[4]		ICSPDAT, Headlight L
; RA1(18)[5]		ICSPCLK, Headlight R
; RA2(17)		Turn FL
; RA3(4)[1]		Vpp/#MCLR, button
; RA4(3)		input
; RA5(2)		input
; RB4(13)		backup L
; RB5(12)		backup R
; RB6(11)		stop L
; RB7(10)		flasher A
; RC0(16)		turn FR
; RC1(15)		turn RL
; RC2(14)		turn RR
; RC3(7)		stop C
; RC4(6)		input
; RC5(5)		input
; RC6(8)		stop R
; RC7(9)		flasher B
;****************************************************************************************

;-----------------------------------------------------------------------------------------------------------
; compiler configuration
;-----------------------------------------------------------------------------------------------------------
	; set processor type and output file type (intel merged hex (.hex))
	list	f=INHX8M
	
	; PIC16F18344 Configuration Bit Settings
	#include "p16F18344.inc"
	; CONFIG1
	; __config 0xFFEC
	 __CONFIG _CONFIG1, _FEXTOSC_OFF & _RSTOSC_HFINT1 & _CLKOUTEN_OFF & _CSWEN_ON & _FCMEN_ON
	; CONFIG2
	; __config 0xF7D0
	 __CONFIG _CONFIG2, _MCLRE_OFF & _PWRTE_ON & _WDTE_OFF & _LPBOREN_ON & _BOREN_ON & _BORV_LOW & _PPS1WAY_OFF & _STVREN_ON & _DEBUG_OFF
	; CONFIG3
	; __config 0x3
	 __CONFIG _CONFIG3, _WRT_OFF & _LVP_OFF
	; CONFIG4
	; __config 0x3
	 __CONFIG _CONFIG4, _CP_OFF & _CPD_OFF

;-----------------------------------------------------------------------------------------------------------
;constants
;-----------------------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------------------
;variables (0x20 - 0x6F only), 0x0A0-0x0BF
;-----------------------------------------------------------------------------------------------------------
; bank 0  
temp		equ	    0x20
last_state	equ	    0x21
blink_count	equ	    0x22
eeprom_update	equ	    0x23
button_bounce	equ	    0x24
init		equ	    0x25

state_regs_H	equ	    0x00
state_regs_L	equ	    0x30
;		equ	    0x31
;		equ	    0x32
;		equ	    0x33
;		equ	    0x34
;		equ	    0x35
;		equ	    0x36
;		equ	    0x37
;		equ	    0x38
;		equ	    0x39
;		equ	    0x3A
;		equ	    0x3B
;		equ	    0x3C
;		equ	    0x3D
;		equ	    0x3E
;		equ	    0x3F


	
;-----------------------------------------------------------------------------------------------------------
;global variables (0x70 - 0x7F only)
;-----------------------------------------------------------------------------------------------------------
global_temp	equ	    0x70
	
;-----------------------------------------------------------------------------------------------------------
;EEPROM data
;   bit 0 = headlights
;   bit 1 = running lights
;   bit 2 = left turn
;   bit 3 = right turn
;   bit 4 = backup
;   bit 5 = stop lights
;   bit 6 = flashers
; byte order input signals inverted. So all open would be the last value (right).
;-----------------------------------------------------------------------------------------------------------
	org     0xF000
	de	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x40,0x20,0x10,0x08,0x04,0x03,0xFF

	
	
;-----------------------------------------------------------------------------------------------------------
;put the following at address 0000h (starting vector)
;-----------------------------------------------------------------------------------------------------------
	org     0000h
	goto	START		    ; normal boot / reset vector

;-----------------------------------------------------------------------------------------------------------
;put the following at address 0004h (IRQ vector)
;-----------------------------------------------------------------------------------------------------------
	org     0004h
	goto	IRQ		    ; catch all IRQ not used
	
	
	
;-----------------------------------------------------------------------------------------------------------
;interrup routine
;-----------------------------------------------------------------------------------------------------------
IRQ	
        ; pic automaticly stores all critical data and disables the GIE
        movlb   d'00'		    ; make sure we are in bank 0
	
	; todo if needed add check for multiple irqs here. 
	
	bcf	PIR0, TMR0IF	    ; clear the irq 
	
	incf	blink_count, F	    ; inc the blinker state
	
	; button debounce code
	bcf	STATUS, C
	rrf	button_bounce, F
	
	; eeprom update trigger
	movf	eeprom_update, W
	btfsc	STATUS, Z
	goto	EEPROM_NO_UPDATE
	xorlw	0x01
	btfsc	STATUS, Z
	goto	EEPROM_UPDATE
	decf	eeprom_update, F
	goto	EEPROM_NO_UPDATE

EEPROM_UPDATE
	;-----------------
        ; change banks
        ;-----------------
        movlb   d'17'
        ;-----------------
	; set address to the start of the eeprom space
	movlw	0x70
	movwf	NVMADRH
	clrf	NVMADRL
	; set FSR0 to the start of the registers
	movlw	state_regs_H
	movwf	FSR0H
	movlw	state_regs_L
	movwf	FSR0L
	
	movlw	0x10
	movwf	global_temp
WRITE_EEPROM_DATA_LOOP	
	movf	INDF0, W
	movwf	NVMDATL
	movlw	0x44	    ; pick EEPROM space and set WREN bit
	movwf	NVMCON1
	movlw	0x55	    ; required unlock seq
	movwf	NVMCON2
	movlw	0xAA	    ; required unlock seq
	movwf	NVMCON2
	bsf	NVMCON1, WR ; start the write
WRITE_EEPROM_LOOP
	btfsc	NVMCON1, WR ; check if write is done
	goto	WRITE_EEPROM_LOOP

	; update to the next location
	incf	NVMADRL, F
	incf	FSR0L, F
	
	; check if it is done yet
	decfsz	global_temp, F
	goto	WRITE_EEPROM_DATA_LOOP
	
	
	;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------	
	
	
	; clear the flag to indicate that no updates have happened. 
	clrf	eeprom_update
EEPROM_NO_UPDATE
	

	
	btfss	INDF0, 2
	goto	flashers_left_irq_done	
	btfss	blink_count, 4
	goto	flashers_left_irq_other
	;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------	
	bsf	TRISA, 2    ; turn FL
	bsf	TRISC, 1    ; turn RL
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------
	goto	flashers_left_irq_done	
flashers_left_irq_other
	;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------	
	bcf	TRISA, 2    ; turn FL
	bcf	TRISC, 1    ; turn RL
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------	
flashers_left_irq_done	

	
	btfss	INDF0, 3
	goto	flashers_right_irq_done	
	btfss	blink_count, 4
	goto	flashers_right_irq_other
	;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------	
	bsf	TRISC, 2    ; turn RR
	bsf	TRISC, 0    ; turn FR
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------
	goto	flashers_right_irq_done	
flashers_right_irq_other
	;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------	
	bcf	TRISC, 2    ; turn RR
	bcf	TRISC, 0    ; turn FR
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------	
flashers_right_irq_done
	
	
	btfss	INDF0, 6
	goto	flashers_irq_done
	bcf	PORTB, 7
	bcf	PORTC, 7
	btfss	blink_count, 2
	goto	flasher_irq_2
	btfsc	blink_count, 0
	bsf	PORTC, 7
	goto	flashers_irq_done
flasher_irq_2
	btfsc	blink_count, 0
	bsf	PORTB, 7	
flashers_irq_done		
	
        retfie                      ; return from IRQ

;-----------------------------------------------------------------------------------------------------------
; Start main code here
;-----------------------------------------------------------------------------------------------------------
START
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------
	movlw	0x03
	movwf	PORTA
	clrf	PORTB
	clrf	PORTC
	

	clrf	init
	clrf	blink_count
	clrf	FSR0L
	clrf	eeprom_update
	movlw	0xFF
	movwf	button_bounce
	movwf	last_state

	movlw	0x04	    ; enable timer no dividers 
	movwf	T2CON
	movlw	0xFF	    ; recycle every 256 counts
	movwf	PR2
	
	clrf	TMR0L	    ; timer 0 
	movlw	0xFF	
	movwf	TMR0H
	movlw	0x90	    ; LFintosc clock source, no sync, 1:1 prescale
	movwf	T0CON1
	movlw	0x87	    ; timer 0 on, 8 bit, 1:8 post scale
	movwf	T0CON0

	; set up ints
	bcf	PIR0, TMR0IF
	
	
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------		
	movlw	0xFF 	    ; make IO inputs (high) or output (low) 
	movwf	TRISA	    ; 5,4,3 inputs 2 turn FL, 1 headlight R, 0 headlight L 
	movlw	0x7F
	movwf	TRISB	    ; 7 flasher A, 6 stop L, 5 backup R, 4 backup L
	movwf	TRISC	    ; 7 flasher B, 6 stop R, 5,6 inputs, 3 stop C, 2 turn RR, 1 turn RL, 0 turn FR
	
	; set up ints
	bsf	PIE0, TMR0IE

        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'03'
        ;-----------------		
	clrf	ANSELA
	clrf	ANSELB
	clrf	ANSELC
	
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'28'
        ;-----------------
	; unlock the perhiperal select
	movlw	0x55
	movwf	PPSLOCK
	movlw	0xAA
	movwf	PPSLOCK
	bcf	PPSLOCK,PPSLOCKED
	
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'29'
        ;-----------------
	movlw	0x0C	    ; set pins to CCP1
	
	movwf	RC6PPS	    ; stop R
	movwf	RC3PPS	    ; stop C
	movwf	RB6PPS	    ; stop L

;	movwf	RA0PPS	    ; headlight 
;	movwf	RA1PPS	    ; headlight 
	
	movlw	0x0D	    ; set pins to CCP2
	movwf	RA2PPS	    ; turn FL
	movwf	RC0PPS	    ; turn FR
	movwf	RC1PPS	    ; turn RL
	movwf	RC2PPS	    ; turn RR
	
	
	movlw	0x0E	    ; set pins to CCP1
	movwf	RB4PPS	    ; backup L
	movwf	RB5PPS	    ; backup R
	
	;-----------------
        ; change banks
        ;-----------------
        movlb   d'28'
        ;-----------------
	bsf PPSLOCK,PPSLOCKED
	
	
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'5'
        ;-----------------
	movlw	0x9F	    ; set up CCP1 to PWM and on
	movwf	CCP1CON
	movlw	0xFF
	movwf	CCPR1L
	movlw	0x20
	movwf	CCPR1H
	
	movlw	0x9F	    ; set up CCP2 to PWM and on
	movwf	CCP2CON
	movlw	0xFF
	movwf	CCPR2L
	movlw	0x20
	movwf	CCPR2H

        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'6'
        ;-----------------
	movlw	0x9F	    ; set up CCP3 to PWM and on
	movwf	CCP3CON
	movlw	0xFF
	movwf	CCPR3L
	movlw	0x20
	movwf	CCPR3H
	
	movlw	0x9F	    ; set up CCP4 to PWM and on
	movwf	CCP4CON
	movlw	0xFF
	movwf	CCPR4L
	movlw	0xFF
	movwf	CCPR4H
	
	
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'0'
        ;-----------------
	
		
	; Point FSR0 to the start of the data registers
	movlw	state_regs_H
	movwf	FSR0H 
	movlw	state_regs_L 
	movwf	FSR0L

	; Point FSR1 to the start of the eeprom space
	movlw	0x70
	movwf	FSR1H 
	clrf	FSR1L
	
	; loop though and copy memory over
	movlw	0x10
	movwf	temp
EEPROM_READ_LOOP	
	moviw	INDF1++
	movwi	INDF0++
	decfsz	temp, F
	goto	EEPROM_READ_LOOP	
	
	; bit 0 = headlights
	; bit 1 = running lights
	; bit 2 = left turn
	; bit 3 = right turn
	; bit 4 = backup
	; bit 5 = stop lights
	; bit 6 = flashers

	; enable ints
	movlw	0xC0
	movwf	INTCON
	
	
MAINLOOP
		
	; grab the current input states
	
	movlw	state_regs_L 
	movwf	temp
	btfsc	PORTC, 4
	bsf	temp, 0
	btfsc	PORTC, 5
	bsf	temp, 1
	btfsc	PORTA, 4
	bsf	temp, 2
	btfsc	PORTA, 5
	bsf	temp, 3
	
	movf	temp, W
	movwf	FSR0L
	

	; fix to update the leds at power up 
	movf	init, W
	btfss	STATUS, Z
	goto	NOT_INIT
	movlw	0x01
	movwf	init
	goto	UPDATE_STATES
NOT_INIT	

	
	; check if button is pressed
	btfsc	PORTA, 3		; check if button pressed
	goto	button_done
	movf	button_bounce, W	; check if previous button press has debounced yet
	btfss	STATUS, Z 
	goto	button_done_pressed
	incf	INDF0, F		; increment the led state for this config
	movlw	0xFF
	movwf	eeprom_update		; start/restart the timer for the EEPROM update due to led state change 
button_done_pressed
	bsf	button_bounce, 2	; start/restart the time for the button debounce
button_done	
	
	movf	last_state, W
	xorwf	INDF0, W
	btfsc	STATUS, Z
	goto	MAINLOOP

UPDATE_STATES	
	movf	INDF0, W
	movwf	last_state
	
	; turn off all leds
	bcf	PORTB, 7    ; flasher
	bcf	PORTC, 7    ; flasher
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------	
	movlw	0xFF
	movwf	TRISA	    ; 5,4,3 inputs 2 turn FL, 1 headlight R, 0 headlight L 
	movlw	0x7F
	movwf	TRISB	    ; 7 flasher A, 6 stop L, 5 backup R, 4 backup L
	movwf	TRISC	    ; 7 flasher B, 6 stop R, 5,6 inputs, 3 stop C, 2 turn RR, 1 turn RL, 0 turn FR	
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------	
	
	
	btfss	INDF0, 0
	goto	headlight_done
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------	
	bcf	TRISA, 0    ; headlight L
	bcf	TRISA, 1    ; headlight R
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------	
headlight_done	

	
	btfss	INDF0, 1
	goto	run_done
	;-----------------
        ; change banks
        ;-----------------
        movlb   d'5'
        ;-----------------
	movlw	0x20	    ; stop pwm channel
	movwf	CCPR1H
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------	
	bcf	TRISA, 2    ; turn FL
	bcf	TRISB, 6    ; stop L
	bcf	TRISC, 6    ; stop r
	bcf	TRISC, 2    ; turn RR
	bcf	TRISC, 1    ; turn RL
	bcf	TRISC, 0    ; turn FR
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------	
run_done	
	

	btfss	INDF0, 4
	goto	backup_done
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------	
	bcf	TRISB, 4    ; backup L
	bcf	TRISB, 5    ; backup r
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------	
backup_done	
	
	
	
	btfss	INDF0, 5
	goto	stop_done
	;-----------------
        ; change banks
        ;-----------------
        movlb   d'5'
        ;-----------------
	movlw	0x80	    ; stop pwm channel
	movwf	CCPR1H
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'01'
        ;-----------------	
	bcf	TRISB, 6    ; stop L
	bcf	TRISC, 6    ; stop r
	bcf	TRISC, 3    ; stop c
        ;-----------------
        ; change banks
        ;-----------------
        movlb   d'00'
        ;-----------------	
stop_done	

	
	
	goto	MAINLOOP
	
	
;This major block of code is a catchall loop if things go bad just stop.
;-----------------------------------------------
ENDLOOP
        goto    ENDLOOP

; ---------------- Function calls ----------------------


	
	de  CODE_VER_STRING         ; put the description string in the ROM	
	end



