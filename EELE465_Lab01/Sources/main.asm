;************************************************************** 
;* Program Name: Lab#01 - Keypad and time-varying patterns
;* Author Names: Matthew Handley 
;* Date: 2014-01-28
;* Description: Changes a time-varying pattern on 8 LEDs based
;*				on user input via the A, B, C, and D buttons on
;*				a 4x4 matrix keypad.
;* 
;**************************************************************

mDataBus		EQU	$F0		; Mask for the data bus pins on PortB
mAddrBus		EQU	$0F		; Mask for the address bus pins on PortB

; max index power each pattern
Seq_A_max_idx	EQU	$01
Seq_B_max_idx	EQU	$08
Seq_C_max_idx	EQU	$06
Seq_D_max_idx	EQU	$0A

; Include derivative-specific definitions
            INCLUDE 'derivative.inc'
            

; export symbols
            XDEF _Startup, main, _Vtpmovf, bus_write, bus_read, scan_keypad, led_write
            ; we export both '_Startup' and 'main' as symbols. Either can
            ; be referenced in the linker .prm file or from C/C++ later on
            
            
            
            XREF __SEG_END_SSTACK   ; symbol defined by the linker for the end of the stack


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			bus_addr:		DS.B	1	; only use lower 3 bits
			bus_data:		DS.B	1	; only use lower 4 bits
			keypad_data_0:	DS.B	1	; bit flags representing what keys are pressed on they 4x4 keypad
			keypad_data_1:	DS.B	1
			
			led_data:		DS.B	1	; 8 bit value for the 8 LEDs
			
			led_cur_pattern: 			DS.W	1	; the address of the current LED pattern
			led_cur_pattern_cur_step: 	DS.W	1	; the address of the current LED pattern
			led_cur_idx:				DS.B	1	; the offset index into the current pattern
			led_max_idx:				DS.B	1	; one more than the maximum value led_cur_idx will be before rolling back to zero
			
MY_CONST: SECTION
; Constant Values and Tables Section

	Seq_A: 	DC.B	%01010101	; 0

	Seq_B: 	
			DC.B	%11111110	; 0
			DC.B	%11111101	; 1
			DC.B	%11111011	; 2
			DC.B	%11110111	; 3
			DC.B	%11101111	; 4
			DC.B	%11011111	; 5
			DC.B	%10111111	; 6
			DC.B	%01111111	; 7

	Seq_C: 	DC.B	%00011000	; 0
			DC.B	%00100100	; 1
			DC.B	%01000010	; 2
			DC.B	%10000001	; 3
			DC.B	%01000010	; 4
			DC.B	%00100100	; 5

	Seq_D: 	DC.B	%00111100	; 0
			DC.B	%01111000	; 1
			DC.B	%11110000	; 2
			DC.B	%11100000	; 3
			DC.B	%11000000	; 4
			DC.B	%10000000	; 5
			DC.B	%11000000	; 6
			DC.B	%11100000	; 7
			DC.B	%11110000	; 8
			DC.B	%01111000	; 9
			
; code section
MyCode:     SECTION
main:
_Startup:
            LDHX   #__SEG_END_SSTACK ; initialize the stack pointer
            TXS
            
            ;*** init LED pin ***
			BSET 	PTADD_PTADD0,	PTADD		; Set PortA[0] to output 
			BSET 	PTAD_PTAD0,		PTAD		; Initialy set PortA[0] to high 
			
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
			
			;*** init the to pattern A for LEDs ***
			LDHX	#Seq_A
			STHX	led_cur_pattern
			
			LDA		#$00
			STA		led_cur_idx
			
			LDA		#Seq_A_max_idx
			STA		led_max_idx
            
			CLI			; enable interrupts

mainLoop:	; Do nothing forever, all work done via TPM interrupt.
           	NOP
           	
            feed_watchdog
            BRA    	mainLoop


;************************************************************** 
;* Subroutine Name: _Vtpmovf 
;* Description: Interrupt service routine for the TPM overflow
;*				interrupt. Toggles the heartbeat LED (PortA[0]) 
;*				and resets TPM overflow flag. Also scans the 
;*				keypad and updates the LED pattern based on 
;*				user's input on the keypad.
;*
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None 
;**************************************************************
_Vtpmovf:
			
;*** update LEDs with pattern ***
			; read keypad			
           	JSR		scan_keypad

			; take keypad input and update led_data			
           	JSR		keypad_to_led           	
           	
			; write new data to LEDs			
           	JSR		led_write
            
            
;*** Toggle Heartbeat LED ***

			; toggle LED
			LDA		PTAD				; Load Accu A with the data bits for Port A
			EOR		mPTAD_PTAD0			; Exclusive OR with bit mask for PortA[0], to toggle PortA[0]
			STA		PTAD				; Store the value in in Accu A back to the Port A Data register
			
			; clear TPM flag
			LDA		TPMSC				; read register
			AND		#$4E				; clear CH0F bit, but leave others alone
			STA		TPMSC				; write back register
			
			;Return from Interrupt
			RTI
			
;**************************************************************

;************************************************************** 
;* Subroutine Name: keypad_to_led 
;* Description: Checks keypad data to see if A, B, C, or D 
;*				buttons were pressed. If so, update pattern to 
;*				start of selected pattern. Else increments to 
;*				next step in current pattern.
;* 
;* Registers Modified: None
;* Entry Variables: keypad_data_0, keypad_data_1
;* Exit Variables: led_data
;**************************************************************
keypad_to_led:
			; preserve registers
			PSHA
			PSHH
			PSHX

;*** Check for button presses ***
			; check if button A pressed
			LDA		keypad_data_0		; load keypad row0:1 bits into A
			AND		#$08				; mask off bit for button A
			BNE		keypad_to_led_A		; if not zero, button A pressed 
			
			; check if button B pressed
			LDA		keypad_data_0		; load keypad row0:1 bits into B
			AND		#$80				; mask off bit for button B
			BNE		keypad_to_led_B		; if not zero, button B pressed 
			
			; check if button C pressed
			LDA		keypad_data_1		; load keypad row0:1 bits into D
			AND		#$08				; mask off bit for button D
			BNE		keypad_to_led_C		; if not zero, button C pressed 
			
			; check if button D pressed
			LDA		keypad_data_1		; load keypad row0:1 bits into D
			AND		#$80				; mask off bit for button D
			BNE		keypad_to_led_D		; if not zero, button D pressed
			
;*** no buttons pressed, so increment current pattern ***
			LDA		led_cur_idx			; load current pattern index
			INCA						; increment to the next index in the pattern
			
			; mod cur idx with max index, handles rollover of idx
			LDHX	#$0000
			LDX		led_max_idx
			DIV							; A <- (H:A)/(X); H <- remainder
			
			; transfer H (remainder) to A, via stack
			PSHH						
			PULA
			
			; store index back to var
			STA		led_cur_idx
			
;*** take led_cur_pattern + led_cur_idx and store to led_cur_pattern_cur_step ***
			; lower byte
			LDHX	#led_cur_pattern
			LDA		1,X
			ADD		led_cur_idx	
			LDHX	#led_cur_pattern_cur_step
			STA		1,X
			
			; upper byte
			LDHX	#led_cur_pattern
			LDA		0,X
			ADC		#$00	
			LDHX	#led_cur_pattern_cur_step
			STA		0,X
			
			; take value at led_cur_pattern_cur_step and copy to led_data
			LDHX	led_cur_pattern_cur_step
			LDA		0,X
			STA		led_data
			
			;done 
			BRA		keypad_to_led_done
				
			
keypad_to_led_A: 
;*** init pattern A ***
			; pattern start address
			LDHX	#Seq_A
			STHX	led_cur_pattern
			
			; pattern index
			LDA		#$00
			STA		led_cur_idx
			
			; pattern max index
			LDA		#Seq_A_max_idx
			STA		led_max_idx
			
			; led_data
			LDA		Seq_A
			STA		led_data
			
			;done 
			BRA		keypad_to_led_done
			
			
keypad_to_led_B: 
;*** init pattern B ***
			; pattern start address
			LDHX	#Seq_B
			STHX	led_cur_pattern
			
			; pattern index
			LDA		#$00
			STA		led_cur_idx
			
			; pattern max index
			LDA		#Seq_B_max_idx
			STA		led_max_idx
			
			; led_data
			LDA		Seq_B
			STA		led_data
			
			;done 
			BRA		keypad_to_led_done
			
			
keypad_to_led_C:
;*** init pattern C ***
			; pattern start address
			LDHX	#Seq_C
			STHX	led_cur_pattern
			
			; pattern index
			LDA		#$00
			STA		led_cur_idx
			
			; pattern max index
			LDA		#Seq_C_max_idx
			STA		led_max_idx
			
			; led_data
			LDA		Seq_C
			STA		led_data
			
			;done 
			BRA		keypad_to_led_done 
			
			
keypad_to_led_D:
;*** init pattern D ***
			; pattern start address
			LDHX	#Seq_D
			STHX	led_cur_pattern
			
			; pattern index
			LDA		#$00
			STA		led_cur_idx
			
			; pattern max index
			LDA		#Seq_D_max_idx
			STA		led_max_idx
			
			; led_data
			LDA		Seq_D
			STA		led_data
			
			;done 
			;BRA		keypad_to_led_done 
	
	
keypad_to_led_done:
			; restore registers
			PULX
			PULH
			PULA
			
			; return from subroutine bus_read
			RTS
;**************************************************************

;************************************************************** 
;* Subroutine Name: led_write 
;* Description: Writes the 8 bits of led_data two the 8 LEDs
;* 				on the DFFs at address 0 and 1 on the bus
;* 
;* Registers Modified: None
;* Entry Variables: led_data
;* Exit Variables: None
;**************************************************************
led_write:
			; preserve accumulator A
			PSHA

;*** write lower nibble LEDs ***
			; set the address
            LDA 	#$00
            STA		bus_addr
            
            ; set the data
            LDA 	led_data
            AND		#$0F
            STA		bus_data
            
            ; write the data
            JSR		bus_write

;*** write upper nibble LEDs ***
			; set the address
            LDA 	#$01
            STA		bus_addr
            
            ; set the data
            LDA 	led_data
            LSRA
            LSRA
            LSRA
            LSRA
            AND		#$0F
            STA		bus_data
            
            ; write the data
            JSR		bus_write
			
;*** done ***
			; restore accumulator A
			PULA			
			RTS


;**************************************************************

;************************************************************** 
;* Subroutine Name: bus_read 
;* Description: Reads data from the device whose address is
;*				the lower 3 bits of bus_addr, and store the
;*				data to the lower 4 bits of bus_data.
;* 
;* Registers Modified: None
;* Entry Variables: bus_addr
;* Exit Variables: bus_data
;**************************************************************
bus_read:
			; preserve accumulator A
			PSHA

			; make address bus output, data bus an input
            LDA		#mAddrBus
            STA		PTBDD
            
			; pull the address low
            LDA 	bus_addr			; load address
            AND		#$07				; mask off the lower 3 bits to be sure, will leave G2A low
            STA		PTBD				; write data to address bus, and clear data bus
            
            ; read data from the bus
            LDA		PTBD
            LSRA						; shift data down to the lower 4 bits
            LSRA
            LSRA
            LSRA
            AND		#$0F				; mask off the lower 4 bits to be sure
            STA		bus_data			; 
            
			; pull the address high
            LDA 	#$08				; G2A_not high
            STA		PTBD				; write, clears address bus
            
			; restore accumulator A
			PULA
			
			; return from subroutine bus_read
			RTS

;**************************************************************


;************************************************************** 
;* Subroutine Name: bus_write 
;* Description: Writes the lower 4 bits of bus_data to the 
;*				device on whose address is the lower 3 bits
;* 				of bus_addr. 
;* Registers Modified: None
;* Entry Variables: bus_addr, bus_data
;* Exit Variables: None 
;**************************************************************
bus_write:
			; preserve accumulator A
			PSHA			
			
			; make data and address busses outputs
            LDA		#$FF
            STA		PTBDD
            
            ; prep data for the bus
            LDA		bus_data
            LSLA						; shift the lower 4 bits to be the upper 4 bits
            LSLA
            LSLA
            LSLA
            AND		#$F0				; mask off the upper 4 bits to be sure
            
			; prep the addr, G2A_not low, Yx goes low
            ORA		bus_addr 			; add in the address
            STA		PTBD				; write data and address bus, with G2A_not low         
            
            ORA		#$08				; leave data and address, set G2A_not high - Yx goes high
            STA		PTBD
            
			; restore accumulator A
			PULA
			
			; return from subroutine bus_write
			RTS

;**************************************************************


;************************************************************** 
;* Subroutine Name: scan_keypad 
;* Description: Scans the greyhill 4x4 keypad, and saves the 
;*				result to variable.
;*				Note that this method will overwrite values in 
;*				the bus_addr and bus_data variables.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: keypad_data_0, keypad_data_1
;**************************************************************
scan_keypad:
			; preserve registers
			PSHA
			PSHH
			PSHX

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
			PULX
			PULH
			PULA
			
			; return from subroutine bus_read
			RTS

;**************************************************************
