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
            
            XREF keypad_interpret, keypad_scan, keypad_get_keypress
            XREF keypad_data_0, keypad_data_1
            
            XREF lcd_init, lcd_write, lcd_char, lcd_str, lcd_num_to_char, lcd_clear, lcd_goto_addr, lcd_goto_row0, lcd_goto_row1 
            XREF lcd_data, lcd_char_data, lcd_col_idx
            
            XREF adc_init, adc_read_ch26_avg, adc_read_ch2_avg, adc_read_avg, adc_data_0, adc_data_1
            
            XREF math_mul_16
            XREF INTACC1, INTACC2
            
            XREF i2c_init, i2c_start, i2c_stop, i2c_tx_byte, i2c_rx_byte
            
            XREF rtc_init, rtc_set_time_zero, rtc_calc_tod, rtc_write_tod, rtc_set_time, rtc_get_time, rtc_display_data, rtc_prompt_time
            XREF Sec, Min, Hour, Date, Month, Year
            
            XREF lm92_init, lm92_read_temp, lm92_write_lcd


; variable/data section
MY_ZEROPAGE: SECTION  SHORT
			
			SUB_delay_cnt:		DS.B	3		; counter for SUB_delay subroutine
			
			num_samples:		DS.B    1		; number of samples to take on the ADC	
			
			temp:				DS.B	1		; some space to hold stuff	
			temp_k:				DS.B	1		; some space to hold stuff	
			
			rtc_set:			DS.B	1		; 0x01 when the rtc has been set, 0x00 otherwise
			
			update_needed:		DS.B	1		; 0x01 when an update of the LEDs, LCD, or TEC is needed, 0x00 otherwise
			
			TEC_state:			DS.B	1		; 		
			
MY_CONST: SECTION
; Constant Values and Tables Section

			str_top:			DC.B 	"TEC State:      "	
			str_top_length:		DC.B	16
			
			str_bottom:			DC.B 	"T92:   K@T=000s "	
			str_bottom_length:	DC.B	16	
			
			str_tec_heat:		DC.B 	"Heat"
			str_tec_cool:		DC.B 	"Cool"
			str_tec_off:		DC.B 	"Off "	
			str_tec_length:		DC.B	4	
			
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
			
			; init rtc
			JSR		rtc_init		
			
			; lm92_init
			JSR		lm92_init
			
			; initially TEC off
			MOV		#$00, TEC_state
			
			; set update_needed
			MOV		#$01, update_needed
            
			CLI			; enable interrupts
			
mainLoop:			
			feed_watchdog
			
			; scan keypad
			JSR		keypad_scan
			JSR		keypad_interpret
			
			; was a key pressed?
			CBEQA	#$FF, mainLoop_cont
			
			; key was pressed, so consider it our new state
			STA		TEC_state
			
			; update TEC data (led_data)
			LDA		led_data
			AND		#$FC
			STA		led_data
			
			LDA		TEC_state
			AND		#$03
			ORA		led_data
			STA		led_data
			
			; since key was pressed, zero the time
			JSR		rtc_set_time_zero
			
			; set update_needed
			MOV		#$01, update_needed
			
mainLoop_cont:	
			; do we need to update stuff?
			LDA		update_needed
			BEQ		mainLoop
			
			JSR		update_devices		
 
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

			; read LM92 every-other time (when heartbeat LED is On) 
			LDA		led_data
			AND		#$80
			BEQ		_Vtpmovf_heartbeat
			JSR		lm92_read_temp

_Vtpmovf_heartbeat:			          
			; Toggle Heartbeat LED			
			LDA		led_data			; load current LED pattern
			EOR		#$80				; toggle bit 7
			STA		led_data			; Store pattern to var		
			
			; clear TPM ch0 flag
			LDA		TPMSC				; read register
			AND		#$4E				; clear CH0F bit, but leav others alone
			STA		TPMSC				; write back register
			
			; set update_needed
			MOV		#$01, update_needed

			; Done, Return from Interrupt
			RTI
			
			
;**************************************************************

;************************************************************** 
;* Subroutine Name: update_devices 
;* Description: 
;*
;* Registers Modified: A, update_needed
;* Entry Variables: None
;* Exit Variables: None 
;**************************************************************
update_devices:

; Update LEDs and TEC
			JSR		led_write		

; write lcd template string
  			JSR		lcd_clear
  			
  			JSR		lcd_goto_row0  			
			LDHX	#str_top
			LDA		str_top_length
			JSR		lcd_str
  			
  			JSR		lcd_goto_row1  			
			LDHX	#str_bottom
			LDA		str_bottom_length
			JSR		lcd_str
			
; write TEC state
			; set LCD cursor position
			LDA		#$8A
			JSR		lcd_goto_addr	

			LDA		TEC_state
			CBEQA	#$01, update_devices_tec_heat
			CBEQA	#$02, update_devices_tec_cool 

update_devices_tec_off:
			LDHX	#str_tec_off			
			BRA		update_devices_tec_write
						
update_devices_tec_heat:
			LDHX	#str_tec_heat			
			BRA		update_devices_tec_write

update_devices_tec_cool:
			LDHX	#str_tec_cool			
			BRA		update_devices_tec_write

update_devices_tec_write:
			LDA		str_tec_length
			JSR		lcd_str

						
; write LM92 temp
			; set LCD cursor position
			LDA		#$C4
			JSR		lcd_goto_addr			
			JSR		lm92_write_lcd 			
  			
; write time
			; if TEC is off, don't overwrite the 000s for time
			LDA		TEC_state
			CBEQA	#$00, update_devices_done

			; set LCD cursor position
			LDA		#$CB
			JSR		lcd_goto_addr
  			
  			; read time from RTC
  			JSR		rtc_get_time
			
			; calc and write TOD
			JSR		rtc_calc_tod
			JSR		rtc_write_tod
			
			BRA 	update_devices_done
			
update_devices_done:
;*** done
			MOV		#$00, update_needed
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



