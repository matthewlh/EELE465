;************************************************************** 
;* Program Name: Lab#00 - Heartbeat LED
;* Author Names: Matthew Handley 
;* Date: 2014-01-23
;* Description: Uses TPM interrupt with prescaler of 1 to 
;*				decrement a counter variable. When the counter
;*				reaches zero, an output pin (PortA[0]) is toggled, 
;*				then repeats. Intended to be used to flash an 
;*				led at 0.5 Hz, 50% duty.
;* 
;**************************************************************

; Include derivative-specific definitions
            INCLUDE 'derivative.inc'
            
; export symbols
            XDEF _Startup, main, _Vtpmovf
            ; we export both '_Startup' and 'main' as symbols. Either can
            ; be referenced in the linker .prm file or from C/C++ later on

            XREF __SEG_END_SSTACK   ; symbol defined by the linker for the end of the stack

; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			counter:	DS.B	1

; code section
MyCode:     SECTION
main:
_Startup:
            LDHX   #__SEG_END_SSTACK ; initialize the stack pointer
            TXS
            
			;*** init LED pin ***
			BSET 	PTADD_PTADD0,	PTADD		; Set PortA[0] to output 
			BSET 	PTAD_PTAD0,		PTAD		; Initialy set PortA[0] to high 
			
			;*** init TPM module ***
			; TPMMODH:L Registers 
			LDA 	#$00
			STA		TPMMODH
			LDA 	#$00 
			STA		TPMMODL
			; TPMSC Register 
			LDA 	#$48					; TOIE set, CLKS: Bus clock, Prescale: 1
			STA		TPMSC
			
			; init counter
			LDA		#$3D					; $3D corresponds to 1 second worth of TPM TOF's
			STA		counter
            
			CLI			; enable interrupts
mainLoop:
            ; Infinite loop of nothing, all work done by interrupts
            NOP

            feed_watchdog
            BRA    mainLoop

;************************************************************** 
;* Subroutine Name: _Vtpmovf 
;* Description: Interrupt service routine for the TPM overflow
;*				interrupt. Derements counter, if counter is 
;*				zero, Toggles PortA[0], resets counter, them 
;*				resets TPM overflow flag.
;* Registers Modified: None
;* Entry Variables: counter - decremented and compared to zero.
;* Exit Variables: 	counter - decremented and compared to zero.
;**************************************************************
_Vtpmovf:
			; decrement counter
			LDA		counter
			DECA
			STA		counter
			
			; if counter != 0, we're done
			BNE 	_Vtpmovf_done
			
			;else, reset counter and toggle LED
			LDA		#$3D				; $3D corresponds to 1 second worth of TPM TOF's
			STA		counter
			
			; toggle LED
			LDA		PTAD				; Load Accu A with the data bits for Port A
			EOR		mPTAD_PTAD0			; Eclusive OR with bit mask for PortA[0], to toggle PortA[0]
			STA		PTAD				; Store the value in in Accu A back to the Port A Data register
						
_Vtpmovf_done:
			; clear TPM ch0 flag
			LDA		TPMSC				; read register
			AND		#$4E				; clear CH0F bit, but leav others alone
			STA		TPMSC				; write back register
			
;**************************************************************
