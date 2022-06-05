// MPPT Boost

#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>

INA219_WE ina219;

unsigned int sensorValue0, sensorValue1, sensorValue2, sensorValue3;
float current_mA, vpd, vb0 = 0, vref, iL0 = 0;
float p0, p1, dv, dp, vb1 = 0, iL1 = 0;
unsigned int dutyref = 0;

float saturation(unsigned int sat_input, unsigned int uplim, unsigned int lowlim) {

  if (sat_input > uplim) sat_input = uplim;
  else if (sat_input < lowlim ) sat_input = lowlim;
  else;
  return sat_input;

}

void sampling() {
  
  sensorValue0 = analogRead(A0);
  current_mA = ina219.getCurrent_mA();

  analogReference(EXTERNAL);
  
  vb0 = sensorValue0*4.096/1023.0;
  iL0 = -current_mA/1000.0;

}

void pwm_modulate(unsigned int pwm_input) {

  analogWrite(6,pwm_input);

}

void calculation(float iL0, float iL1, float vb0, float vb1) {

  p0 = vb0*iL0;
  p1 = vb1*iL1;
  dv = vb0-vb1;
  dp = p0-p1;

}

void setup() {

  Wire.begin(); 
  Wire.setClock(700000);
  ina219.init();
  
  Serial.begin(9600);

  analogReference(EXTERNAL);

  pinMode(13, OUTPUT);
  pinMode(2, INPUT_PULLUP);
  pinMode(3, INPUT_PULLUP);

  pinMode(6, OUTPUT);
  TCB0.CTRLA = TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm;

  pwm_modulate(dutyref);

  delay(5000);

}

void loop() {

  digitalWrite(13, HIGH);

  sampling();

  calculation(iL0,iL1,vb0,vb1);

  if (dp > 0) {
    if (dv > 0) {
      dutyref -= 1;
    }
    else {
      dutyref += 1;
    }
  }
  else {
    if (dv > 0) {
      dutyref += 1;
    }
    else {
      dutyref -= 1;
    }
  }

  dutyref = saturation(dutyref,170,0);
  pwm_modulate(dutyref);

  vb1 = vb0;
  iL1 = iL0;

  Serial.print(dutyref/255.0);
  Serial.print("   ");
  Serial.print(vb0);
  Serial.print("   ");
  Serial.print(iL0);
  Serial.print("   ");
  Serial.print(p0);
  Serial.println("   ");

  digitalWrite(13,LOW);

  delay(1000);