#include <stdio.h>
#include <stdint.h>
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
    ThreeBandCoeffs coeffs = calcCoeffUpdate(
        values[2],   // low band knob
        values[1],   // mid band knob
        values[3]    // high band knob
    );
    
    
    // -----------------------------
    // SPI OUTPUT
    // -----------------------------     
    digitalWrite(PA11, 0);  // CS low
    
    spiSendReceive(0xAA);  // Sync byte 1
    spiSendReceive(0x55);  // Sync byte 2
    
    // Send 5 ADC values (10 bytes total)
    for(int i = 0; i < 5; i++) {
        spiSendReceive(values[i] >> 8);    // MSB of ADC value
        spiSendReceive(values[i] & 0xFF);  // LSB of ADC value
    }
    
    // Send Low-pass filter coefficients (10 bytes)
    spiSendReceive(0x40); spiSendReceive(0x00);  // LOW_B0 = 0x4000
    spiSendReceive(0x00); spiSendReceive(0x30);  // LOW_B1 = 0x0000
    spiSendReceive(0x00); spiSendReceive(0x00);  // LOW_B2 = 0x0000
    spiSendReceive(0x00); spiSendReceive(0x00);  // LOW_A1 = 0x0000
    spiSendReceive(0x00); spiSendReceive(0x00);  // LOW_A2 = 0x0000
    
    // Send Mid-pass filter coefficients (10 bytes)
    spiSendReceive(0x20); spiSendReceive(0x00);  // MID_B0 = 0x4000
    spiSendReceive(0x00); spiSendReceive(0x01);  // MID_B1 = 0x0000
    spiSendReceive(0x00); spiSendReceive(0x01);  // MID_B2 = 0x0000
    spiSendReceive(0xFF); spiSendReceive(0xFF);  // MID_A1 = 0x0000
    spiSendReceive(0x00); spiSendReceive(0x00);  // MID_A2 = 0x0000
    
    // Send High-pass filter coefficients (10 bytes)
    spiSendReceive(0x40); spiSendReceive(0x00);  // HIGH_B0 = 0x4000
    spiSendReceive(0x00); spiSendReceive(0x00);  // HIGH_B1 = 0x0000
    spiSendReceive(0x00); spiSendReceive(0x10);  // HIGH_B2 = 0x0000
    spiSendReceive(0x00); spiSendReceive(0x00);  // HIGH_A1 = 0x0000
    spiSendReceive(0xFF); spiSendReceive(0x00);  // HIGH_A2 = 0x0000
    

    // helper macro
    #define SEND_Q14(x)                 \
        spiSendReceive(((x) >> 8) & 0xFF); \
        spiSendReceive((x) & 0xFF);
    /*
    // ---- LOW BAND ----
    SEND_Q14(coeffs.low.b0);
    SEND_Q14(coeffs.low.b1);
    SEND_Q14(coeffs.low.b2);
    SEND_Q14(coeffs.low.a1);
    SEND_Q14(coeffs.low.a2);

    // ---- MID BAND ----
    SEND_Q14(coeffs.mid.b0);
    SEND_Q14(coeffs.mid.b1);
    SEND_Q14(coeffs.mid.b2);
    SEND_Q14(coeffs.mid.a1);
    SEND_Q14(coeffs.mid.a2);

    // ---- HIGH BAND ----
    SEND_Q14(coeffs.high.b0);
    SEND_Q14(coeffs.high.b1);
    SEND_Q14(coeffs.high.b2);
    SEND_Q14(coeffs.high.a1);
    SEND_Q14(coeffs.high.a2);
    */

    digitalWrite(PA11, 1);  // CS high
    for(volatile int i = 0; i < 100000; i++);  
     
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
    float real = (float)q / 16384.0f;   // Q14 → float
    printf("%s: raw = %d, real = %.6f\n", name, q, real);
}