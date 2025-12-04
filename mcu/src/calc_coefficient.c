// calc_coefficient.c
// Coefficient calculation with moving average filtering for three-band equalizer

#include "calc_coefficient.h"
#include <math.h>

// -----------------------------
// Configuration
// -----------------------------

#define FS 48000.0f
#define Q  0.707f
#define MAX_CUT_DB 15.0f

#define Q14_SHIFT 14
#define Q14_SCALE (1 << Q14_SHIFT)

#define M_PI 3.14159265358979323846f

// ADC configuration
#define ADC_MAX 4095.0f
#define ADC_THRESHOLD 3850.0f  // Values above this are treated as max (1.0)

// Moving average filter
#define MA_SIZE 5

// -----------------------------
// Moving Average State
// -----------------------------

typedef struct {
    uint16_t buffer[MA_SIZE];
    uint8_t  index;
    uint32_t sum;
    uint8_t  count;
} MovingAverage;

static MovingAverage ma_low;
static MovingAverage ma_mid;
static MovingAverage ma_high;

// Current smoothed pot values
static float pot_low_smooth  = 0.5f;
static float pot_mid_smooth  = 0.5f;
static float pot_high_smooth = 0.5f;

// -----------------------------
// Moving Average Functions
// -----------------------------

static void ma_init(MovingAverage *ma)
{
    for (int i = 0; i < MA_SIZE; i++) {
        ma->buffer[i] = 0;
    }
    ma->index = 0;
    ma->sum = 0;
    ma->count = 0;
}

static uint16_t ma_update(MovingAverage *ma, uint16_t new_value)
{
    // Subtract oldest value from sum
    ma->sum -= ma->buffer[ma->index];
    
    // Add new value
    ma->buffer[ma->index] = new_value;
    ma->sum += new_value;
    
    // Update index (circular buffer)
    ma->index = (ma->index + 1) % MA_SIZE;
    
    // Track how many samples we have (up to MA_SIZE)
    if (ma->count < MA_SIZE) {
        ma->count++;
    }
    
    // Return average
    return (uint16_t)(ma->sum / ma->count);
}

// -----------------------------
// ADC to Pot Conversion
// -----------------------------

static inline float adc_to_pot(uint16_t adc_value)
{
    // Clamp to valid range
    if (adc_value > ADC_MAX) {
        adc_value = (uint16_t)ADC_MAX;
    }
    
    // Values above threshold are treated as 1.0 (max effect)
    if (adc_value >= ADC_THRESHOLD) {
        return 1.0f;
    }
    
    // Linear mapping from 0 to threshold
    return (float)adc_value / ADC_THRESHOLD;
}

// -----------------------------
// Q2.14 Helpers
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

static BiquadQ14 low_shelf_coeffs_q14(float pot)
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

static BiquadQ14 mid_peaking_coeffs_q14(float pot)
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

static BiquadQ14 high_shelf_coeffs_q14(float pot)
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

// -----------------------------
// Public Functions
// -----------------------------

void calcCoeffInit(void)
{
    ma_init(&ma_low);
    ma_init(&ma_mid);
    ma_init(&ma_high);
    
    pot_low_smooth  = 0.5f;
    pot_mid_smooth  = 0.5f;
    pot_high_smooth = 0.5f;
}

ThreeBandCoeffs calcCoeffUpdate(uint16_t adc_low, uint16_t adc_mid, uint16_t adc_high)
{
    ThreeBandCoeffs coeffs;
    
    // Apply moving average filter to each ADC input
    uint16_t low_filtered  = ma_update(&ma_low,  adc_low);
    uint16_t mid_filtered  = ma_update(&ma_mid,  adc_mid);
    uint16_t high_filtered = ma_update(&ma_high, adc_high);
    
    // Convert filtered ADC values to pot values (0.0 to 1.0)
    pot_low_smooth  = adc_to_pot(low_filtered);
    pot_mid_smooth  = adc_to_pot(mid_filtered);
    pot_high_smooth = adc_to_pot(high_filtered);
    
    // Generate coefficients for each band
    coeffs.low  = low_shelf_coeffs_q14(pot_low_smooth);
    coeffs.mid  = mid_peaking_coeffs_q14(pot_mid_smooth);
    coeffs.high = high_shelf_coeffs_q14(pot_high_smooth);
    
    return coeffs;
}

void calcCoeffGetPotValues(float *pot_low, float *pot_mid, float *pot_high)
{
    if (pot_low)  *pot_low  = pot_low_smooth;
    if (pot_mid)  *pot_mid  = pot_mid_smooth;
    if (pot_high) *pot_high = pot_high_smooth;
}