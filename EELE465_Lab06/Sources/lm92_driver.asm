;************************************************************** 
;* File Name    : 	rtc_driver.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-27
;* Description  : 	Contains subroutines talking to a DS1337
;*					Real Time Clock, using i2c_driver.asm
;*
;**************************************************************

; EQU statements

LM92_ADDR_W 		EQU $90 	; Slave address to write to LM92
LM92_ADDR_R 		EQU $91 	; Slave address to read from LM92

LM92_REG_TEMP		EQU	$00		; register address of the seconds register

; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF lm92_init, lm92_read_temp
            
; import symbols
			XREF i2c_init, i2c_start, i2c_stop, i2c_tx_byte, i2c_rx_byte
			            


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			Temp_Data_Raw:		DS.B	2

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

;************************************************************** 
;* Subroutine Name: lm92_read_temp  
;* Description: Read temperature from LM92 and converts to 
;*				degrees C. The result is returned in Accu A.
;* 
;* Registers Modified: Accu A
;* Entry Variables: None
;* Exit Variables: Accu A
;**************************************************************
lm92_read_temp:

			; start condition
			JSR		i2c_start
			
			; send rtc write addr
			LDA		#LM92_ADDR_W
			JSR 	i2c_tx_byte
			
			; send register address
			LDA		#LM92_REG_TEMP
			JSR 	i2c_tx_byte
			
			; stop condition
			JSR		i2c_stop
						

			; start condition
			JSR		i2c_start
			
			; send rtc read addr
			LDA		#LM92_ADDR_R
			JSR 	i2c_tx_byte
			
			; read byte
			LDA		#$01			; ack the byte			
			JSR		i2c_rx_byte	
			STA		Temp_Data_Raw+0
			
			; read byte
			LDA		#$00			; nack the byte			
			JSR		i2c_rx_byte	
			STA		Temp_Data_Raw+1
			
			; stop condition
			JSR		i2c_stop
			

			; divide by 16 to convert to degrees C
			LDHX	Temp_Data_Raw+0
			LDX		#$80
			LDA		Temp_Data_Raw+1
			
			DIV		; A <- (H:A)/(X)

			; done			
			RTS

;**************************************************************



