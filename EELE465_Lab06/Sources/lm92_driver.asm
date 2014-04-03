;************************************************************** 
;* File Name    : 	rtc_driver.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-27
;* Description  : 	Contains subroutines talking to a DS1337
;*					Real Time Clock, using i2c_driver.asm
;*
;**************************************************************

; EQU statements

LM92_ADDR_W 		EQU $80 	; Slave address to write to LM92
LM92_ADDR_R 		EQU $81 	; Slave address to read from LM92

LM92_REG_			EQU	$00		; register address of the seconds register

; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF lm92_init
            
; import symbols
			XREF i2c_init, i2c_start, i2c_stop, i2c_tx_byte, i2c_rx_byte
			            


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			
			Byte_counter:		DS.B	1

MY_CONST: SECTION
; Constant Values and Tables Section
			
			;str_date:			DC.B 	"Date is "	
			;str_date_length:	DC.B	8
			
			
; code section
MyCode:     SECTION

;************************************************************** 
;* Subroutine Name: lm92_init  
;* Description: Initilizes the LM92 digital temperature
;*				sensor driver.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
lm92_init:
			; nothing to see here			
			RTS

;**************************************************************
