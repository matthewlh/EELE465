;************************************************************** 
;* File Name    : 	math.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-04
;* Description  : 	Contains subroutines for math operations
;*					that can not be done with the 8-bit 
;*					commands of the S08.
;*					
;*					Based on Freescale AN1219
;*
;**************************************************************

; EQU statements


; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF math_mul_16, math_div_32
            XDEF INTACC1, INTACC2
            
; import symbols
			


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			INTACC1:			DS.B	4	; 32-bit INT accumulator 1
			INTACC2:			DS.B	4	; 32-bit INT accumulator 2  
			
			
; code section
MyCode:     SECTION

;************************************************************** 
;* Subroutine Name: math_mul_16  
;* Description: Performs a 16x16 bit multiplication of 
;*				INTACC1 and INTACC2
;* 
;* Registers Modified: None
;* Entry Variables: INTACC1, INTACC2
;* Exit Variables: INTACC19
;**************************************************************
math_mul_16: 

;*** preserve registers
			PSHA
			PSHX
			PSHH
			
			; reserve 6 bytes on the stack and zero
			AIS		#-6
			CLR		6, SP
			
;*** Multiply (INTACC1:INTACC1+1) by math_intacc2+1

			LDX 	INTACC1+1 	;load x-reg w/multiplier LSB
			LDA 	INTACC2+1 	;load acc w/multiplicand LSB
			MUL 				;multiply
			STX 	6, SP 		;save carry from multiply
			STA 	INTACC1+3 	;store LSB of final result
			LDX 	INTACC1 	;load x-reg w/multiplier MSB
			LDA 	INTACC2+1 	;load acc w/multiplicand LSB
			MUL 				;multiply
			ADD 	6,SP 		;add carry from previous multiply
			STA 	2,SP 		;store 2nd byte of interm. result 1.
			BCC 	NOINCA 		;check for carry from addition
			INCX 				;increment MSB of interm. result 1. 
NOINCA:
			STX 	1,SP 		;store MSB of interm. result 1.
			CLR 	6,SP 		;clear storage for carry
			

;*** Multiply (INTACC1:INTACC1+1) by math_intacc2

			LDX 	INTACC1+1 	;load x-reg w/multiplier LSB
			LDA 	INTACC2 	;load acc w/multiplicand MSB
			MUL 				;multiply
			STX 	6,SP 		;save carry from multiply
			STA 	5,SP 		;store LSB of interm. result 2.
			LDX 	INTACC1 	;load x-reg w/multiplier MSB
			LDA 	INTACC2 	;load acc w/multiplicand MSB
			MUL 				;multiply
			ADD 	6,SP 		;add carry from previous multiply
			STA 	4,SP 		;store 2nd byte of interm. result 2.
			BCC 	NOINCB 		;check for carry from addition
			INCX 				;increment MSB of interm. result 2. 
NOINCB:
			STX 	3,SP 		;store MSB of interm. result 2.

;*** Add the intermediate results and store the remaining three bytes 
;*** of the final value in locations INTACC1:INTACC1+2.

			LDA 	2,SP 		;load acc with 2nd byte of 1st result
			ADD 	5,SP 		;add acc with LSB of 2nd result
			STA 	INTACC1+2 	;store 2nd byte of final result
			LDA 	1,SP 		;load acc with MSB of 1st result
			ADC 	4,SP 		;add w/ carry 2nd byte of 2nd result
			STA 	INTACC1+1 	;store 3rd byte of final result
			LDA 	3,SP 		;load acc with MSB from 2nd result
			ADC 	#0 			;add any carry from previous addition
			STA 	INTACC1 	;store MSB of final result

;*** restore registers and stack pointer

			AIS		#6
			
			PULH
			PULX
			PULA
			RTS

;**************************************************************

;************************************************************** 
;* Subroutine Name: math_div_32  
;* Description: Performs a 32x16 bit division of  
;*				INTACC1 by INTACC2
;* 
;* Registers Modified: None
;* Entry Variables: INTACC1, INTACC1
;* Exit Variables: INTACC2
;**************************************************************
math_div_32:

DIVIDEND 	EQU INTACC1+2
DIVISOR 	EQU INTACC2
QUOTIENT 	EQU INTACC1
REMAINDER 	EQU INTACC1

;*** preserve registers
			PSHA
			PSHX
			PSHH
			
			; reserve 3 bytes on the stack and zero
			AIS #-3 			;reserve three bytes of temp storage
			LDA #!32 			;
			STA 3,SP 			;loop counter for number of shifts
			LDA DIVISOR 		;get divisor MSB
			STA 1,SP 			;put divisor MSB in working storage
			LDA DIVISOR+1 		;get divisor LSB
			STA 2,SP 			;put divisor LSB in working storage
*
* Shift all four bytes of dividend 16 bits to the right and clear
* both bytes of the temporary remainder location
*
			
			LDA 	DIVIDEND+1 	;shift dividend LSB
			STA		DIVIDEND+3
			LDA 	DIVIDEND 	;shift 2nd byte of dividend
			STA		DIVIDEND+2
			LDA 	DIVIDEND-1 	;shift 3rd byte of dividend
			STA		DIVIDEND+1
			LDA 	DIVIDEND-2 	;shift dividend MSB
			STA		DIVIDEND
			LDA		#$00
			STA 	REMAINDER 	;zero remainder MSB
			STA 	REMAINDER+1 ;zero remainder LSB
			
*
* Shift each byte of dividend and remainder one bit to the left
*
SHFTLP:
			LDA 	REMAINDER 		;get remainder MSB
			ROLA 					;shift remainder MSB into carry
			
			LDA 	DIVIDEND+3 		;shift dividend LSB
			ROLA
			STA		DIVIDEND+3
			
			LDA 	DIVIDEND+2 	;shift 2nd byte of dividend
			ROLA
			STA		DIVIDEND+2
			
			LDA 	DIVIDEND+1 	;shift 3rd byte of dividend
			ROLA	
			STA		DIVIDEND+1
			
			LDA 	DIVIDEND 		;shift dividend MSB
			ROLA
			STA		DIVIDEND
			
			LDA 	REMAINDER+1 	;shift remainder LSB
			ROLA
			STA		REMAINDER+1 
			
			LDA 	REMAINDER 		;shift remainder MSB
			ROLA
			STA		REMAINDER 
*			
* Subtract both bytes of the divisor from the remainder
*
			LDA 	REMAINDER+1 ;get remainder LSB
			SUB 	2,SP 		;subtract divisor LSB from remainder LSB
			STA 	REMAINDER+1 ;store new remainder LSB
			LDA 	REMAINDER 	;get remainder MSB
			SBC 	1,SP 		;subtract divisor MSB from remainder MSB
			STA 	REMAINDER 	;store new remainder MSB
			LDA 	DIVIDEND+3 	;get low byte of dividend/quotient
			SBC 	#0 			;dividend low bit holds subtract carry
			STA 	DIVIDEND+3 	;store low byte of dividend/quotient
*
* Check dividend/quotient LSB. If clear, set LSB of quotient to indicate
* successful subraction, else add both bytes of divisor back to remainder
*
			BRCLR 	0,DIVIDEND+3,SETLSB 	;check for a carry from subtraction and add divisor to remainder if set
			LDA 	REMAINDER+1 	;get remainder LSB
			ADD 	2,SP 			;add divisor LSB to remainder LSB
			STA 	REMAINDER+1 	;store remainder LSB
			LDA 	REMAINDER 		;get remainder MSB
			ADC 	1,SP 			;add divisor MSB to remainder MSB
			STA 	REMAINDER 		;store remainder MSB
			LDA 	DIVIDEND+3 		;get low byte of dividend
			ADC 	#0 				;add carry to low bit of dividend
			STA 	DIVIDEND+3 		;store low byte of dividend
			BRA 	DECRMT 			;do next shift and subtract
SETLSB:		BSET 	0,DIVIDEND+3 	;set LSB of quotient to indicate successive subtraction
DECRMT:		DBNZ 	3,SP,SHFTLP 	;decrement loop counter and do next shift
*
* Move 32-bit dividend into INTACC1:INTACC1+3 and put 16-bit
* remainder in INTACC2:INTACC2+1
*
			LDA 	REMAINDER 	;get remainder MSB
			STA 	1,SP 		;temporarily store remainder MSB
			LDA 	REMAINDER+1 ;get remainder LSB
			STA 	2,SP 		;temporarily store remainder LSB
			MOV 	DIVIDEND,QUOTIENT 		;
			MOV 	DIVIDEND+1,QUOTIENT+1 	;shift all four bytes of quotient
			MOV 	DIVIDEND+2,QUOTIENT+2 	; 16 bits to the left
			MOV 	DIVIDEND+3,QUOTIENT+3 	;
			LDA 	1,SP 		;get final remainder MSB
			STA 	INTACC2 	;store final remainder MSB
			LDA 	2,SP 		;get final remainder LSB
			STA 	INTACC2+1 	;store final remainder LSB
*
* Deallocate local storage, restore register values, and return from
* subroutine
*
			AIS #3 	;deallocate temporary storage
			PULX 	;restore x-reg value
			PULA 	;restore accumulator value
			PULH 	;restore h-reg value
			RTS 	;return

;**************************************************************
