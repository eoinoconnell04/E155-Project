// coefficient_calculations_q14.c
// Fixed-point Q2.14 coefficient generation for three_band_eq

#include <stdint.h>
#include <math.h>
#define M_PI 3.14159265358979323846f  // Add this

// -----------------------------
// Configuration
// -----------------------------

#define FS 48000.0f
#define Q  0.707f
#define MAX_CUT_DB 15.0f

#define Q14_SHIFT 14
#define Q14_SCALE (1 << Q14_SHIFT)

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
// Helpers
// -----------------------------

static inline float pot_to_gain_db(float pot)
{
    return -MAX_CUT_DB * (1.0f - pot);
}

static inline float db_to_amplitude(float db)
{
    return powf(10.0f, db / 40.0f);
}

static inline int16_t float_to_q14(float x)
{
    int32_t q = (int32_t)lroundf(x * Q14_SCALE);

    if (q >  32767) q =  32767;
    if (q < -32768) q = -32768;

    return (int16_t)q;
}

static inline BiquadQ14 biquad_float_to_q14(float b0, float b1, float b2,
                                           float a1, float a2)
{
    BiquadQ14 q;

    q.b0 = float_to_q14(b0);
    q.b1 = float_to_q14(b1);
    q.b2 = float_to_q14(b2);
    q.a1 = float_to_q14(a1);
    q.a2 = float_to_q14(a2);

    return q;
}

// -----------------------------
// Low-Shelf (Q2.14 Output)
// -----------------------------

BiquadQ14 low_shelf_coeffs_q14(float pot)
{
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

    return biquad_float_to_q14(b0/a0, b1/a0, b2/a0, a1/a0, a2/a0);
}

// -----------------------------
// Mid-Peaking (Q2.14 Output)
// -----------------------------

BiquadQ14 mid_peaking_coeffs_q14(float pot)
{
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

    return biquad_float_to_q14(b0/a0, b1/a0, b2/a0, a1/a0, a2/a0);
}

// -----------------------------
// High-Shelf (Q2.14 Output)
// -----------------------------

BiquadQ14 high_shelf_coeffs_q14(float pot)
{
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

    return biquad_float_to_q14(b0/a0, b1/a0, b2/a0, a1/a0, a2/a0);
}
