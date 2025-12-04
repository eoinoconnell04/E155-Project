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

// -----------------------------
// Simple Test Filters
// -----------------------------

/**
 * @brief Unity gain filter (passthrough, no filtering)
 * @return BiquadQ14 with b0=1.0, all others=0
 */
BiquadQ14 simpleUnity(void);

/**
 * @brief Simple attenuator (constant gain, all frequencies)
 * @param gain_db Gain in dB (e.g., -6.0 for half volume)
 * @return BiquadQ14 with only b0 set to the gain value
 */
BiquadQ14 simpleAttenuator(float gain_db);

/**
 * @brief Simple first-order lowpass filter
 * @param cutoff_hz Cutoff frequency in Hz (e.g., 5000.0 for 5 kHz)
 * @return BiquadQ14 with b0 and a1 set for lowpass
 */
BiquadQ14 simpleLowpass(float cutoff_hz);

/**
 * @brief Simple first-order highpass filter
 * @param cutoff_hz Cutoff frequency in Hz (e.g., 1000.0 for 1 kHz)
 * @return BiquadQ14 with b0, b1, and a1 set for highpass
 */
BiquadQ14 simpleHighpass(float cutoff_hz);

/**
 * @brief Get predefined simple test filter sets
 * @param test_number Test configuration (0-5):
 *   0: All unity (passthrough)
 *   1: -6 dB attenuator on all bands
 *   2: Gentle lowpass (5 kHz) on all bands
 *   3: Gentle highpass (1 kHz) on all bands
 *   4: Very gentle lowpass (10 kHz) on all bands
 *   5: Mix: LP on low, unity on mid, HP on high
 * @return ThreeBandCoeffs with test configuration
 */
ThreeBandCoeffs simpleTestFilters(uint8_t test_number);

#endif // CALC_COEFFICIENT_H