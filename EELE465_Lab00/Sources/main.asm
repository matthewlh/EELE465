;************************************************************** 
;* Program Name: Lab#00 - Heartbeat LED
;* Author Names: Matthew Handley 
;* Date: 2014-01-23
;* Description: Uses SUB_delay to wait 1 second, toggle an output
;*				pin (PortA[0]), then repeats. Intended to be 
;*				used to flash an led at 0.5 Hz, 50% duty.
;* 
;**************************************************************

; Include derivative-specific definitions
            INCLUDE 'derivative.inc'
            

; export symbols
            XDEF _Startup, main, SUB_delay
            ; we export both '_Startup' and 'main' as symbols. Either can
            ; be referenced in the linker .prm file or from C/C++ later on
            
            XREF __SEG_END_SSTACK   ; symbol defined by the linker for the end of the stack


; variable/data section
MY_ZEROPAGE: SECTION  SHORT         ; Insert here your data definition

			; counter for SUB_delay subroutine
			SUB_delay_cnt:		DS.B	3

; code section
MyCode:     SECTION
main:
_Startup:
            LDHX   #__SEG_END_SSTACK 	; initialize the stack pointer
            TXS
			CLI							; enable interrupts
			
			; init LED pin
			BSET 	PTADD_PTADD0,	PTADD		; Set PortA[0] to output 
			BSET 	PTAD_PTAD0,		PTAD		; Initialy set PortA[0] to high 

mainLoop:
            feed_watchdog
            		
			LDA		PTAD				; Load Accu A with the data bits for Port A
			COMA						; Complement the bits in Accu A
			AND		mPTAD_PTAD0			; Mask the value in Accu A with the bit for PortA[0]
			STA		PTAD				; Store the value in in Accu A back to the Port A Data register
			
			; load address of SUB_delay_cnt
			LDHX #SUB_delay_cnt
			
			; configure loop delays: 0x03CBFF = 2.000 second period
			LDA		#$03
			STA		2,X
			LDA		#$CB
			STA		1,X
			LDA		#$FF
			STA		0,X
			
			; jump to the delay loop
			JSR		SUB_delay
			
			; repeat forever
			BRA		mainLoop
			
;************************************************************** 
;* Subroutine Name: SUB_delay 
;* Description: Decrements SUB_delay_cnt until it reaches zero.
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
