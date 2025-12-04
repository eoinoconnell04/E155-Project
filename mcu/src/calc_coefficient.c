// calc_coefficient.c
// Coefficient calculation with moving average filtering for three-band equalizer
// CORRECTED VERSION

#include "calc_coefficient.h"
#include <math.h>

// -----------------------------
// Configuration
// -----------------------------

#define FS 63000.0f  // Fixed: actual sample rate is 63 kHz (was 48 kHz)
#define Q  0.707f
#define MAX_CUT_DB 15.0f

#define Q14_SHIFT 14
#define Q14_SCALE (1 << Q14_SHIFT)

#define M_PI 3.14159265358979323846f

// ADC configuration
#define ADC_MAX 4095.0f
#define ADC_THRESHOLD 3850.0f  // Values above this are treated as max (1.0)

// Unity gain detection threshold (0.1 dB = essentially flat)
#define UNITY_GAIN_THRESHOLD_DB 0.1f

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
    // RBJ Audio EQ Cookbook uses db/40 for BOTH shelving and peaking filters
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

static inline BiquadQ14 unity_gain_biquad(void)
{
    // Unity gain: b0 = 1.0 (0x4000 in Q2.14), all others = 0
    BiquadQ14 q;
    q.b0 = 0x4000;  // 1.0 in Q2.14
    q.b1 = 0x0000;
    q.b2 = 0x0000;
    q.a1 = 0x0000;
    q.a2 = 0x0000;
    return q;
}

// -----------------------------
// Low-Shelf (Q2.14 Output)
// -----------------------------

static BiquadQ14 low_shelf_coeffs_q14(float pot)
{
    float gainDB = pot_to_gain_db(pot);
    
    // If near unity gain, return bypass filter
    if (fabsf(gainDB) < UNITY_GAIN_THRESHOLD_DB) {
        return unity_gain_biquad();
    }
    
    float A = db_to_amplitude(gainDB);  // Use db/40 for shelving (RBJ standard)
    float w0 = 2.0f * M_PI * 400.0f / FS;
    float alpha = sinf(w0) / (2.0f * Q);
    float cosw0 = cosf(w0);

    float b0 =    A*((A+1) - (A-1)*cosw0 + 2*sqrtf(A)*alpha);
    float b1 =  2*A*((A-1) - (A+1)*cosw0);
    float b2 =    A*((A+1) - (A-1)*cosw0 - 2*sqrtf(A)*alpha);
    float a0 =        (A+1) + (A-1)*cosw0 + 2*sqrtf(A)*alpha;
    float a1 =   -2*((A-1) + (A+1)*cosw0);
    float a2 =        (A+1) + (A-1)*cosw0 - 2*sqrtf(A)*alpha;

    // Normalize by a0
    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    a1 /= a0;
    a2 /= a0;
    
    // Negate a1 and a2 for FPGA format (no subtraction, only add)
    // y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] + (-a1)*y[n-1] + (-a2)*y[n-2]
    a1 = -a1;
    a2 = -a2;

    return biquad_float_to_q14(b0, b1, b2, a1, a2);
}

// -----------------------------
// Mid-Peaking (Q2.14 Output)
// -----------------------------

static BiquadQ14 mid_peaking_coeffs_q14(float pot)
{
    float gainDB = pot_to_gain_db(pot);
    
    // If near unity gain, return bypass filter
    if (fabsf(gainDB) < UNITY_GAIN_THRESHOLD_DB) {
        return unity_gain_biquad();
    }
    
    float A = db_to_amplitude(gainDB);  // Use db/40 for peaking (RBJ standard)
    float w0 = 2.0f * M_PI * 1000.0f / FS;
    float alpha = sinf(w0) / (2.0f * Q);
    float cosw0 = cosf(w0);

    float b0 = 1 + alpha*A;
    float b1 = -2*cosw0;
    float b2 = 1 - alpha*A;
    float a0 = 1 + alpha/A;
    float a1 = -2*cosw0;
    float a2 = 1 - alpha/A;

    // Normalize by a0
    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    a1 /= a0;
    a2 /= a0;
    
    // Negate a1 and a2 for FPGA format
    a1 = -a1;
    a2 = -a2;

    return biquad_float_to_q14(b0, b1, b2, a1, a2);
}

// -----------------------------
// High-Shelf (Q2.14 Output)
// -----------------------------

static BiquadQ14 high_shelf_coeffs_q14(float pot)
{
    float gainDB = pot_to_gain_db(pot);
    
    // If near unity gain, return bypass filter
    if (fabsf(gainDB) < UNITY_GAIN_THRESHOLD_DB) {
        return unity_gain_biquad();
    }
    
    float A = db_to_amplitude(gainDB);  // Use db/40 for shelving (RBJ standard)
    float w0 = 2.0f * M_PI * 2000.0f / FS;
    float alpha = sinf(w0) / (2.0f * Q);
    float cosw0 = cosf(w0);

    float b0 =    A*((A+1) + (A-1)*cosw0 + 2*sqrtf(A)*alpha);
    float b1 = -2*A*((A-1) + (A+1)*cosw0);
    float b2 =    A*((A+1) + (A-1)*cosw0 - 2*sqrtf(A)*alpha);
    float a0 =        (A+1) - (A-1)*cosw0 + 2*sqrtf(A)*alpha;
    float a1 =    2*((A-1) - (A+1)*cosw0);
    float a2 =        (A+1) - (A-1)*cosw0 - 2*sqrtf(A)*alpha;

    // Normalize by a0
    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    a1 /= a0;
    a2 /= a0;
    
    // Negate a1 and a2 for FPGA format
    a1 = -a1;
    a2 = -a2;

    return biquad_float_to_q14(b0, b1, b2, a1, a2);
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

// -----------------------------
// Simple Test Filters
// -----------------------------

BiquadQ14 simpleUnity(void)
{
    // Unity gain - passthrough (no filtering)
    BiquadQ14 q;
    q.b0 = 0x4000;  // 1.0
    q.b1 = 0x0000;  // 0.0
    q.b2 = 0x0000;  // 0.0
    q.a1 = 0x0000;  // 0.0
    q.a2 = 0x0000;  // 0.0
    return q;
}

BiquadQ14 simpleAttenuator(float gain_db)
{
    // Simple gain reduction (no poles or zeros)
    // Example: simpleAttenuator(-6.0f) for -6 dB
    float gain = powf(10.0f, gain_db / 20.0f);
    
    BiquadQ14 q;
    q.b0 = float_to_q14(gain);
    q.b1 = 0x0000;
    q.b2 = 0x0000;
    q.a1 = 0x0000;
    q.a2 = 0x0000;
    return q;
}

BiquadQ14 simpleLowpass(float cutoff_hz)
{
    // First-order lowpass filter
    // Example: simpleLowpass(5000.0f) for 5 kHz cutoff
    // Formula: H(z) = (1-alpha) / (1 - alpha*z^-1)
    
    float alpha = expf(-2.0f * M_PI * cutoff_hz / FS);
    float b0 = 1.0f - alpha;
    
    BiquadQ14 q;
    q.b0 = float_to_q14(b0);
    q.b1 = 0x0000;
    q.b2 = 0x0000;
    q.a1 = float_to_q14(alpha);  // Positive for FPGA addition
    q.a2 = 0x0000;
    return q;
}

BiquadQ14 simpleHighpass(float cutoff_hz)
{
    // First-order highpass filter
    // Example: simpleHighpass(1000.0f) for 1 kHz cutoff
    // Formula: H(z) = alpha * (1 - z^-1) / (1 - alpha*z^-1)
    
    float alpha = expf(-2.0f * M_PI * cutoff_hz / FS);
    
    BiquadQ14 q;
    q.b0 = float_to_q14(alpha);
    q.b1 = float_to_q14(-alpha);  // Negative coefficient
    q.b2 = 0x0000;
    q.a1 = float_to_q14(alpha);   // Positive for FPGA addition
    q.a2 = 0x0000;
    return q;
}

ThreeBandCoeffs simpleTestFilters(uint8_t test_number)
{
    ThreeBandCoeffs coeffs;
    
    switch (test_number) {
        case 0:  // All unity - passthrough
            coeffs.low  = simpleUnity();
            coeffs.mid  = simpleUnity();
            coeffs.high = simpleUnity();
            break;
            
        case 1:  // -6 dB attenuator on all bands
            coeffs.low  = simpleAttenuator(-6.0f);
            coeffs.mid  = simpleAttenuator(-6.0f);
            coeffs.high = simpleAttenuator(-6.0f);
            break;
            
        case 2:  // Gentle lowpass on all bands (5 kHz)
            coeffs.low  = simpleLowpass(5000.0f);
            coeffs.mid  = simpleLowpass(5000.0f);
            coeffs.high = simpleLowpass(5000.0f);
            break;
            
        case 3:  // Gentle highpass on all bands (1 kHz)
            coeffs.low  = simpleHighpass(1000.0f);
            coeffs.mid  = simpleHighpass(1000.0f);
            coeffs.high = simpleHighpass(1000.0f);
            break;
            
        case 4:  // Very gentle lowpass on all bands (10 kHz)
            coeffs.low  = simpleLowpass(10000.0f);
            coeffs.mid  = simpleLowpass(10000.0f);
            coeffs.high = simpleLowpass(10000.0f);
            break;
            
        case 5:  // Mix: LP on low, unity on mid, HP on high
            coeffs.low  = simpleLowpass(5000.0f);
            coeffs.mid  = simpleUnity();
            coeffs.high = simpleHighpass(1000.0f);
            break;
            
        default:  // Unity for safety
            coeffs.low  = simpleUnity();
            coeffs.mid  = simpleUnity();
            coeffs.high = simpleUnity();
            break;
    }
    
    return coeffs;
}