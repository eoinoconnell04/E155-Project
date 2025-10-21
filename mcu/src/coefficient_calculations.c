// coefficient_calculations.c
// Eoin O'Connell
// eoconnell@hmc.edu
// Fri Oct. 21 2025
// File containing functions to generate IIR filter coefficients for low shelf, mid peaking, and high shelf filters.

#ifndef EQ_COEFFS_H
#define EQ_COEFFS_H

#include <math.h>

#define FS 48000.0f
#define Q 0.707f
#define MAX_CUT_DB 15.0f

typedef struct {
    float b0, b1, b2;
    float a1, a2; // a0 = 1 implicit
} BiquadCoeffs;

// --- Helper functions ---
static inline float pot_to_gain_db(float pot) {
    // Map pot [0,1] to gain dB (-MAX_CUT_DB to 0)
    return -MAX_CUT_DB * (1.0f - pot);
}

static inline float db_to_amplitude(float db) {
    return powf(10.0f, db / 40.0f);
}

// --- Low-shelf biquad ---
static inline BiquadCoeffs low_shelf_coeffs(float pot) {
    float gainDB = pot_to_gain_db(pot);
    float A = db_to_amplitude(gainDB);
    float w0 = 2.0f * M_PI * 400.0f / FS;
    float alpha = sinf(w0) / (2.0f * Q);
    float cosw0 = cosf(w0);

    float b0 =    A*((A+1) - (A-1)*cosw0 + 2*sqrtf(A)*alpha);
    float b1 =  2*A*((A-1) - (A+1)*cosw0);
    float b2 =    A*((A+1) - (A-1)*cosw0 - 2*sqrtf(A)*alpha);
    float a0 =        (A+1) + (A-1)*cosw0 + 2*sqrtf(A)*alpha;
    float a1 =   -2*((A-1) + (A+1)*cosw0);
    float a2 =        (A+1) + (A-1)*cosw0 - 2*sqrtf(A)*alpha;

    BiquadCoeffs coeffs;
    coeffs.b0 = b0 / a0;
    coeffs.b1 = b1 / a0;
    coeffs.b2 = b2 / a0;
    coeffs.a1 = a1 / a0;
    coeffs.a2 = a2 / a0;
    return coeffs;
}

// --- Mid-peaking biquad ---
static inline BiquadCoeffs mid_peaking_coeffs(float pot) {
    float gainDB = pot_to_gain_db(pot);
    float A = db_to_amplitude(gainDB);
    float w0 = 2.0f * M_PI * 1000.0f / FS;
    float alpha = sinf(w0) / (2.0f * Q);
    float cosw0 = cosf(w0);

    float b0 = 1 + alpha*A;
    float b1 = -2*cosw0;
    float b2 = 1 - alpha*A;
    float a0 = 1 + alpha/A;
    float a1 = -2*cosw0;
    float a2 = 1 - alpha/A;

    BiquadCoeffs coeffs;
    coeffs.b0 = b0 / a0;
    coeffs.b1 = b1 / a0;
    coeffs.b2 = b2 / a0;
    coeffs.a1 = a1 / a0;
    coeffs.a2 = a2 / a0;
    return coeffs;
}

// --- High-shelf biquad ---
static inline BiquadCoeffs high_shelf_coeffs(float pot) {
    float gainDB = pot_to_gain_db(pot);
    float A = db_to_amplitude(gainDB);
    float w0 = 2.0f * M_PI * 2000.0f / FS;
    float alpha = sinf(w0) / (2.0f * Q);
    float cosw0 = cosf(w0);

    float b0 =    A*((A+1) + (A-1)*cosw0 + 2*sqrtf(A)*alpha);
    float b1 = -2*A*((A-1) + (A+1)*cosw0);
    float b2 =    A*((A+1) + (A-1)*cosw0 - 2*sqrtf(A)*alpha);
    float a0 =        (A+1) - (A-1)*cosw0 + 2*sqrtf(A)*alpha;
    float a1 =    2*((A-1) - (A+1)*cosw0);
    float a2 =        (A+1) - (A-1)*cosw0 - 2*sqrtf(A)*alpha;

    BiquadCoeffs coeffs;
    coeffs.b0 = b0 / a0;
    coeffs.b1 = b1 / a0;
    coeffs.b2 = b2 / a0;
    coeffs.a1 = a1 / a0;
    coeffs.a2 = a2 / a0;
    return coeffs;
}

#endif // EQ_COEFFS_H
