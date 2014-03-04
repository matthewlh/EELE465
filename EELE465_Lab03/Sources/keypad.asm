;************************************************************** 
;* File Name    : 	keypad.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-04
;* Description  : 	Contains subroutines for reading the
;*					keypad.
;*
;**************************************************************

; EQU statements


; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF keypad_interpret, keypad_scan, keypad_data_0, keypad_data_1, keypad_data_0_old, keypad_data_1, keypad_data_cmp 
            
; import symbols
			XREF bus_read, bus_write, bus_addr, bus_data
			XREF led_data  
			XREF lcd_char  


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			keypad_data_0:	DS.B	1	; bit flags representing what keys are pressed on they 4x4 keypad
			keypad_data_1:	DS.B	1
			
			keypad_data_0_old:	DS.B	1	; bit flags representing which keys were pressed on the keypad, the last time it was scanned
			keypad_data_1_old:	DS.B	1
			
			keypad_data_cmp:	DS.B	1	; tempory holder for keypad data comparison in keypad_interpret

; code section
MyCode:     SECTION



;************************************************************** 
;* Subroutine Name: keypad_scan 
;* Description: Scans the greyhill 4x4 keypad, and saves the 
;*				result to variable.
;*				Note that this method will overwrite values in 
;*				the bus_addr and bus_data variables.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: keypad_data_0, keypad_data_1
;**************************************************************
keypad_scan:
			; preserve registers
			PSHA
			
;*** save old value of keypad_data, before we overwrite it

			LDA		keypad_data_0
			STA		keypad_data_0_old
			LDA		keypad_data_1
			STA		keypad_data_1_old

;*** scan row 0 ***

		;* set row 0 to low, other rows to high * 
		           
            ; set address of keypad driver DFF
            LDA 	#$02
            STA		bus_addr
            
            ; set the data
            LDA 	#%00001110
            STA		bus_data
            
            ; write the data
            JSR		bus_write
            
		;* read data from row *
		
			; set the address
            LDA 	#$03
            STA		bus_addr
            
            ; read the data
            JSR		bus_read
            
		;* save row data to variable *
			
			LDA		bus_data		; load in data nibble
			COMA					; compliment bits, so 1=button press
			AND		#$0F			; mask off the lower 4 bits
			STA		keypad_data_0	; store to vairable


;*** scan row 1 ***

		;* set row 1 to low, other rows to high * 
		           
            ; set address of keypad driver DFF
            LDA 	#$02
            STA		bus_addr
            
            ; set the data
            LDA 	#%00001101
            STA		bus_data
            
            ; write the data
            JSR		bus_write
            
		;* read data from row *
		
			; set the address
            LDA 	#$03
            STA		bus_addr
            
            ; read the data
            JSR		bus_read
            
		;* save row data to variable *
					
			LDA		bus_data		; load in data nibble
			COMA					; compliment bits, so 1=button press
			NSA						; swap our data to the upper nibble
			AND		#$F0			; mask off the data
			ORA		keypad_data_0	; add the lower 4 bits in
			STA		keypad_data_0	; store to vairable


;*** scan row 2 ***

		;* set row 2 to low, other rows to high * 
		           
            ; set address of keypad driver DFF
            LDA 	#$02
            STA		bus_addr
            
            ; set the data
            LDA 	#%00001011
            STA		bus_data
            
            ; write the data
            JSR		bus_write
            
		;* read data from row *
		
			; set the address
            LDA 	#$03
            STA		bus_addr
            
            ; read the data
            JSR		bus_read
            
		;* save row data to variable *
			
			LDA		bus_data		; load in data nibble
			COMA					; compliment bits, so 1=button press
			AND		#$0F			; mask off the lower 4 bits
			STA		keypad_data_1	; store to vairable


;*** scan row 3 ***

		;* set row 3 to low, other rows to high * 
		           
            ; set address of keypad driver DFF
            LDA 	#$02
            STA		bus_addr
            
            ; set the data
            LDA 	#%00000111
            STA		bus_data
            
            ; write the data
            JSR		bus_write
            
		;* read data from row *
		
			; set the address
            LDA 	#$03
            STA		bus_addr
            
            ; read the data
            JSR		bus_read
            
		;* save row data to variable *
					
			LDA		bus_data		; load in data nibble
			COMA					; compliment bits, so 1=button press
			NSA						; swap our data to the upper nibble
			AND		#$F0			; mask off the data
			ORA		keypad_data_1	; add the lower 4 bits in
			STA		keypad_data_1	; store to vairable


;*** done ***
            
			; restore registers
			PULA
			
			; return from subroutine keypad_scan
			RTS

;**************************************************************

;************************************************************** 
;* Subroutine Name: keypad_interpret  
;* Description: Interpres the data from the keypad.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
keypad_interpret:

			; preserve registers
			PSHA

;*** was a key pressed in the first 2 rows ? ***
			
			LDA		keypad_data_0_old
			COMA	
			AND		keypad_data_0
			CBEQA	#$00, keypad_interpret_lower_rows_jump
			
			; key was pressed
			STA		keypad_data_cmp

keypad_interpret_1:

			; was '1' pressed ?
			LDA		keypad_data_cmp
			AND		#%11111110
			BNE		keypad_interpret_2

			; write a '1' to the LCD
			LDA		#'1'
			JSR		lcd_char
			
			; put 0x1 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$01
			STA		led_data


keypad_interpret_2:

			; was '2' pressed ?
			LDA		keypad_data_cmp
			AND		#%11111101
			BNE		keypad_interpret_3

			; write a '2' to the LCD
			LDA		#'2'
			JSR		lcd_char
			
			; put 0x1 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$02
			STA		led_data

keypad_interpret_3:

			; was '3' pressed ?
			LDA		keypad_data_cmp
			AND		#%11111011
			BNE		keypad_interpret_A

			; write a '3' to the LCD
			LDA		#'3'
			JSR		lcd_char
			
			; put 0x3 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$03
			STA		led_data


keypad_interpret_A:

			; was 'A' pressed ?
			LDA		keypad_data_cmp
			AND		#%11110111
			BNE		keypad_interpret_4

			; write a 'A' to the LCD
			LDA		#'A'
			JSR		lcd_char
			
			; put 0xA on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$0A
			STA		led_data
			
			BRA		keypad_interpret_4
keypad_interpret_lower_rows_jump:
			BRA		keypad_interpret_lower_rows


keypad_interpret_4:

			; was '4' pressed ?
			LDA		keypad_data_cmp
			AND		#%11101111
			BNE		keypad_interpret_5

			; write a '4' to the LCD
			LDA		#'4'
			JSR		lcd_char
			
			; put 0x4 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$04
			STA		led_data


keypad_interpret_5:

			; was '5' pressed ?
			LDA		keypad_data_cmp
			AND		#%11011111
			BNE		keypad_interpret_6

			; write a '5' to the LCD
			LDA		#'5'
			JSR		lcd_char
			
			; put 0x5 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$05
			STA		led_data


keypad_interpret_6:

			; was '6' pressed ?
			LDA		keypad_data_cmp
			AND		#%10111111
			BNE		keypad_interpret_B

			; write a '6' to the LCD
			LDA		#'6'
			JSR		lcd_char
			
			; put 0x6 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$06
			STA		led_data


keypad_interpret_B:

			; was 'B' pressed ?
			LDA		keypad_data_cmp
			AND		#%01111111
			BNE		keypad_interpret_lower_rows

			; write a 'B' to the LCD
			LDA		#'B'
			JSR		lcd_char
			
			; put 0xB on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$0B
			STA		led_data



keypad_interpret_lower_rows:
;*** was a key pressed in the second 2 rows ? ***

			LDA		keypad_data_1_old
			COMA	
			AND		keypad_data_1
			CBEQA	#$00, keypad_interpret_done_jump
			
			; key was pressed
			STA		keypad_data_cmp


keypad_interpret_7:

			; was '7' pressed ?
			LDA		keypad_data_cmp
			AND		#%11111110
			BNE		keypad_interpret_8

			; write a '7' to the LCD
			LDA		#'7'
			JSR		lcd_char
			
			; put 0x7 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$07
			STA		led_data


keypad_interpret_8:

			; was '8' pressed ?
			LDA		keypad_data_cmp
			AND		#%11111101
			BNE		keypad_interpret_9

			; write a '8' to the LCD
			LDA		#'8'
			JSR		lcd_char
			
			; put 0x8 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$08
			STA		led_data


keypad_interpret_9:

			; was '9' pressed ?
			LDA		keypad_data_cmp
			AND		#%11111011
			BNE		keypad_interpret_C

			; write a '9' to the LCD
			LDA		#'9'
			JSR		lcd_char
			
			; put 0x9 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$09
			STA		led_data


keypad_interpret_C:

			; was 'C' pressed ?
			LDA		keypad_data_cmp
			AND		#%11110111
			BNE		keypad_interpret_E

			; write a 'C' to the LCD
			LDA		#'C'
			JSR		lcd_char
			
			; put 0xC on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$0C
			STA		led_data		
			
			
			BRA 	keypad_interpret_E
keypad_interpret_done_jump:
			BRA		keypad_interpret_done


keypad_interpret_E:

			; was 'E'/'*' pressed ?
			LDA		keypad_data_cmp
			AND		#%11101111
			BNE		keypad_interpret_0

			; write a 'E' to the LCD
			LDA		#'E'
			JSR		lcd_char
			
			; put 0xE on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$0E
			STA		led_data


keypad_interpret_0:

			; was '0' pressed ?
			LDA		keypad_data_cmp
			AND		#%11011111
			BNE		keypad_interpret_F

			; write a '0' to the LCD
			LDA		#'0'
			JSR		lcd_char
			
			; put 0x0 on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$00
			STA		led_data


keypad_interpret_F:

			; was 'F'/'#' pressed ?
			LDA		keypad_data_cmp
			AND		#%10111111
			BNE		keypad_interpret_D

			; write a 'F' to the LCD
			LDA		#'F'
			JSR		lcd_char
			
			; put 0xF on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$0F
			STA		led_data


keypad_interpret_D:

			; was 'D' pressed ?
			LDA		keypad_data_cmp
			AND		#%01111111
			BNE		keypad_interpret_done

			; write a 'D' to the LCD
			LDA		#'D'
			JSR		lcd_char
			
			; put 0xD on LEDs
			LDA		led_data
			AND		#$F0
			ORA		#$0D
			STA		led_data

			

keypad_interpret_done:
;*** done ***
            
			; restore registers
			PULA
			
			; return from subroutine keypad_scan
			RTS

;**************************************************************
