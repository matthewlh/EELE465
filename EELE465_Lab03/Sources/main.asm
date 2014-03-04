;************************************************************** 
;* Program Name: Lab#03 - ADC
;* Author Names: Matthew Handley 
;* Date: 2014-02-25
;* Description: Does stuff and stuff.
;*
;* 
;**************************************************************

mDataBus		EQU	$F0		; Mask for the data bus pins on PortB
mAddrBus		EQU	$0F		; Mask for the address bus pins on PortB

ADCS1_CH2		EQU %00000010	;ADCS1 configured for CH2
ADCS1_CH26		EQU %00011010	;ADCS1 configured for CH26 (internal temp. sensor) 


; Include derivative-specific definitions
            INCLUDE 'derivative.inc'
            

; export symbols
            XDEF _Startup, main, _Vtpmovf, keypad_scan, lcd_init, SUB_delay
            ; we export both '_Startup' and 'main' as symbols. Either can
            ; be referenced in the linker .prm file or from C/C++ later on
            
            
            XREF __SEG_END_SSTACK   ; symbol defined by the linker for the end of the stack
            XREF bus_read, bus_write
            XREF led_write, led_data
            XREF keypad_interpret, keypad_scan, keypad_data_0, keypad_data_1


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			bus_addr:		DS.B	1	; only use lower 3 bits
			bus_data:		DS.B	1	; only use lower 4 bits
			
			lcd_data:		DS.B	1	; lower 4 bits = LCD data lines, bit 6 = RS, bit 5 = RW
			lcd_char_data:	DS.B	1	; used by lcd_char subroutine to store a character
			lcd_col_idx:	DS.B	1	; index of the column of the LCD that the cursor is currently in
			
			
			adc_data_0:		DS.B	1	; upper 8 bits from ADC read
			adc_data_1:		DS.B	1	; lower 8 bits from ADC read  
			
			; counter for SUB_delay subroutine
			SUB_delay_cnt:		DS.B	3
			
MY_CONST: SECTION
; Constant Values and Tables Section

	
			
; code section
MyCode:     SECTION
main:
_Startup:
            LDHX   #__SEG_END_SSTACK ; initialize the stack pointer
            TXS
			
			;*** init TPM module - for heartbeat LED ***
			; TPMMODH:L Registers 
			LDA 	#$00
			STA		TPMMODH
			LDA 	#$00 
			STA		TPMMODL
			; TPMSC Register 
			LDA 	#$4E					; TOIE clear, CLKS: Bus clock, Prescale: 128
			STA		TPMSC
			
			;*** init Data & Address Busses ***
			LDA		mAddrBus				; Set Address Bus pins as output by default, leave data as input
			STA		PTBDD
			LDA		$00						; Leave all of PortB as input at start 
			STA		PTBD
		
			;*** init LCD and RS, RW pins ***
			JSR		lcd_init
			
			LDA		#$00
			STA		lcd_col_idx				
			
			;*** init led_data variable ***
			LDA		#$00
			STA		led_data
			
			;*** init ADC ***
			LDA		#ADCS1_CH2		;AIEN=0, ADCO=0, ADCH=2
			STA		ADCSC1
			LDA		#$00			;ADTRG=0, ACFE=0, ACFGT=0
			STA		ADCSC2
			LDA		#%00001000		;ADLPC=0, ADIV=00, ADLSMP=0, MODE=10-bit, ADICLK=00
			STA		ADCCFG
			LDA		#$04			;ADPC2=1
			STA		APCTL1
			
            
			CLI			; enable interrupts
			

mainLoop:
;*** reset to start
			; clear vars 
			
			
			; clear display
			

;*** prompt user for input
			
			
;*** wait for user response, n
mainloop_prompt:

           	; Update heartheat LED while we wait	
			JSR		led_write
			
			; feed watchdog while we wait
            feed_watchdog
			
			; scan keypad
           	JSR		keypad_scan
			
			; check for button press
			JSR		keypad_interpret
			
			; if no button press, repeat
			
			
;*** while n != 0
mainloop_read:			

           	; Update heartheat LED while we wait	
			JSR		led_write
			
			; feed watchdog while we wait
            feed_watchdog

			; read external temp sensor
				

			; read internal temp sensor			
			
			
			; repeat if n != 0
			
;*** do math internal temp data

			
;*** do math internal temp data


;*** displau result
mainloop_end:
           	
            feed_watchdog
            BRA    	mainLoop


;************************************************************** 
;* Subroutine Name: _Vtpmovf 
;* Description: Interrupt service routine for the TPM overflow
;*				interrupt. Toggles the heartbeat LED (PortA[0]) 
;*				and resets TPM overflow flag.
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None 
;**************************************************************
_Vtpmovf:   
			; presever registers
			PSHA
			PSHH
			PSHX

;*** Write ADC value to LCD
			; write to ADCS1 to trigger ADC measurement
			LDA		ADCSC1
			STA		ADCSC1	
								
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

			; go back to first column and row of LCD
			LDA		#$00
			JSR		lcd_write
			LDA		#$00
			JSR		lcd_write
			
			;  reset lcd_col_idx
			LDA		#$00
			STA		lcd_col_idx
			
			; save adc data
			LDA		ADCRH
			STA		adc_data_0
			LDA		ADCRL
			STA		adc_data_1
			
			; divide adc_data by 4
			LDHX	adc_data_0
			LDX		#$04
			LDA		adc_data_1
			DIV						; A <= (H:A)/(X)
			STA		adc_data_0
			
			; subtract from offset
			LDA		#$93		
			SUB		adc_data_0
			STA		adc_data_0
			
			; make sure value less than 99
			CMP		#$63
			BLO		write_to_lcd
			LDA		#$63			
			
write_to_lcd:
			; write upper numbder to LCD
			LDHX	#$000A
			DIV						; A <= (H:A)/(X), H <= (remainder)
			
			; convert to ASCII char
			JSR		num_to_char
			
			; write to LCD
			JSR		lcd_char
			
			; move remainder from H to A
			PSHH
			PULA
			
			; convert to ASCII char
			JSR		num_to_char
			
			; write to LCD
			JSR		lcd_char
			   
;*** Other Stuff            
			; Toggle Heartbeat LED			
			LDA		led_data			; load current LED pattern
			EOR		#$80				; toggle bit 7
			STA		led_data			; Store pattern to var		
			
			; clear TPM ch0 flag
			LDA		TPMSC				; read register
			AND		#$4E				; clear CH0F bit, but leav others alone
			STA		TPMSC				; write back register
			

;*** done ***
			PULX
			PULH
			PULA

			;Return from Interrupt
			RTI
			
			
;**************************************************************


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
num_to_char:
			; Add 0x30
			ADD		#$30
			RTS
			
;**************************************************************

;************************************************************** 
;* Subroutine Name: SUB_delay 
;* Description: Decrements SUB_delay_cnt until it reaches zero.
;*				1 count in SUB_delay_cnt is approx 4.019 us
;*
;* Registers Modified: None.
;* Entry Variables: SUB_delay_cnt - 3 byte variable, determines length 
;*					of time the SUB_delay routine will take to execute.
;* Exit Variables: SUB_delay_cnt - will be zero at exit. 
;**************************************************************
SUB_delay:
			; save the existing values of registers
			PSHH
			PSHX
			PSHA
			
			; load address of SUB_delay_cnt
			LDHX #SUB_delay_cnt
			
SUB_delay_loop_0:

			feed_watchdog
			
			; if byte[0] == 0
			LDA 	0, X
			BEQ		SUB_delay_loop_1		; jump to SUB_delay_outer_loop
			
			;else
			DECA							; decrement byte[0]
			STA		0, X
			
			;repeat
			BRA SUB_delay_loop_0
			
SUB_delay_loop_1:

			; if byte[1] == 0
			LDA 	1, X
			BEQ		SUB_delay_loop_2		; branch to done
			
			;else
			DECA							; decrement byte[1]
			STA		1, X
			 
			LDA		#$FF					; reset byte[0]
			STA		0,X
			
			;repeat
			BRA SUB_delay_loop_0	
			
SUB_delay_loop_2:

			; if byte[2] == 0
			LDA 	2, X
			BEQ		SUB_delay_done			; branch to done
			
			;else
			DECA							; decrement byte[2]
			STA		2, X
			 
			LDA		#$FF					; reset byte[1]
			STA		1, X
			LDA		#$FF					; reset byte[0]
			STA		0, X
			
			;repeat
			BRA SUB_delay_loop_0	
			
SUB_delay_done:
			
			; restore registers to previous values 
			PULA
			PULX
			PULH

			RTS
;**************************************************************



