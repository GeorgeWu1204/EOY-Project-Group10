#ifndef MPPT_H
#define MPPT_H


void sampling();

float saturation(int sat_input, int uplim, int lowlim);

void pwm_modulate(int pwm_input);

bool calculation(float iL0, float iL1, float vb0, float vb1, float vpd0, float vpd1);

void mvavg_powerdiff(float pavg0, float pavg1);

void SD_fn();

void set_dutyref(float irradiance);

void set_mppt_stepsize(float irradiance);

void setup_code();

#endif