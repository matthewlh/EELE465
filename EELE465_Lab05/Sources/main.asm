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
            XREF math_mul_16
            XREF INTACC1, INTACC2
            XREF i2c_init, i2c_start, i2c_stop, i2c_tx_byte, i2c_rx_byte
            XREF rtc_init


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
			
			; init i2c
			JSR		i2c_init
            
			CLI			; enable interrupts
			
mainLoop:
			
			; update heatbeat led
			JSR		led_write
			
			; configure loop delays: 0x001388 = 20 ms
			LDA		#$0F
			STA		2,X
			LDA		#$FF
			STA		1,X
			LDA		#$88
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay
 
			BRA		mainLoop

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
			; do some i2c stuff
			JSR		rtc_init
			          
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



