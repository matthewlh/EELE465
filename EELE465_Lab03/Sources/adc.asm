;************************************************************** 
;* File Name    : 	adc.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-04
;* Description  : 	Contains subroutines for controlling the
;*					adc.
;*
;**************************************************************

; EQU statements


; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF adc_init 
            XDEF adc_data_0, adc_data_1
            
; import symbols
			XREF SUB_delay, SUB_delay_cnt
			XREF bus_read, bus_write, bus_addr, bus_data


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			adc_data_0:		DS.B	1	; upper 8 bits from ADC read
			adc_data_1:		DS.B	1	; lower 8 bits from ADC read  
			
; code section
MyCode:     SECTION

adc_init: 
