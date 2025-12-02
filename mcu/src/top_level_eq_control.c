// top_level_eq_control.c
// Top-level module: ADC -> unity-snapped gain -> coefficient calculation (Q2.14) -> SPI transmit
// Uses dac_to_gain() helper for knob scaling

#include <stdint.h>
#include "STM32L432KC.h"

// -----------------------------
// External Drivers
// -----------------------------

void initSPI(int br, int cpol, int cpha);
char spiSendReceive(char send);

void initADC(void);
uint16_t readADC(uint8_t channel);

// -----------------------------
// DAC Gain Mapping Helper
// -----------------------------

#define UNITY_SNAP_THRESHOLD 0.95f

static inline float dac_to_gain(uint16_t dac_value, uint16_t dac_max)
{
    if (dac_value >= (uint16_t)(UNITY_SNAP_THRESHOLD * dac_max))
        return 1.0f;

    return (float)dac_value / (float)dac_max;
}

// -----------------------------
// Q2.14 Coefficient API
// -----------------------------

typedef struct {
    int16_t b0;
    int16_t b1;
    int16_t b2;
    int16_t a1;
    int16_t a2;
} BiquadQ14;

BiquadQ14 low_shelf_coeffs_q14(float pot);
BiquadQ14 mid_peaking_coeffs_q14(float pot);
BiquadQ14 high_shelf_coeffs_q14(float pot);

// -----------------------------
// SPI Framing Helper
// -----------------------------

static inline void spi_send_biquad(BiquadQ14 c)
{
    int16_t vals[5] = { c.b0, c.b1, c.b2, c.a1, c.a2 };

    for (int i = 0; i < 5; i++) {
        spiSendReceive((vals[i] >> 8) & 0xFF);
        spiSendReceive(vals[i] & 0xFF);
    }
}

// -----------------------------
// Main Control Loop
// -----------------------------

int main(void)
{
    initSPI(0b010, 0, 0);
    initADC();

    const uint16_t ADC_MAX = 4095;

    while (1) {
        uint16_t dac_low  = readADC(0);
        uint16_t dac_mid  = readADC(1);
        uint16_t dac_high = readADC(2);

        float pot_low  = dac_to_gain(dac_low,  ADC_MAX);
        float pot_mid  = dac_to_gain(dac_mid,  ADC_MAX);
        float pot_high = dac_to_gain(dac_high, ADC_MAX);

        BiquadQ14 low  = low_shelf_coeffs_q14(pot_low);
        BiquadQ14 mid  = mid_peaking_coeffs_q14(pot_mid);
        BiquadQ14 high = high_shelf_coeffs_q14(pot_high);

        // Optional frame sync
        spiSendReceive(0xAA);

        spi_send_biquad(low);
        spi_send_biquad(mid);
        spi_send_biquad(high);
    }
}
