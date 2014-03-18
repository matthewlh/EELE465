;************************************************************** 
;* Program Name: Lab#03 - ADC
;* Author Names: Matthew Handley 
;* Date: 2014-02-25
;* Description: Does stuff and stuff.
;*
;* 
;**************************************************************

; Include derivative-specific definitions
            INCLUDE 'derivative.inc'
            

; export symbols
            XDEF _Startup, main, _Vtpmovf, SUB_delay, SUB_delay_cnt
            ; we export both '_Startup' and 'main' as symbols. Either can
            ; be referenced in the linker .prm file or from C/C++ later on
            
            
            XREF __SEG_END_SSTACK   ; symbol defined by the linker for the end of the stack
            XREF bus_init, bus_read, bus_write, bus_addr, bus_data
            XREF led_write, led_data
            XREF keypad_interpret, keypad_scan, keypad_data_0, keypad_data_1
            XREF lcd_init, lcd_write, lcd_char, lcd_str, lcd_num_to_char, lcd_clear, lcd_goto_row0, lcd_goto_row1, lcd_data, lcd_char_data, lcd_col_idx
            XREF adc_init, adc_read_ch26_avg, adc_read_ch2_avg, adc_read_avg, adc_data_0, adc_data_1


; variable/data section
MY_ZEROPAGE: SECTION  SHORT
			
			SUB_delay_cnt:		DS.B	3		; counter for SUB_delay subroutine
			
			num_samples:		DS.B    1		; number of samples to take on the ADC	
			
			temp:				DS.B	1		; some space to hold stuff	
			temp_k:				DS.B	1		; some space to hold stuff	
			
MY_CONST: SECTION
; Constant Values and Tables Section

			str_prompt:			DC.B 	"Enter n: "	
			str_prompt_length:	DC.B	9	

			str_TK:				DC.B 	"T,K:"	
			str_TK_length:		DC.B	4	
			str_TC:				DC.B 	" T,C:"	
			str_TC_length:		DC.B	5		
			
; code section
MyCode:     SECTION
main:
_Startup:
            LDHX   #__SEG_END_SSTACK ; initialize the stack pointer
            TXS
            
            ; init bus
            JSR		bus_init
            
            ;*** init LCD and RS, RW pins ***
			JSR		lcd_init
			
			LDA		#$00
			STA		lcd_col_idx	
			
			;*** init TPM module - for heartbeat LED ***
			; TPMMODH:L Registers 
			LDA 	#$00
			STA		TPMMODH
			LDA 	#$00 
			STA		TPMMODL
			; TPMSC Register 
			LDA 	#$4E					; TOIE clear, CLKS: Bus clock, Prescale: 128
			STA		TPMSC			
			
			;*** init led_data variable ***
			LDA		#$00
			STA		led_data
			
			; init ADC
			JSR		adc_init
            
			CLI			; enable interrupts
			

mainLoop:
;*** reset to start
			; clear vars 
			
			
			; clear display
			JSR		lcd_clear
			

;*** prompt user for input
			LDHX	#str_prompt
			LDA		str_prompt_length
			JSR		lcd_str			
			
;*** wait for user response, n
mainloop_prompt_wait:

           	; Update heartheat LED while we wait	
			JSR		led_write
			
			; feed watchdog while we wait
            feed_watchdog
			
			; scan keypad
           	JSR		keypad_scan
			
			; check for button press
			JSR		keypad_interpret
			
			; if no button press, repeat
			BEQ		mainloop_prompt_wait		
			
			
;*** read external temp sensor n times
			STA		num_samples
			JSR		adc_read_ch2_avg
			
;*** do math external temp sensor data

			; multiply n*4
			LDA		num_samples
			LDX		#04
			MUL		; X:A <- (X) * (A)
			
			; load upper byte of adc_data to HX 
			LDHX	adc_data_0
			
			; move result of n*4 to X
			PSHA
			PULX
			
			; load A with lower byte of adc_data 
			LDA		adc_data_1
			
			; divide adc_data by (n*4)
			DIV		; A <- (H:A)/(X)

			; save result in temp
			STA		temp
			
			; subtract result from offset $93
			LDA		#$93
			SUB		temp
			STA		temp

; make sure value less than 99
			CMP		#$63
			BLO		mainloop_write_external
			LDA		#$63	
			STA		temp		
			
mainloop_write_external:

			; clear display
			JSR		lcd_clear

;*** write external temp in K

			; write "T,K:" to the LCD 
			LDHX	#str_TK
			LDA		str_TK_length
			JSR		lcd_str	
			
			
			; temp >= 27 C == 300 K?
			LDA		temp
			CMP		#$1B
			BLO		mainloop_k_small
			
mainloop_k_big:
			; convert to K
			SUB		#$1B
			STA		temp_k
			
			; write 3 for 300K
			LDA		#'3'
			JSR		lcd_char
			BRA		mainloop_k
			
mainloop_k_small:
			; convert to K
			ADD		#$49
			STA		temp_k
			
			; write 2 for 200K
			LDA		#'2'
			JSR		lcd_char

mainloop_k:
			LDA		temp_k

			; write upper number to LCD
			LDHX	#$000A
			DIV						; A <= (H:A)/(X), H <= (remainder)
			
			; convert to ASCII char
			JSR		lcd_num_to_char
			
			; write to LCD
			JSR		lcd_char
			
			; move remainder from H to A
			PSHH
			PULA
			
			; convert to ASCII char
			JSR		lcd_num_to_char
			
			; write to LCD
			JSR		lcd_char
			
			
;*** write external temp in C

			; write " T,C:" to the LCD 
			LDHX	#str_TC
			LDA		str_TC_length
			JSR		lcd_str	
			
			LDA		temp

			; write upper number to LCD
			LDHX	#$000A
			DIV						; A <= (H:A)/(X), H <= (remainder)
			
			; convert to ASCII char
			JSR		lcd_num_to_char
			
			; write to LCD
			JSR		lcd_char
			
			; move remainder from H to A
			PSHH
			PULA
			
			; convert to ASCII char
			JSR		lcd_num_to_char
			
			; write to LCD
			JSR		lcd_char
			

;*** wait for '*' key press
mainloop_end:

           	; Update heartheat LED while we wait	
			JSR		led_write
			
           	; feed watchdog while we wait
            feed_watchdog
            
            ; scan keypad
           	JSR		keypad_scan
			
			; check for button press
			JSR		keypad_interpret
			
			; if '*' button pressed, restart
			CBEQA	#$0E, mainloop_restart
            
            ; keep waiting for '*' key
            BRA    	mainloop_end
            
mainloop_restart:
			JMP		mainLoop

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
			          
			; Toggle Heartbeat LED			
			LDA		led_data			; load current LED pattern
			EOR		#$80				; toggle bit 7
			STA		led_data			; Store pattern to var		
			
			; clear TPM ch0 flag
			LDA		TPMSC				; read register
			AND		#$4E				; clear CH0F bit, but leav others alone
			STA		TPMSC				; write back register

			; Done, Return from Interrupt
			RTI
			
			
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



