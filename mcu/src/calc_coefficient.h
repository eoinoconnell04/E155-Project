// calc_coefficient.h
// Coefficient calculation with moving average filtering for three-band equalizer

#ifndef CALC_COEFFICIENT_H
#define CALC_COEFFICIENT_H

#include <stdint.h>

// -----------------------------
// Q2.14 Biquad Format
// -----------------------------

typedef struct {
    int16_t b0;
    int16_t b1;
    int16_t b2;
    int16_t a1;
    int16_t a2;
} BiquadQ14;

// -----------------------------
// Three-band Coefficients
// -----------------------------

typedef struct {
    BiquadQ14 low;
    BiquadQ14 mid;
    BiquadQ14 high;
} ThreeBandCoeffs;

// -----------------------------
// Public Functions
// -----------------------------

/**
 * @brief Initialize the coefficient calculator (clears moving average buffers)
 */
void calcCoeffInit(void);

/**
 * @brief Update coefficients based on new ADC readings
 * @param adc_low  ADC value for low band (0-4095, max effect at >3850)
 * @param adc_mid  ADC value for mid band (0-4095, max effect at >3850)
 * @param adc_high ADC value for high band (0-4095, max effect at >3850)
 * @return ThreeBandCoeffs structure with updated Q2.14 coefficients
 */
ThreeBandCoeffs calcCoeffUpdate(uint16_t adc_low, uint16_t adc_mid, uint16_t adc_high);

/**
 * @brief Get the current smoothed potentiometer values (0.0 to 1.0)
 * @param pot_low  Pointer to store smoothed low pot value
 * @param pot_mid  Pointer to store smoothed mid pot value
 * @param pot_high Pointer to store smoothed high pot value
 */
void calcCoeffGetPotValues(float *pot_low, float *pot_mid, float *pot_high);

#endif // CALC_COEFFICIENT_H