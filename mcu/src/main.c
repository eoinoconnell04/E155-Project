/*
Authors: Eoin O'Connell (eoconnell@hmc.edu)
         Drake Gonzales (drgonzales@g.hmc.edu)
Date: Dec. 4, 2025
File Function: STM32L432KC main program for audio equalizer control
- Reads 6 ADC channels for frequency band gain control
- Calculates biquad filter coefficients for each band
- Transmits coefficients to FPGA via SPI (336-bit frames)
- Q2.14 fixed-point coefficient format
*/
#include 
#include 
#include "STM32L432KC.h"
#include "calc_coefficient.h"

int _write(int file, char *ptr, int len);
static void print_q14(const char *name, int16_t q);

int main(void) {
    RCC->AHB2ENR |= (RCC_AHB2ENR_GPIOAEN | RCC_AHB2ENR_GPIOBEN | RCC_AHB2ENR_GPIOCEN |
                     RCC_AHB2ENR_ADCEN);
    initSPI(7, 0, 0);

    gpioEnable(GPIO_PORT_A);
    gpioEnable(GPIO_PORT_B);
    gpioEnable(GPIO_PORT_C);

    pinMode(PA11, GPIO_OUTPUT);
    digitalWrite(PA11, 1);  // CS idle HIGH

    configureADC();

    calcCoeffInit();   // <-- initialize coefficient calculator
while(1){
    readADC();
    //printf("%u \n", values[3]);

    // ADC TABLE:
    // values[1] is middle knob
    // values[2] is left knob
    // values[3] is right knob

    //printf("ADC Values: "); 
    //for(int i = 0; i < 5; i++) { 
    // printf("%u \n", values[i]); 
    //}

    // -----------------------------
    // Coefficient Calculation
    // -----------------------------
    /*ThreeBandCoeffs coeffs = calcCoeffUpdate(
        values[2],   // low band knob
        values[1],   // mid band knob
        values[3]    // high band knob
    ); */

    //ThreeBandCoeffs coeffs = simpleTestFilters(0);
SixBandCoeffs coeffs = calcCoeffUpdateAll(values[2], values[1], values[3],
                                          values[4], values[5], values[6]);

    
    // -----------------------------
    // SPI OUTPUT
    // -----------------------------     
   digitalWrite(PA11, 0);  // CS low

// ---- SYNC ----
spiSendReceive(0xAA);
spiSendReceive(0x55);

// ---- SEND 6 ADC VALUES (12 bytes) ----
for(int i = 0; i < 6; i++) {
    spiSendReceive(values[i] >> 8);
    spiSendReceive(values[i] & 0xFF);
}

// ---- Helper ----
#define SEND_Q14(x)                      \
    do {                                 \
        spiSendReceive(((x) >> 8) & 0xFF); \
        spiSendReceive((x) & 0xFF);        \
    } while(0)

// ---- SEND ALL 6 BANDS (60 bytes) ----

// BAND 1 (LOW)
SEND_Q14(coeffs.low.b0);
SEND_Q14(coeffs.low.b1);
SEND_Q14(coeffs.low.b2);
SEND_Q14(coeffs.low.a1);
SEND_Q14(coeffs.low.a2);

// BAND 2 (MID)
SEND_Q14(coeffs.mid.b0);
SEND_Q14(coeffs.mid.b1);
SEND_Q14(coeffs.mid.b2);
SEND_Q14(coeffs.mid.a1);
SEND_Q14(coeffs.mid.a2);

// BAND 3 (HIGH)
SEND_Q14(coeffs.high.b0);
SEND_Q14(coeffs.high.b1);
SEND_Q14(coeffs.high.b2);
SEND_Q14(coeffs.high.a1);
SEND_Q14(coeffs.high.a2);

// BAND 4
SEND_Q14(coeffs.band4.b0);
SEND_Q14(coeffs.band4.b1);
SEND_Q14(coeffs.band4.b2);
SEND_Q14(coeffs.band4.a1);
SEND_Q14(coeffs.band4.a2);

// BAND 5
SEND_Q14(coeffs.band5.b0);
SEND_Q14(coeffs.band5.b1);
SEND_Q14(coeffs.band5.b2);
SEND_Q14(coeffs.band5.a1);
SEND_Q14(coeffs.band5.a2);

// BAND 6
SEND_Q14(coeffs.band6.b0);
SEND_Q14(coeffs.band6.b1);
SEND_Q14(coeffs.band6.b2);
SEND_Q14(coeffs.band6.a1);
SEND_Q14(coeffs.band6.a2);

digitalWrite(PA11, 1);  // CS high

    for(volatile int i = 0; i < 20000; i++);  
     
    print_q14("LOW_B0", coeffs.low.b0);
    print_q14("LOW_B1", coeffs.low.b1);
    print_q14("LOW_B2", coeffs.low.b2);
    print_q14("LOW_A1", coeffs.low.a1);
    print_q14("LOW_A2", coeffs.low.a2);
}
}

// Function used by printf to send characters to the laptop (taken from E155 website)
int _write(int file, char *ptr, int len) {
  int i = 0;
  for (i = 0; i < len; i++) {
    ITM_SendChar((*ptr++));
  }
  return len;
}

static void print_q14(const char *name, int16_t q)
{
    float real = (float)q / 16384.0f;   // Q14 ? float
    printf("%s: raw = %d, real = %.6f\n", name, q, real);
}