// dac_gain_mapping.c
// Minimal helper for scaling MCU DAC output with unity snap

#include <stdint.h>

#define UNITY_SNAP_THRESHOLD 0.95f

// Raw DAC -> scaled gain [0.0, 1.0] with unity snap
static inline float dac_to_gain(uint16_t dac_value, uint16_t dac_max)
{
    if (dac_value >= (uint16_t)(UNITY_SNAP_THRESHOLD * dac_max))
        return 1.0f;

    return (float)dac_value / (float)dac_max;
}
