;************************************************************** 
;* File Name    : 	i2c_driver.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-25
;* Description  : 	Contains subroutines for a bit-banging 
;*					software I2C driver, based on AN1820.
;*
;**************************************************************

; EQU statements
SCL 		EQU 3 		;Serial clock bit number
SDA 		EQU 2 		;Serial data bit number

; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF i2c_init, i2c_start, i2c_stop, i2c_tx_byte, i2c_rx_byte
            ;XDEF 
            
; import symbols
			;XREF 


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			BitCounter:		DS.B	1		; Used to count bits in a Tx
			Value:			DS.B	1		; Used to store rx data value
			
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
			BSET	SCL, PTADD
			
			;*** init SDA and SCL pins to high
			BSET	SDA, PTAD
			BSET	SCL, PTAD

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
;* Registers Modified: A, X
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
i2c_tx_byte: 			
			;Initialize variable
			LDX 	#$08
			STX 	BitCounter

tx_nextbit:
			ROLA						; Shift MSB into Carry
			BCC		tx_send_low			; Send low bit or high bit
			
tx_send_high:
			BSET	SDA, PTAD			; set the data bit value
			JSR		i2c_setup_delay		; Give some time for data
			
tx_setup:
			BSET	SCL, PTAD			; clock in data
			JSR		i2c_bit_delay		; wait a bit
			BRA		tx_continue			; continue
			
tx_send_low:
			BCLR	SDA, PTAD			; set the data bit value
			JSR		i2c_setup_delay		; Give some time for data
			BRA		tx_setup				; clock in the bit

tx_continue:
			BCLR	SCL, PTAD			; Restore clock to low state
			DEC		BitCounter			; Decrement the bit counter
			BEQ		tx_ack_poll			; Last bit?
			BRA		tx_nextbit			; Do the next bit

tx_ack_poll:
			BSET	SDA, PTAD
			BCLR	SDA, PTADD			; Set SDA as input
			JSR  	i2c_setup_delay		; wait
			
			BSET	SCL, PTAD			; clock the line
			JSR		i2c_bit_delay		; wait
			
			BRCLR	SDA, PTAD, tx_done	; check SDA for ack
						
tx_no_ack:		
			; do error handling here
			
tx_done:
			BCLR	SCL, PTAD			; restore the clock line
			BSET	SDA, PTADD			; SDA back to output
			RTS							; done
;**************************************************************

;************************************************************** 
;* Subroutine Name: i2c_rx_byte  
;* Description: Recieves a byte from the I2C bus. 
;*				Will Ack the byte if Accu A != 0
;*				Data returned in Accu A 
;* 
;* Registers Modified: A, X
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
i2c_rx_byte:

			; clear output var
			CLR		Value
			
			; set BitCounter
			LDX 	#$08
			STX 	BitCounter
			
			; set SDA to input and pull clock low
			BCLR	SDA, PTADD
			BCLR	SCL, PTAD
			
rx_nextbit:
			; wait for a bit
			JSR		i2c_bit_delay

			; shift the last bit recieved left (and fill LSB with zero)
			LSL		Value
			
			; clock the line and wait
			BSET	SCL, PTAD
			JSR		i2c_setup_delay

			; grab bit from bus
			BRCLR	SDA, PTAD, rx_low
			
rx_high:
			; store a 1 to Value
			BSET	0, Value
			BRA		rx_continue

rx_low:
			; do nothing since LSL fills with 0

rx_continue:
			BCLR	SCL, PTAD			; Restore clock to low state
			DEC		BitCounter			; Decrement the bit counter
			BNE		rx_nextbit			; More bits?
			
			
			; set SDA back to output
			BSET	SDA, PTADD
			
			; test Accu A == 0
			CBEQA	#$00, rx_nack
			BRA		rx_ack

rx_ack:
			; clear data bit to acknowledge
			BCLR	SDA, PTAD			
			BRA		rx_done

rx_nack:
			; set data bit to not acknowledge
			BSET	SDA, PTAD			

rx_done:
			; let ack/nack settle
			JSR		i2c_setup_delay
			
			;clock the ack/nack 
			BSET	SCL, PTAD
			JSR		i2c_bit_delay
			
			; retun clock to low
			BCLR	SCL, PTAD
			
			; load Value into Accu A
			LDA		Value
			
			RTS


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
