;************************************************************** 
;* Program Name: Lab#00 - Heartbeat LED
;* Author Names: Matthew Handley 
;* Date: 2014-01-23
;* Description: Uses TPM to wait 1 second, toggle an output
;*				pin (PortA[0]), then repeats. Intended to be 
;*				used to flash an led at 0.5 Hz, 50% duty.
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
MY_ZEROPAGE: SECTION  SHORT         ; Insert here your data definition

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
			LDA 	#$4E					; TOIE clear, CLKS: Bus clock, Prescale: 128
			STA		TPMSC
            
			CLI			; enable interrupts

mainLoop:
            ; Infinite loop of nothing, all work done by interrupts
            NOP

            feed_watchdog
            BRA    mainLoop

;************************************************************** 
;* Subroutine Name: _Vtpmovf 
;* Description: Interrupt service routine for the TPM overflow
;*				interrupt. Toggles PortA[0] and resets TPM
;*				overflow flag.
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None 
;**************************************************************
_Vtpmovf:
			; toggle LED
			LDA		PTAD				; Load Accu A with the data bits for Port A
			EOR		mPTAD_PTAD0			; Eclusive OR with bit mask for PortA[0], to toggle PortA[0]
			STA		PTAD				; Store the value in in Accu A back to the Port A Data register
			
			; clear TPM ch0 flag
			LDA		TPMSC				; read register
			AND		#$4E				; clear CH0F bit, but leav others alone
			STA		TPMSC				; write back register
			
			;Return from Interrupt
			RTI
			
;**************************************************************
