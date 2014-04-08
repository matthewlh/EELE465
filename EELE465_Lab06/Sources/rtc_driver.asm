;************************************************************** 
;* File Name    : 	rtc_driver.asm
;* Author Names : 	Matthew Handley 
;* Date         : 	2014-03-27
;* Description  : 	Contains subroutines talking to a DS1337
;*					Real Time Clock, using i2c_driver.asm
;*
;**************************************************************

; EQU statements

RTC_ADDR_W 		EQU $D0 	; Slave address to write to RTC
RTC_ADDR_R 		EQU $D1 	; Slave address to read from RTC
RTC_REG_SEC		EQU	$00		; register address of the seconds register

; Include derivative-specific definitions
            INCLUDE 'MC9S08QG8.inc'
            
; export symbols
            XDEF rtc_init, rtc_set_time_zero, rtc_calc_tod, rtc_write_tod, rtc_set_time, rtc_get_time, rtc_display_data, rtc_prompt_time
            XDEF Sec, Min, Hour, Date, Month, Year
            
; import symbols
			XREF i2c_init, i2c_start, i2c_stop, i2c_tx_byte, i2c_rx_byte
			
			XREF lcd_init, lcd_write, lcd_char, lcd_str, lcd_num_to_char, lcd_clear, lcd_goto_addr, lcd_goto_row0, lcd_goto_row1 
            XREF lcd_data, lcd_char_data, lcd_col_idx
            
            XREF keypad_get_keypress


; variable/data section
MY_ZEROPAGE: SECTION  SHORT

			Sec:				DS.B	2		; normally holds last time read from RTC, 
			Min:				DS.B	2		; written to prior to calling rtc_set_time
			Hour:				DS.B	2
			Date:				DS.B	2
			Month:				DS.B	2
			Year:				DS.B	2
						
			TOD:				DS.B	2		; time of day in seconds since midnight
			
			rtc_epoch_delta:	DS.B	2
			
			Byte_counter:		DS.B	1

MY_CONST: SECTION
; Constant Values and Tables Section
			
			str_date:			DC.B 	"Date is "	
			str_date_length:	DC.B	8
			str_time:			DC.B 	"Time is "	
			str_time_length:	DC.B	8
			
			str_prompt_row0:			DC.B 	"Set   : MM/DD/YY"	
			str_prompt_row0_length:		DC.B	16
			str_prompt_row1:			DC.B 	"Clock : HH:MM:SS"	
			str_prompt_row1_length:		DC.B	16
			
			
; code section
MyCode:     SECTION

;************************************************************** 
;* Subroutine Name: rtc_init  
;* Description: Initilizes the RTC driver.
;* 
;* Registers Modified: None
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
rtc_init:	
			; set rtc
			JSR		rtc_set_time_zero
						
			RTS

;**************************************************************


;************************************************************** 
;* Subroutine Name: rtc_set_time_zero  
;* Description: Sets the RTC to time zero
;* 
;* Registers Modified: A, X
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
rtc_set_time_zero:

			MOV		#$00, Sec+0
			MOV		#$00, Sec+1
			
			MOV		#$00, Min+0			
			MOV		#$00, Min+1
			
			MOV		#$00, Hour+0
			MOV		#$00, Hour+1
			
			MOV		#$00, Date+0
			MOV		#$01, Date+1
			
			MOV		#$00, Month+0
			MOV		#$01, Month+1
			
			MOV		#$00, Year+0
			MOV		#$01, Year+1
			
			JSR		rtc_set_time

			;done
			RTS

;**************************************************************


;************************************************************** 
;* Subroutine Name: rtc_calc_tod
;* Description: 
;* 
;* Registers Modified: A, X
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
rtc_calc_tod:

			; clear TOD var
			MOV		#$00, TOD+0
			MOV		#$00, TOD+1
			
;*** calculate seconds
			LDA		Sec+1
			STA		TOD+1
			
			LDA		Sec+0
			LDX		#$0A
			MUL						; X:A <= (X) * (A)
			ADD		TOD+1
			STA		TOD+1
			
			PSHX
			PULA
			ADC		TOD+0
			STA		TOD+0
			
;*** calculate minutes
			LDA		Min+1
			LDX		#$3C 			; 0x3C = 60
			MUL						; X:A <= (X) * (A)
			
			; add lower byte of result
			ADD		TOD+1
			STA		TOD+1
			
			; add upper byte of result
			PSHX
			PULA
			ADC		TOD+0
			STA		TOD+0

			;done
			RTS

;**************************************************************


;************************************************************** 
;* Subroutine Name: rtc_write_tod
;* Description: 
;* 
;* Registers Modified: A, X
;* Entry Variables: None
;* Exit Variables: rtc_delta
;**************************************************************
rtc_write_tod:
			

;*** write upper number to LCD
			LDHX	TOD+0
			LDX		#$64
			LDA		TOD+1			
			DIV						; A <= (H:A)/(X), H <= (remainder)

			; convert to ASCII char
			JSR		lcd_num_to_char

			; write to LCD
			JSR		lcd_char

;*** write middle number to LCD
			PSHH
			PULA

			LDHX	#$000A
			DIV						; A <= (H:A)/(X), H <= (remainder)
			
			; convert to ASCII char
			JSR		lcd_num_to_char

			; write to LCD
			JSR		lcd_char		
			

;*** write lower number to LCD
			PSHH
			PULA

			; convert to ASCII char
			JSR		lcd_num_to_char

			; write to LCD
			JSR		lcd_char			
			
			; done
			RTS
			
;**************************************************************


;************************************************************** 
;* Subroutine Name: rtc_set_time  
;* Description: Set the RTC with the current time in the Sec, 
;*				Min, etc var values
;* 
;* Registers Modified: Accu A
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
rtc_set_time:

			; start condition
			JSR		i2c_start
			
			; send rtc write addr
			LDA		#RTC_ADDR_W
			JSR 	i2c_tx_byte
			
			; send register address
			LDA		#RTC_REG_SEC
			JSR 	i2c_tx_byte
			
			; send seconds data
			LDA		Sec+0
			NSA
			AND		#$70
			ORA		Sec+1
			JSR 	i2c_tx_byte
			
			; send minutes data
			LDA		Min+0
			NSA
			AND		#$70
			ORA		Min+1
			JSR 	i2c_tx_byte
			
			; send hours data
			LDA		Hour+0
			NSA
			AND		#$30
			ORA		Hour+1
			JSR 	i2c_tx_byte
			
			; send day of week (not used)
			LDA		#$01
			JSR 	i2c_tx_byte
			
			; send date data
			LDA		Date+0
			NSA
			AND		#$30
			ORA		Date+1
			JSR 	i2c_tx_byte
			
			; send month data
			LDA		Month+0
			NSA
			AND		#$10
			ORA		#$80		; set century bit
			ORA		Month+1
			JSR 	i2c_tx_byte
			
			; send year data
			LDA		Year+0
			NSA
			AND		#$F0
			ORA		Year+1
			JSR 	i2c_tx_byte
			
			; send stop condition
			JSR		i2c_stop
			


;**************************************************************


;************************************************************** 
;* Subroutine Name: rtc_get_time  
;* Description: Get the RTC time and save to vars
;* 
;* Registers Modified: Accu A
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
rtc_get_time:

			; start condition
			JSR		i2c_start
			
			; send rtc write addr
			LDA		#RTC_ADDR_W
			JSR 	i2c_tx_byte
			
			; send register address
			LDA		#RTC_REG_SEC
			JSR 	i2c_tx_byte
			
			; stop condition
			JSR		i2c_stop
			

			; set byte counter to 6
			MOV		#$06, Byte_counter

			; start condition
			JSR		i2c_start
			
			; send rtc read addr
			LDA		#RTC_ADDR_R
			JSR 	i2c_tx_byte
			
			; read seconds data
			LDA		#$01			; ack the byte			
			JSR		i2c_rx_byte			
			STA		Sec+1
			NSA
			STA		Sec+0
			
			; read minutes data
			LDA		#$01			; ack the byte			
			JSR		i2c_rx_byte			
			STA		Min+1
			NSA
			STA		Min+0
			
			; read hours data
			LDA		#$01			; ack the byte			
			JSR		i2c_rx_byte			
			STA		Hour+1
			NSA
			STA		Hour+0
			
			; read day of week data
			LDA		#$01			; ack the byte			
			JSR		i2c_rx_byte	
			; we don't care about this
			
			; read date data
			LDA		#$01			; ack the byte			
			JSR		i2c_rx_byte			
			STA		Date+1
			NSA
			STA		Date+0
			
			; read month data
			LDA		#$01			; ack the byte			
			JSR		i2c_rx_byte			
			STA		Month+1
			NSA
			STA		Month+0
			
			; read Year data
			LDA		#$00			; nack the byte			
			JSR		i2c_rx_byte			
			STA		Year+1
			NSA
			STA		Year+0
			
			; stop condition
			JSR		i2c_stop
			
			; mask off the recieved data
			JSR		rtc_mask_data

			RTS


;**************************************************************


;************************************************************** 
;* Subroutine Name: rtc_display_data  
;* Description: Takes the data in the Sec, Min, etc vars and 
;*				writes it to the lcd.
;* 
;* Registers Modified: Accu A
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
rtc_display_data:

			; clear the lcd
			JSR 	lcd_clear
			
			; goto top row
			JSR		lcd_goto_row0
			
			; write header
			LDHX	#str_date
			LDA		str_date_length
			JSR		lcd_str
			
			; write month
			LDA		Month+0
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			LDA		Month+1
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			; write '/'
			LDA		#'/'
			JSR		lcd_char
			
			; write Date
			LDA		Date+0
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			LDA		Date+1
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			; write '/'
			LDA		#'/'
			JSR		lcd_char
			
			; write Year
			LDA		Year+0
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			LDA		Year+1
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			; goto second row on lcd
			JSR		lcd_goto_row1
			
			; write header
			LDHX	#str_time
			LDA		str_time_length
			JSR		lcd_str
			
			; write hour
			LDA		Hour+0
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			LDA		Hour+1
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			; write ':'
			LDA		#':'
			JSR		lcd_char
			
			; write minute
			LDA		Min+0
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			LDA		Min+1
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			; write ':'
			LDA		#':'
			JSR		lcd_char
			
			; write minute
			LDA		Sec+0
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			LDA		Sec+1
			JSR		lcd_num_to_char
			JSR		lcd_char
			
			; done
			RTS
			

			
;**************************************************************

;************************************************************** 
;* Subroutine Name: rtc_mask_data  
;* Description: Takes the raw register values recieved in the 
;*				Sec, Min, etc vars and masks off the data we 
;*				want.
;* 
;* Registers Modified: Accu A
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
rtc_mask_data:

			; Seconds
			LDA		Sec+0
			AND		#$07
			STA		Sec+0
			
			LDA		Sec+1
			AND		#$0F
			STA		Sec+1

			; Minutes
			LDA		Min+0
			AND		#$07
			STA		Min+0
			
			LDA		Min+1
			AND		#$0F
			STA		Min+1

			; Hours
			LDA		Hour+0
			AND		#$03
			STA		Hour+0
			
			LDA		Hour+1
			AND		#$0F
			STA		Hour+1

			; Date
			LDA		Date+0
			AND		#$03
			STA		Date+0
			
			LDA		Date+1
			AND		#$0F
			STA		Date+1

			; Month
			LDA		Month+0
			AND		#$01
			STA		Month+0
			
			LDA		Month+1
			AND		#$0F
			STA		Month+1

			; Year
			LDA		Year+0
			AND		#$0F
			STA		Year+0
			
			LDA		Year+1
			AND		#$0F
			STA		Year+1
			
			; done
			RTS


;**************************************************************


;************************************************************** 
;* Subroutine Name: rtc_prompt_time  
;* Description: Prompts the user to enter a date and time on  
;*				the LCD with the keypad, and saves the 
;*				user-entered time into the Sec, Min, etc vars.
;* 
;* Registers Modified: Accu A
;* Entry Variables: None
;* Exit Variables: None
;**************************************************************
rtc_prompt_time:

;*** write promt to display

			; clear the lcd
			JSR 	lcd_clear
			
			; goto top row
			JSR		lcd_goto_row0
			
			; write header
			LDHX	#str_prompt_row0
			LDA		str_prompt_row0_length
			JSR		lcd_str
			
			; goto bottom row
			JSR		lcd_goto_row1
			
			; write header
			LDHX	#str_prompt_row1
			LDA		str_prompt_row1_length
			JSR		lcd_str
			
			; goto MM address
			LDA		#$88
			JSR		lcd_goto_addr
			
			; prompt for Month+0
			JSR		keypad_get_keypress
			STA		Month+0
			
			; prompt for Month+1
			JSR		keypad_get_keypress
			STA		Month+1
			
			; goto DD address
			LDA		#$8B
			JSR		lcd_goto_addr
			
			; prompt for Date+0
			JSR		keypad_get_keypress
			STA		Date+0
			
			; prompt for Date+1
			JSR		keypad_get_keypress
			STA		Date+1
			
			; goto YY address
			LDA		#$8E
			JSR		lcd_goto_addr
			
			; prompt for Year+0
			JSR		keypad_get_keypress
			STA		Year+0
			
			; prompt for Year+1
			JSR		keypad_get_keypress
			STA		Year+1
			
			; goto HH address
			LDA		#$C8
			JSR		lcd_goto_addr
			
			; prompt for Hour+0
			JSR		keypad_get_keypress
			STA		Hour+0
			
			; prompt for Hour+1
			JSR		keypad_get_keypress
			STA		Hour+1
			
			; goto MM address
			LDA		#$CB
			JSR		lcd_goto_addr
			
			; prompt for Min+0
			JSR		keypad_get_keypress
			STA		Min+0
			
			; prompt for Min+1
			JSR		keypad_get_keypress
			STA		Min+1
			
			; goto SS address
			LDA		#$CE
			JSR		lcd_goto_addr
			
			; prompt for Sec+0
			JSR		keypad_get_keypress
			STA		Sec+0
			
			; prompt for Sec+1
			JSR		keypad_get_keypress
			STA		Sec+1			
			
			; done 
			RTS
			


;**************************************************************

