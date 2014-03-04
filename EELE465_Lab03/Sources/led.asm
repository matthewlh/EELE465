;************************************************************** 
;* File Name    : 	led.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-04
;* Description  : 	Contains subroutines for controlling the
;*					DFF-driven LEDs.
;*
;**************************************************************

; EQU statements


; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF led_write, led_data
            
; import symbols
			XREF bus_read, bus_write, bus_addr, bus_data  


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			led_data:		DS.B	1	; 8 bit value for the 8 LEDs

; code section
MyCode:     SECTION

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
            NSA
            AND		#$0F
            STA		bus_data
            
            ; write the data
            JSR		bus_write
			
;*** done ***
			; restore accumulator A
			PULA			
			RTS


;**************************************************************
