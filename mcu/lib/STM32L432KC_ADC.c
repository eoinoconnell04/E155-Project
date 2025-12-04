#include "STM32L432KC_ADC.h"
uint16_t values[5];  // Changed from 3 to 5

void configureADC(void){
    ADC1_COMMON->CCR |= (1 << ADC_CCR_CKMODE_Pos);

    // Configure 5 GPIO pins as analog
    GPIOA->MODER |= (3 << GPIO_MODER_MODE0_Pos) |
                    (3 << GPIO_MODER_MODE1_Pos) |
                    (3 << GPIO_MODER_MODE3_Pos) |
                    (3 << GPIO_MODER_MODE4_Pos) |  // Added
                    (3 << GPIO_MODER_MODE5_Pos);   // Added
    
    ADC1->CR &= ~ADC_CR_DEEPPWD;  
    ADC1->CR &= ~ADC_CR_ADEN;
    ADC1->CR |= ADC_CR_ADVREGEN;
    for (volatile int i = 0; i < 1000; i++); 

    ADC1->CR |= ADC_CR_ADCAL;
    while (ADC1->CR & ADC_CR_ADCAL);

    ADC1->CFGR &= ~ADC_CFGR_RES;
    
    // Configure channels (5, 6, 8, 9, 10 for example)
    ADC1->DIFSEL &= ~(ADC_DIFSEL_DIFSEL_5 |
                      ADC_DIFSEL_DIFSEL_6 |
                      ADC_DIFSEL_DIFSEL_8 |
                      ADC_DIFSEL_DIFSEL_9 |
                      ADC_DIFSEL_DIFSEL_10);
    
    ADC1->SMPR1 &= ~(ADC_SMPR1_SMP5 |
                     ADC_SMPR1_SMP6 |
                     ADC_SMPR1_SMP8 |
                     ADC_SMPR1_SMP9);
    
    ADC1->SMPR2 &= ~ADC_SMPR2_SMP10;

    ADC1->SMPR1 |= (5 << ADC_SMPR1_SMP5_Pos) |
                   (5 << ADC_SMPR1_SMP6_Pos) |
                   (5 << ADC_SMPR1_SMP8_Pos) |
                   (5 << ADC_SMPR1_SMP9_Pos);
    
    ADC1->SMPR2 |= (5 << ADC_SMPR2_SMP10_Pos);

    // Configure sequence for 5 conversions
    ADC1->SQR1 = (4 << ADC_SQR1_L_Pos) |      // Length = 5 conversions (0-indexed)
                 (5 << ADC_SQR1_SQ1_Pos) |    // Channel 5
                 (6 << ADC_SQR1_SQ2_Pos) |    // Channel 6
                 (8 << ADC_SQR1_SQ3_Pos) |    // Channel 8
                 (9 << ADC_SQR1_SQ4_Pos);     // Channel 9
    
    ADC1->SQR2 = (10 << ADC_SQR2_SQ5_Pos);    // Channel 10

    ADC1->ISR |= ADC_ISR_ADRDY;
    ADC1->CR  |= ADC_CR_ADEN;
    while (!(ADC1->ISR & ADC_ISR_ADRDY));
}

void readADC(void) {
    ADC1->CR |= ADC_CR_ADSTART; 
    
    for(int i = 0; i < 5; i++) {  // Changed from 3 to 5
        while (!(ADC1->ISR & ADC_ISR_EOC));
        values[i] = ADC1->DR;
    }
}