// MPPT Buck

#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>

// A0 - Vb (output voltage)

#define OUTPUT_VOLTAGE A0
#define RELAY_BATTERY  7 

INA219_WE ina219;

unsigned int sensorValue0, sensorValue1, sensorValue2, sensorValue3;
float current_mA, vpd, vb0 = 0, iL0 = 0;
float p0, p1, dv, dp, vb1 = 0, iL1 = 0;
unsigned int dutyref = 0;
float vref = 10, iref = 0.41;
float ev, ei, cv, ci;

bool loopTrigger;
enum charger_mode {off, on, bulk, absorption, flt} charger_state;


float saturation(unsigned int sat_input, unsigned int uplim, unsigned int lowlim) {

  if (sat_input > uplim) sat_input = uplim;
  else if (sat_input < lowlim ) sat_input = lowlim;
  else;
  return sat_input;

}

void sampling() {
  
  vb0 = analogRead((OUTPUT_VOLTAGE*4.096/1023)/0.5175); 
  iL = ina219.getCurrent_mA()/1000;

  analogReference(EXTERNAL);

}

void pwm_modulate(unsigned int pwm_input) {

  analogWrite(6, 255-pwm_input);

}

void calculation(float iL0, float iL1, float vb0, float vb1) {

  p0 = vb0*iL0;
  p1 = vb1*iL1;
  dv = vb0-vb1;
  dp = p0-p1;

}

float pidv( float pid_input){

}

ISR(TCA0_CMP1_vect){

  TCA0.SINGLE.INTFLAGS |= TCA_SINGLE_CMP1_bm; //clear interrupt flag
  loopTrigger = true;

}

void setup() {

  Wire.begin(); 
  Wire.setClock(700000);
  ina219.init();
  
  Serial.begin(115200);

  analogReference(EXTERNAL);

  pinMode(13, OUTPUT);

  pinMode(6, OUTPUT);
  TCB0.CTRLA = TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm;

  pwm_modulate(0.6);

  // interrupt for checking output voltage every 1ms
  TCA0.SINGLE.PER = 999; 
  TCA0.SINGLE.CMP1 = 999; 
  TCA0.SINGLE.CTRLA = TCA_SINGLE_CLKSEL_DIV16_gc | TCA_SINGLE_ENABLE_bm; //16 prescaler, 1M.
  TCA0.SINGLE.INTCTRL = TCA_SINGLE_CMP1_bm; 

}

void loop() {

  digitalWrite(13, HIGH);
  
  if (loopTrigger){
    sampling();
    calculation(iL0, iL1, vb0, vb1);

    if (vb0 > 5.15 || vb0 < 4.58){
      charger_state = off;
    }

  switch(charger_state){

    case on:
      if (vb0 < 4.5){
          pwm_modulate(255);
          charger_state = off;
      }
      else {
          digitalWrite(7, HIGH);
          charger_state = bulk;
      }

    case bulk: // constant current
      if (dp > 0) {
          if (dv > 0) {
              vref += 1;
          }
          else {
              vref -= 1;
          }
      }
      else {
          if (dv > 0) {
              vref -= 1;
          }
          else {
              vref += 1;
          }
      }

      vref = saturation(vref, 5.2, 4.5);
      pwm_modulate(vref); 
      
      vb1 = vb0;
      iL1 = iL0;

      if (vb0 > 5){ // limit for battery voltage
          charger_state = absorption;
      }

    case absorption: // constant voltage
      vref = saturation(vref, 5.2, 4.5);
      ev = vref - vb0;  
      cv = pidv(ev); 
      pwm_modulate(cv);

      if (iL0 < 0.05){
          charger_state = flt;
      }

    case flt:
      vref = 5; // floating voltage to be set
      ev = vref - vb0;  
      cv = pidv(ev); 
      pwm_modulate(cv);

      if (vb0 < 4.5){
          charger_state = bulk;   
      }

    case off:
      digitalWrite(7, LOW);

  }

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

  loopTrigger = false;

  }

  digitalWrite(13,LOW);

}