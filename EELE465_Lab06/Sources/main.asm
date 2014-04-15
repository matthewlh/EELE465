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
            
            XREF lm92_init, lm92_read_temp, lm92_write_lcd_K, lm92_write_lcd_C


; variable/data section
MY_ZEROPAGE: SECTION  SHORT
			
			SUB_delay_cnt:		DS.B	3		; counter for SUB_delay subroutine
			
			num_samples:		DS.B    1		; number of samples to take on the ADC	
			
			temp:				DS.B	1		; some space to hold stuff	
			temp_k:				DS.B	1		; some space to hold stuff	
			
			rtc_set:			DS.B	1		; 0x01 when the rtc has been set, 0x00 otherwise
			
			update_needed:		DS.B	1		; 0x01 when an update of the LEDs, LCD, or TEC is needed, 0x00 otherwise
			
			TEC_state:			DS.B	1		; In Mode A: 0=off,  1=heat, 2=cool
												; In Mode B: 0=hold, 1=heat, 2=cool
			new_TEC_state:		DS.B	1
			
			mode:				DS.B	1		; Mode; 0x0A = A, 0x0B = B, 0x00 = Waiting for mode	
			
			Tset:				DS.B	1		; set point temperature, for mode B
			Tcur:				DS.B	1		; current temperature, for mode B	
			
MY_CONST: SECTION
; Constant Values and Tables Section
			
			str_start:				DC.B 	"Mode: A,B?      "	
			str_start_length:		DC.B	16

			str_A_top:				DC.B 	"TEC State:      "	
			str_A_top_length:		DC.B	16			
			str_A_bottom:			DC.B 	"T92:   K@T=000s "	
			str_A_bottom_length:	DC.B	16	
			
			
			str_B_prompt_top:		DC.B 	"Target Temp?    "
			str_B_prompt_top_len:	DC.B	16
			str_B_prompt_bottom:	DC.B 	"Enter 10-40C "
			str_B_prompt_bottom_len:DC.B	13
			
			str_B_top_heat:			DC.B 	"TEC State:HeatXX"	
			str_B_top_cool:			DC.B 	"TEC State:CoolXX"
			str_B_top_hold:			DC.B 	"TEC State:HoldXX"
			str_B_bottom:			DC.B 	"T92:   C@T=000s "
			
			str_tec_heat:			DC.B 	"Heat"
			str_tec_cool:			DC.B 	"Cool"
			str_tec_off:			DC.B 	"Off "	
			str_tec_length:			DC.B	4	
			
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
			
			; set mode
            
			CLI			; enable interrupts
			
;************************************************************** 
;* Subroutine Name: restart 
;* Description: Restart loop for startup and when the user
;*				wants to change modes.
;* Registers Modified: A,X,H
;* Entry Variables: None
;* Exit Variables: None 
;**************************************************************			
restart:
			; reset mode & Tset
			MOV		#$00, mode
			MOV		#$00, Tset
			
			; turn TEC off
			LDA		led_data
			AND		#$FC
			STA		led_data
			
			; reset state
			MOV		#$00, TEC_state
			
			; put prompt on LCD	
  			JSR		lcd_clear
  			
  			JSR		lcd_goto_row0  			
			LDHX	#str_start
			LDA		str_start_length
			JSR		lcd_str
			
			; set update_needed
			MOV		#$01, update_needed

restart_loop:
			feed_watchdog
			
			; update LEDs
			JSR		led_write
			
			; scan keypad
			JSR		keypad_scan
			JSR		keypad_interpret
			
			; was 'A' pressed?
			CBEQA	#$0A, A_mainLoop
			
			; was 'B' pressed?
			CBEQA	#$0B, B_mainLoop_start
			
			BRA		restart_loop

			
;************************************************************** 
;* Subroutine Name: A_mainLoop 
;* Description: Main loop for mode A
;* Registers Modified: A,X,H
;* Entry Variables: None
;* Exit Variables: None 
;**************************************************************
A_mainLoop:			
			; set mode
			MOV		#$0A, mode

			feed_watchdog
			
			; scan keypad
			JSR		keypad_scan
			JSR		keypad_interpret
			
			; was a key pressed?
			CBEQA	#$FF, A_mainLoop_cont
			
			; was '*' pressed
			CBEQA	#$0E, restart
			
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
			
A_mainLoop_cont:	
			; do we need to update stuff?
			LDA		update_needed
			BEQ		A_mainLoop
			
			JSR		A_update_devices		
 
			BRA		A_mainLoop
			
;**************************************************************

jmp_restart:
			JMP		restart

;************************************************************** 
;* Subroutine Name: B_mainLoop_start 
;* Description: Main loop for mode B
;* Registers Modified: A,X,H
;* Entry Variables: None
;* Exit Variables: None 
;**************************************************************
B_mainLoop_start:

			; set mode
			MOV		#$0B, mode
			
			; set TEC_state so that state change forced on first iteration
			MOV		#$10, TEC_state
			
			; prompt for Tset
			JSR		lcd_goto_row0
			LDHX	#str_B_prompt_top
			LDA		str_B_prompt_top_len
			JSR		lcd_str
			
			JSR		lcd_goto_row1
			LDHX	#str_B_prompt_bottom
			LDA		str_B_prompt_bottom_len
			JSR		lcd_str
			
B_mainLoop_start_loop:	

			feed_watchdog
						
			; scan keypad
			JSR		keypad_scan
			JSR		keypad_interpret
			
			; was '*' pressed
			CBEQA	#$0E, jmp_restart
			
			; was '#' pressed
			CBEQA	#$0F, B_mainLoop
			
			; was nothing presed
			CBEQA	#$FF, B_mainLoop_start_loop
			
			; else, something was pressed, save it
			STA		temp
			
			; is this the second digit?
			LDA		Tset
			BNE		B_mainLoop_start_2nd_digit

B_mainLoop_start_1st_digit:

			; multiply by 10
			LDHX	#$000A
			LDA		temp
			MUL			; X:A <= (X) * (A)
			STA		Tset

			; wait for next digit
			BRA		B_mainLoop_start_loop
			
B_mainLoop_start_2nd_digit:
			
			; Add the digit to Tset
			ADD		temp
			STA		Tset
			
			; wait for '#' key press
			BRA		B_mainLoop_start_loop
			
B_mainLoop:			
			feed_watchdog
			
			; scan keypad
			JSR		keypad_scan
			JSR		keypad_interpret
			
			; was '*' pressed
			CBEQA	#$0E, jmp_restart
			
			; compare Tset with Tcur
			LDA		Tset
			CMP		Tcur
			
			; if Tset < Tcur, cool
			BHI		B_mainLoop_cool
			
			; else if Tset > Tcur, heat
			BLO		B_mainLoop_heat
			
			; else, hold
			BRA		B_mainLoop_hold
			
B_mainLoop_heat:
			MOV		#$02, new_TEC_state
			BRA		B_mainLoop_check_state

B_mainLoop_cool:			
			MOV		#$01, new_TEC_state
			BRA		B_mainLoop_check_state
			
B_mainLoop_hold:
			MOV		#$00, new_TEC_state

B_mainLoop_check_state:
			; new_TEC_state == TEC_state ?
			LDA		TEC_state
			CBEQ	new_TEC_state, B_mainLoop_cont
			
			; else new_TEC_state != TEC_state		
			
B_mainLoop_state_changed:
			
			; save new state to current state
			MOV		new_TEC_state, TEC_state
			
			; merge TEC_state with LED_data
			LDA		led_data
			AND		#$FC
			ORA		TEC_state
			STA		led_data
			
			; reset RTC counter
			JSR		rtc_set_time_zero
			
			; set update_needed flag
			MOV		#$01, update_needed
			
B_mainLoop_cont:
			; do we need to update stuff?
			LDA		update_needed
			BEQ		B_mainLoop
			
			JSR		B_update_devices		
 
			BRA		B_mainLoop
			
;**************************************************************

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
			; check mode
			LDA		mode
			CBEQA	#$0A, _Vtpmovf_A
			CBEQA	#$0B, _Vtpmovf_B 

			; not in Mode A or B, so do nothing, except update heartbeat LED
			BRA		_Vtpmovf_heartbeat

_Vtpmovf_A:
			; read LM92 every-other time (when heartbeat LED is On) 
			LDA		led_data
			AND		#$80
			BEQ		_Vtpmovf_heartbeat
			JSR		lm92_read_temp
			STA		Tcur
			
			BRA		_Vtpmovf_heartbeat

_Vtpmovf_B:
			; always read LM92
			JSR		lm92_read_temp
			STA		Tcur
			
			;BRA		_Vtpmovf_heartbeat
			
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
A_update_devices:

; Update LEDs and TEC
			JSR		led_write		

; write lcd template string
  			JSR		lcd_clear
  			
  			JSR		lcd_goto_row0  			
			LDHX	#str_A_top
			LDA		str_A_top_length
			JSR		lcd_str
  			
  			JSR		lcd_goto_row1  			
			LDHX	#str_A_bottom
			LDA		str_A_bottom_length
			JSR		lcd_str
			
; write TEC state
			; set LCD cursor position
			LDA		#$8A
			JSR		lcd_goto_addr	

			LDA		TEC_state
			CBEQA	#$01, A_update_devices_tec_heat
			CBEQA	#$02, A_update_devices_tec_cool 

A_update_devices_tec_off:
			LDHX	#str_tec_off			
			BRA		A_update_devices_tec_write
						
A_update_devices_tec_heat:
			LDHX	#str_tec_heat			
			BRA		A_update_devices_tec_write

A_update_devices_tec_cool:
			LDHX	#str_tec_cool			
			BRA		A_update_devices_tec_write

A_update_devices_tec_write:
			LDA		str_tec_length
			JSR		lcd_str

						
; write LM92 temp
			; set LCD cursor position
			LDA		#$C4
			JSR		lcd_goto_addr			
			JSR		lm92_write_lcd_K 			
  			
; write time
			; if TEC is off, don't overwrite the 000s for time
			LDA		TEC_state
			CBEQA	#$00, A_update_devices_done

			; set LCD cursor position
			LDA		#$CB
			JSR		lcd_goto_addr
  			
  			; read time from RTC
  			JSR		rtc_get_time
			
			; calc and write TOD
			JSR		rtc_calc_tod
			JSR		rtc_write_tod
			
			BRA 	A_update_devices_done
			
A_update_devices_done:
;*** done
			MOV		#$00, update_needed
			RTS

;**************************************************************
;************************************************************** 
;* Subroutine Name: B_update_devices 
;* Description: 
;*
;* Registers Modified: A, update_needed
;* Entry Variables: None
;* Exit Variables: None 
;**************************************************************
B_update_devices:

; Update LEDs and TEC
			JSR		led_write		

; write to lcd template string
  			JSR		lcd_clear
			
			; set LCD cursor position
  			JSR		lcd_goto_row0 

			; write top row depending on state
			LDA		TEC_state
			CBEQA	#$01, B_update_devices_tec_heat
			CBEQA	#$02, B_update_devices_tec_cool 

B_update_devices_tec_hold:
			LDHX	#str_B_top_hold			
			BRA		B_update_devices_tec_write
						
B_update_devices_tec_heat:
			LDHX	#str_B_top_heat			
			BRA		B_update_devices_tec_write

B_update_devices_tec_cool:
			LDHX	#str_B_top_cool		
			BRA		B_update_devices_tec_write

B_update_devices_tec_write:
			LDA		#$10
			JSR		lcd_str
			
			; write LCD bottom row
			JSR		lcd_goto_row1
			LDHX	#str_B_bottom
			LDA		#$10
			JSR		lcd_str 
						
; write LM92 temp
			; set LCD cursor position
			LDA		#$C5
			JSR		lcd_goto_addr			
			JSR		lm92_write_lcd_C 	
						
; write Tset temp
			; set LCD cursor position
			LDA		#$8E
			JSR		lcd_goto_addr	
			
			; write upper number to LCD
			LDA		Tset
			LDHX	#$000A
			DIV						; A <= (H:A)/(X), H <= (remainder)
			JSR		lcd_num_to_char
			JSR		lcd_char

			; write upper number to LCD
			PSHH
			PULA
			JSR		lcd_num_to_char
			JSR		lcd_char			
  			
; write time

			; set LCD cursor position
			LDA		#$CB
			JSR		lcd_goto_addr
  			
  			; read time from RTC
  			JSR		rtc_get_time
			
			; calc and write TOD
			JSR		rtc_calc_tod
			JSR		rtc_write_tod
			
			BRA 	B_update_devices_done
			
B_update_devices_done:
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



