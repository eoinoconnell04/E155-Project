// STM32L432KC_FLASH.h
// Header for FLASH functions

#ifndef STM32L4_ADC_H
#define STM32L4_ADC_H

#include <stdint.h>
#include <stm32l432xx.h>

///////////////////////////////////////////////////////////////////////////////
// Function prototypes
///////////////////////////////////////////////////////////////////////////////

extern uint16_t values[5];


void configureADC(void);
void readADC(void);

#endif