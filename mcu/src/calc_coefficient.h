#ifndef CALC_COEFFICIENT_H
#define CALC_COEFFICIENT_H

#include <stdint.h>

// Q2.14 biquad structure
typedef struct {
    int16_t b0, b1, b2;
    int16_t a1, a2;
} BiquadQ14;

// Old 3-band structure
typedef struct {
    BiquadQ14 low;
    BiquadQ14 mid;
    BiquadQ14 high;
} ThreeBandCoeffs;

// New 6-band structure
typedef struct {
    BiquadQ14 low;
    BiquadQ14 mid;
    BiquadQ14 high;
    BiquadQ14 band4;
    BiquadQ14 band5;
    BiquadQ14 band6;
} SixBandCoeffs;

// Initialization
void calcCoeffInit(void);

// 3-band API (for backward compatibility)
ThreeBandCoeffs calcCoeffUpdate(uint16_t adc_low, uint16_t adc_mid, uint16_t adc_high);
void calcCoeffGetPotValues(float *pot_low, float *pot_mid, float *pot_high);

// 6-band API
SixBandCoeffs calcCoeffUpdateAll(uint16_t adc_b1, uint16_t adc_b2, uint16_t adc_b3,
                                 uint16_t adc_b4, uint16_t adc_b5, uint16_t adc_b6);
void calcCoeffGetPotValuesAll(float *p1, float *p2, float *p3,
                              float *p4, float *p5, float *p6);

// Test filters
ThreeBandCoeffs simpleTestFilters(uint8_t test_number);

#endif