;************************************************************** 
;* File Name    : 	i2c_driver.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-25
;* Description  : 	Contains subroutines for a bit-banging 
;*					software I2C driver, based on AN1820.
;*
;**************************************************************

; EQU statements


; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF i2c_init
            ;XDEF 
            
; import symbols
			XREF SUB_delay, SUB_delay_cnt
			XREF bus_read, bus_write, bus_addr, bus_data


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			
; code section
MyCode:     SECTION

;************************************************************** 
;* Subroutine Name: i2c_init  
;* Description: Initilizes the software I2C driver.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
i2c_init: 


			RTS

;**************************************************************
