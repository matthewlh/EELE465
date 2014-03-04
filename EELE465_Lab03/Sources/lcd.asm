;************************************************************** 
;* File Name    : 	lcd.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-04
;* Description  : 	Contains subroutines for controlling the
;*					lcd.
;*
;**************************************************************

; EQU statements


; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF lcd_init, lcd_write, lcd_char, lcd_num_to_char 
            XDEF lcd_data, lcd_char_data, lcd_col_idx
            
; import symbols
			XREF SUB_delay, SUB_delay_cnt
			XREF bus_read, bus_write, bus_addr, bus_data


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			lcd_data:		DS.B	1	; lower 4 bits = LCD data lines, bit 6 = RS, bit 5 = RW
			lcd_char_data:	DS.B	1	; used by lcd_char subroutine to store a character
			lcd_col_idx:	DS.B	1	; index of the column of the LCD that the cursor is currently in
			
; code section
MyCode:     SECTION

;************************************************************** 
;* Subroutine Name: lcd_init  
;* Description: Initilizes the LCD.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
lcd_init:
			; preserve registers
			PSHA

;*** init RS and RW pins as outputs
			LDA		PTADD
			ORA		#$03
			STA		PTADD			
						
;*** wait for 15 ms
			; load address of SUB_delay_cnt
			LDHX #SUB_delay_cnt
			
			; configure loop delays: 0x001388 = 20 ms
			LDA		#$00
			STA		2,X
			LDA		#$13
			STA		1,X
			LDA		#$88
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay


;*** Send Init Command	

			LDA		#$03
			JSR		lcd_write
			
;*** Wait for 4.1 ms
			; load address of SUB_delay_cnt
			LDHX #SUB_delay_cnt
			
			; configure loop delays: 0x001388 = 20 ms
			LDA		#$00
			STA		2,X
			LDA		#$13
			STA		1,X
			LDA		#$88
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay


;*** Send Init command
			
			LDA		#$03
			JSR		lcd_write
			

;*** Wait for 100 us
			; load address of SUB_delay_cnt
			LDHX #SUB_delay_cnt
			
			; configure loop delays: 0x001388 = 20 ms
			LDA		#$00
			STA		2,X
			LDA		#$13
			STA		1,X
			LDA		#$88
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay


;*** Send Init command

			LDA		#$03
			JSR		lcd_write
			
;*** Send Function set command

			LDA		#$02
			JSR		lcd_write

			LDA		#$02
			JSR		lcd_write

			LDA		#$08
			JSR		lcd_write ; goes blank here


;*** Send display ctrl command

			LDA		#$00
			JSR		lcd_write

			LDA		#$0F
			JSR		lcd_write

;*** Send display clear command

			LDA		#$00
			JSR		lcd_write
			
;*** Wait for 5 ms
			; load address of SUB_delay_cnt
			LDHX #SUB_delay_cnt
			
			; configure loop delays: 0x001388 = 20 ms
			LDA		#$00
			STA		2,X
			LDA		#$13
			STA		1,X
			LDA		#$88
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay

;*** Send display clear command

			LDA		#$01
			JSR		lcd_write
			
;*** Wait for 5 ms
			; load address of SUB_delay_cnt
			LDHX #SUB_delay_cnt
			
			; configure loop delays: 0x001388 = 20 ms
			LDA		#$00
			STA		2,X
			LDA		#$13
			STA		1,X
			LDA		#$88
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay


;*** Send entry mode command

			LDA		#$00
			JSR		lcd_write

			LDA		#$06
			JSR		lcd_write

;*** done ***
            
			; restore registers
			PULA
			
			; return from subroutine lcd_init
			RTS

;**************************************************************

;************************************************************** 
;* Subroutine Name: lcd_write 
;* Description: Sends data to the LCD.
;*
;* Registers Modified: Accu A
;* Entry Variables: Accu A
;* Exit Variables:  
;**************************************************************
lcd_write:
			; preserve HX register
			PSHH
			PSHX

			; store param to var for latter
			STA		lcd_data

			; clear RS and RW pins on PTAD
			LDA 	PTAD
			AND		#$FC
			STA		PTAD

			; put RS an RW on PTAD
			LDA		lcd_data
			NSA
			AND 	#$03
			ORA		PTAD
			STA		PTAD
			
			; prep bus data
			LDA		lcd_data
			AND		#$0F
			STA		bus_data						
			; prep bus addr
			LDA		#$04
			STA		bus_addr			
			; write data to bus (and clock the addr)
			JSR		bus_write		
			
			
;*** Wait for 40 us
			; load address of SUB_delay_cnt
			LDHX #SUB_delay_cnt
			
			; configure loop delays: 0x00000A = 40 us
			LDA		#$00
			STA		2,X
			LDA		#$00
			STA		1,X
			LDA		#$0A
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay
			
			; restore HX register
			PULX
			PULH

			; done
			RTS

;**************************************************************

;************************************************************** 
;* Subroutine Name: lcd_char 
;* Description: Writes a character to the LCD.
;*				If lcd_col_idx is off of the first line, the
;*				LCD will be cleared and the new char will be 
;*				written to the first column of row 0
;*
;* Registers Modified: Accu A
;* Entry Variables: Accu A
;* Exit Variables:  
;**************************************************************
lcd_char:
			; preserve HX
			PSHH
			PSHX

			; store input parameter			
			STA		lcd_char_data

			; lcd_col_idx < 17
			LDA		lcd_col_idx
			CMP		#$10
			BNE		lcd_char_write_Char
			
			; lcd_col_idx >= 17, clear lcd
			
			; Send display clear command
			LDA		#$00
			JSR		lcd_write
			LDA		#$01
			JSR		lcd_write
			
			;*** Wait for 20 ms ***
			LDHX #SUB_delay_cnt
			
			; configure loop delays: 0x001388 = 20 ms
			LDA		#$00
			STA		2,X
			LDA		#$13
			STA		1,X
			LDA		#$88
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay
			
			;  reset lcd_col_idx
			LDA		#$00
			STA		lcd_col_idx


lcd_char_write_Char:

			; write upper nibble
			LDA		lcd_char_data
			NSA
			AND		#$0F
			ORA		#$20
			JSR		lcd_write
			
			; write lower nibble
			LDA		lcd_char_data
			AND		#$0F
			ORA		#$20
			JSR		lcd_write
			
			;*** Wait for 20 ms ***
			LDHX #SUB_delay_cnt
			
			; configure loop delays: 0x001388 = 20 ms
			LDA		#$00
			STA		2,X
			LDA		#$13
			STA		1,X
			LDA		#$88
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay
			
			; increment lcd_col_idx
			LDA		lcd_col_idx
			INCA
			STA		lcd_col_idx						
			
			; done
			PULX
			PULH
			RTS


;**************************************************************

;************************************************************** 
;* Subroutine Name: num_to_char 
;* Description: Takes a number in Accu A and converts it to the
;*				ASCII representation of that number. Only works
;*				for lower for bits of Accu A.
;*
;* Registers Modified: None.
;* Entry Variables: Accu A
;* Exit Variables: Accu A 
;**************************************************************
lcd_num_to_char:
			; Add 0x30
			ADD		#$30
			RTS
			
;**************************************************************
