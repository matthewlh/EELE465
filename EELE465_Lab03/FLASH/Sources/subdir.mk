################################################################################
# Automatically-generated file. Do not edit!
################################################################################

-include ../makefile.local

# Add inputs and outputs from these tool invocations to the build variables 
ASM_SRCS += \
../Sources/adc.asm \
../Sources/bus.asm \
../Sources/keypad.asm \
../Sources/lcd.asm \
../Sources/led.asm \
../Sources/main.asm \

ASM_SRCS_QUOTED += \
"../Sources/adc.asm" \
"../Sources/bus.asm" \
"../Sources/keypad.asm" \
"../Sources/lcd.asm" \
"../Sources/led.asm" \
"../Sources/main.asm" \

OBJS += \
./Sources/adc_asm.obj \
./Sources/bus_asm.obj \
./Sources/keypad_asm.obj \
./Sources/lcd_asm.obj \
./Sources/led_asm.obj \
./Sources/main_asm.obj \

ASM_DEPS += \
./Sources/adc_asm.d \
./Sources/bus_asm.d \
./Sources/keypad_asm.d \
./Sources/lcd_asm.d \
./Sources/led_asm.d \
./Sources/main_asm.d \

OBJS_QUOTED += \
"./Sources/adc_asm.obj" \
"./Sources/bus_asm.obj" \
"./Sources/keypad_asm.obj" \
"./Sources/lcd_asm.obj" \
"./Sources/led_asm.obj" \
"./Sources/main_asm.obj" \

ASM_DEPS_QUOTED += \
"./Sources/adc_asm.d" \
"./Sources/bus_asm.d" \
"./Sources/keypad_asm.d" \
"./Sources/lcd_asm.d" \
"./Sources/led_asm.d" \
"./Sources/main_asm.d" \

OBJS_OS_FORMAT += \
./Sources/adc_asm.obj \
./Sources/bus_asm.obj \
./Sources/keypad_asm.obj \
./Sources/lcd_asm.obj \
./Sources/led_asm.obj \
./Sources/main_asm.obj \


# Each subdirectory must supply rules for building sources it contributes
Sources/adc_asm.obj: ../Sources/adc.asm
	@echo 'Building file: $<'
	@echo 'Executing target #1 $<'
	@echo 'Invoking: HCS08 Assembler'
	"$(HC08ToolsEnv)/ahc08" -ArgFile"Sources/adc.args" -Objn"Sources/adc_asm.obj" "$<" -Lm="$(@:%.obj=%.d)" -LmCfg=xilmou
	@echo 'Finished building: $<'
	@echo ' '

Sources/%.d: ../Sources/%.asm
	@echo 'Regenerating dependency file: $@'
	
	@echo ' '

Sources/bus_asm.obj: ../Sources/bus.asm
	@echo 'Building file: $<'
	@echo 'Executing target #2 $<'
	@echo 'Invoking: HCS08 Assembler'
	"$(HC08ToolsEnv)/ahc08" -ArgFile"Sources/bus.args" -Objn"Sources/bus_asm.obj" "$<" -Lm="$(@:%.obj=%.d)" -LmCfg=xilmou
	@echo 'Finished building: $<'
	@echo ' '

Sources/keypad_asm.obj: ../Sources/keypad.asm
	@echo 'Building file: $<'
	@echo 'Executing target #3 $<'
	@echo 'Invoking: HCS08 Assembler'
	"$(HC08ToolsEnv)/ahc08" -ArgFile"Sources/keypad.args" -Objn"Sources/keypad_asm.obj" "$<" -Lm="$(@:%.obj=%.d)" -LmCfg=xilmou
	@echo 'Finished building: $<'
	@echo ' '

Sources/lcd_asm.obj: ../Sources/lcd.asm
	@echo 'Building file: $<'
	@echo 'Executing target #4 $<'
	@echo 'Invoking: HCS08 Assembler'
	"$(HC08ToolsEnv)/ahc08" -ArgFile"Sources/lcd.args" -Objn"Sources/lcd_asm.obj" "$<" -Lm="$(@:%.obj=%.d)" -LmCfg=xilmou
	@echo 'Finished building: $<'
	@echo ' '

Sources/led_asm.obj: ../Sources/led.asm
	@echo 'Building file: $<'
	@echo 'Executing target #5 $<'
	@echo 'Invoking: HCS08 Assembler'
	"$(HC08ToolsEnv)/ahc08" -ArgFile"Sources/led.args" -Objn"Sources/led_asm.obj" "$<" -Lm="$(@:%.obj=%.d)" -LmCfg=xilmou
	@echo 'Finished building: $<'
	@echo ' '

Sources/main_asm.obj: ../Sources/main.asm
	@echo 'Building file: $<'
	@echo 'Executing target #6 $<'
	@echo 'Invoking: HCS08 Assembler'
	"$(HC08ToolsEnv)/ahc08" -ArgFile"Sources/main.args" -Objn"Sources/main_asm.obj" "$<" -Lm="$(@:%.obj=%.d)" -LmCfg=xilmou
	@echo 'Finished building: $<'
	@echo ' '


