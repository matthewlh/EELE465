;************************************************************** 
;* File Name    : 	adc.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-04
;* Description  : 	Contains subroutines for controlling the
;*					adc.
;*
;**************************************************************

; EQU statements

ADCS1_CH2		EQU %00000010	;ADCS1 configured for CH2
ADCS1_CH26		EQU %00011010	;ADCS1 configured for CH26 (internal temp. sensor) 


; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF adc_init, adc_read_ch26_avg, adc_read_ch2_avg, adc_read_avg
            XDEF adc_data_0, adc_data_1
            
; import symbols
			XREF SUB_delay, SUB_delay_cnt
			XREF bus_read, bus_write, bus_addr, bus_data


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			adc_data_0:			DS.B	1	; upper 8 bits from ADC read
			adc_data_1:			DS.B	1	; lower 8 bits from ADC read  
			
			adc_num_samples:			DS.B	1	; number of samples to take and average together
			adc_num_samples_remaining:	DS.B	1	; number of samples to be taken
			
; code section
MyCode:     SECTION

;************************************************************** 
;* Subroutine Name: adc_init  
;* Description: Initilizes the ADC module.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
adc_init: 
			; preserve registers
			PSHA
			
			;*** init ADC ***
			LDA		#ADCS1_CH2		;AIEN=0, ADCO=0, ADCH=2
			STA		ADCSC1
			LDA		#$00			;ADTRG=0, ACFE=0, ACFGT=0
			STA		ADCSC2
			LDA		#%00001000		;ADLPC=0, ADIV=00, ADLSMP=0, MODE=10-bit, ADICLK=00
			STA		ADCCFG
			LDA		#$04			;ADPC2=1
			STA		APCTL1
			

			; restore registers
			PULA		
			
			; done
			RTS
			
;**************************************************************


;************************************************************** 
;* Subroutine Name: adc_read_ch26_avg
;* Description: Reads and averages ADC CH2.
;* 
;* Registers Modified: Accu A
;* Entry Variables: Accu A - number of samples to take
;* Exit Variables: Accu A - ADC counts averaged
;**************************************************************
adc_read_ch26_avg: 

			; store input
			STA		adc_num_samples

			; setup ADC for internal temp sensor
			LDA		#ADCS1_CH26		;AIEN=0, ADCO=0, ADCH=26
			STA		ADCSC1
			
			; read the selected channel n times
			JSR		adc_read_avg			
			
			; done
			RTS

;**************************************************************


;************************************************************** 
;* Subroutine Name: adc_read_ch2_avg
;* Description: Reads and averages ADC CH2.
;* 
;* Registers Modified: Accu A
;* Entry Variables: Accu A - number of samples to take
;* Exit Variables: Accu A - ADC counts averaged
;**************************************************************
adc_read_ch2_avg: 

			; store input
			STA		adc_num_samples

			; setup ADC for internal temp sensor
			LDA		#ADCS1_CH2		;AIEN=0, ADCO=0, ADCH=2
			STA		ADCSC1
			
			; read the selected channel n times
			JSR		adc_read_avg			
			
			; done
			RTS

;**************************************************************


;************************************************************** 
;* Subroutine Name: adc_read_avg
;* Description: Reads and sums whatever the current ADC 
;*				channel is.
;* 
;* Registers Modified: Accu A
;* Entry Variables: adc_num_samples - number of samples to 
;*					take and sum.
;* Exit Variables: adc_data_0:adc_data_1 - sum of all samples
;**************************************************************
adc_read_avg: 
			; clear adc_data
			LDA		#$00
			STA		adc_data_0
			STA		adc_data_1

			; load Accu A for loop counter 
			LDA		adc_num_samples
			STA		adc_num_samples_remaining
			
adc_read_avg_measure:

			; start ADC conversion
			LDA		ADCSC1
			STA		ADCSC1
			
			
adc_read_avg_loop_conversion:

			; CoCo flag set?
			LDA		ADCSC1
			AND		mADCSC1_COCO
			BEQ		adc_read_avg_loop_conversion
			
			
			; add the sample to adc_data
			LDA		ADCRL
			ADD		adc_data_1
			STA		adc_data_1
			
			LDA		ADCRH
			ADC		adc_data_0
			STA		adc_data_0			
			
			; decrement adc_num_samples_remaining
			LDA 	adc_num_samples_remaining
			DECA
			STA		adc_num_samples_remaining
			
			; more samples remaining ?
			BNE		adc_read_avg_measure		
			
			; done
			RTS
				

;************************************************************** 


