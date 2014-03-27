;************************************************************** 
;* File Name    : 	rtc_driver.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-27
;* Description  : 	Contains subroutines talking to a DS1337
;*					Real Time Clock, using i2c_driver.asm
;*
;**************************************************************

; EQU statements

RTC_ADDR_W 	EQU $D0 	; Slave address to write to RTC
RTC_ADDR_R 	EQU $D1 	; Slave address to read from RTC

; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF rtc_init
            ;XDEF 
            
; import symbols
			XREF i2c_init, i2c_start, i2c_stop, i2c_tx_byte


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			;BitCounter:		DS.B	1		; Used to count bits in a Tx
			
; code section
MyCode:     SECTION

;************************************************************** 
;* Subroutine Name: rtc_init  
;* Description: Initilizes the RTC driver.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
rtc_init:

			; start condition
			JSR		i2c_start
			
			; send rtc read addr
			LDA		RTC_ADDR_R
			JSR 	i2c_tx_byte
			
			; send register addr
			LDA		#$0F
			JSR		i2c_tx_byte		

			; stop condition
			JSR		i2c_stop			

			RTS

;**************************************************************
