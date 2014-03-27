;************************************************************** 
;* File Name    : 	i2c_driver.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-25
;* Description  : 	Contains subroutines for a bit-banging 
;*					software I2C driver, based on AN1820.
;*
;**************************************************************

; EQU statements
SCL 		EQU 3 		;Serial clock
SDA 		EQU 2 		;Serial data

RTCADDR 	EQU $2C 	; Slave address of RTC

; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF i2c_init, i2c_start, i2c_stop, i2c_tx_byte
            ;XDEF 
            
; import symbols
			XREF SUB_delay, SUB_delay_cnt
			XREF bus_read, bus_write, bus_addr, bus_data


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			BitCounter:		DS.B	1		; Used to count bits in a Tx
			Value:			DS.B	1		; Used to store data value
			
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
			;Initialize variables
			CLR 	Value 			;Clear all RAM variables
			CLR 	BitCounter
			
			;*** init SDA and SCL pins as outputs
			BSET	SDA, PTADD
			BSET	SDA, PTADD
			
			;*** init SDA and SCL pins to high
			BSET	SDA, PTAD
			BSET	SDA, PTAD

			RTS

;**************************************************************


;************************************************************** 
;* Subroutine Name: i2c_start  
;* Description: Generate a START condition on the bus.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
i2c_start: 
			; crate falling edge on SDA while SCL high
			BCLR 	SDA, PTAD
			JSR 	i2c_bit_delay
			BCLR 	SCL, PTAD
			RTS

;**************************************************************

;************************************************************** 
;* Subroutine Name: i2c_stop  
;* Description: Generate a STOP condition on the bus.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
i2c_stop: 
			; crate rising edge on SDA while SCL high
			BCLR 	SDA, PTAD
			BSET 	SCL, PTAD
			BSET 	SDA, PTAD
			JSR 	i2c_bit_delay
			RTS

;**************************************************************

;************************************************************** 
;* Subroutine Name: i2c_tx_byte  
;* Description: Transmit the byte in Acc to the SDA pin
;*				(Acc will not be restored on return)
;*
;*				Must be careful to change SDA values only 
;*				while SCL is low, otherwise a STOP or START 
;*				could be implied.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
i2c_tx_byte: 			
			;Initialize variable
			LDX 	#$08
			STX 	BitCounter

nextbit:
			ROLA						; Shift MSB into Carry
			BCC		send_low			; Send low bit or high bit
			
send_high:
			BSET	SDA, PTAD			; set the data bit value
			JSR		i2c_setup_delay		; Give some time for data
			
setup:
			BSET	SCL, PTAD			; clock in data
			JSR		i2c_bit_delay		; wait a bit
			BRA		continue			; continue
			
send_low:
			BCLR	SDA, PTAD			; set the data bit value
			JSR		i2c_setup_delay		; Give some time for data
			BRA		setup				; clock in the bit

continue:
			BCLR	SCL, PTAD			; Restore clock to low state
			DEC		BitCounter			; Decrement the bit counter
			BEQ		ack_poll			; Last bit?
			BRA		nextbit				; Do the next bit

ack_poll:
			BSET	SDA, PTAD
			BCLR	SDA, PTADD			; Set SDA as input
			JSR  	i2c_setup_delay		; wait
			
			BSET	SCL, PTAD			; clock the line
			JSR		i2c_bit_delay		; wait
			
			BRCLR	SDA, PTAD, done		; check SDA for ack
						
no_ack:		
			; do error handling here
			
done:
			BCLR	SCL, PTAD			; restore the clock line
			BSET	SDA, PTAD			; SDA back to output
			RTS							; done
;**************************************************************

;************************************************************** 
;* Subroutine Name: i2c_setup_delay  
;* Description: Provide some data setup time to allow
;* 				SDA to stabilize in slave device
;*				Completely arbitrary delay (10 cycles?)
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
i2c_setup_delay: 
			
			NOP
			NOP
			RTS

;**************************************************************

;************************************************************** 
;* Subroutine Name: i2c_setup_delay  
;* Description: Bit delay to provide (approximately) the desired
;*				SCL frequency
;*				Again, this is arbitrary (16 cycles?)
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
i2c_bit_delay: 
			
			NOP
			NOP
			NOP
			NOP
			NOP
			RTS

;**************************************************************
