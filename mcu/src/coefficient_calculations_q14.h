#ifndef COEFFICIENT_CALCULATIONS_Q14_H
#define COEFFICIENT_CALCULATIONS_Q14_H

#include <stdint.h>

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

#endif