#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>

#define OUTPUT_VOLTAGE  A0
#define RELAY_BATTERY   7

INA219_WE ina219;

unsigned int sensorValue0; float current_mA; //
float vb0 = 0, iL0 = 0; //

float p0, p1, dv, dp, vb1 = 0, iL1 = 0; //

unsigned int dutyref = 0;

float vref = 10;

// float iref = 0.41;

float ev, ei, cv, ci;

float Ts = 0.001;

float kpv = 0.05024, kiv = 15.78, kdv = 0;
float u0v, u1v, delta_uv, e0v, e1v, e2v;
float kpi = 0.02512, kii = 39.4, kdi = 0;
float u0i, u1i, delta_ui, e0i, e1i, e2i;

float uv_max = 4.9, uv_min = 4.6;
float ui_max = 3, ui_min = 0;

float current_limit = 1.0;

unsigned int count = 0;

bool loopTrigger; //
enum charger_mode {off, on, bulk, absorption, flt} charger_state;

float saturation(float sat_input, float uplim, float lowlim) { //

  if (sat_input > uplim) sat_input = uplim;
  else if (sat_input < lowlim ) sat_input = lowlim;
  else;
  return sat_input;

}

void sampling() { //
  
  sensorValue0 = analogRead(OUTPUT_VOLTAGE);
  current_mA = ina219.getCurrent_mA();

  //analogReference(DEFAULT); // 5V as default for now, external may be more accurate
  
  vb0 = sensorValue0*5/1023;
  iL0 = current_mA/1000.0;

}

void pwm_modulate(unsigned int pwm_input) {

  analogWrite(6, 255-pwm_input);

}

void calculation(float iL0, float iL1, float vb0, float vb1) { //

  p0 = vb0*iL0;
  p1 = vb1*iL1;
  dv = vb0-vb1;
  dp = p0-p1;

}

float pidv( float pid_input){
  float e_integration;
  e0v = pid_input;
  e_integration = e0v;
 
  //anti-windup, if last-time pid output reaches the limitation, this time there won't be any intergrations.
  if(u1v >= uv_max) {
    e_integration = 0;
  } else if (u1v <= uv_min) {
    e_integration = 0;
  }

  delta_uv = kpv*(e0v-e1v) + kiv*Ts*e_integration + kdv/Ts*(e0v-2*e1v+e2v); //incremental PID programming avoids integrations.there is another PID program called positional PID.
  u0v = u1v + delta_uv;  //this time's control output

  //output limitation
  saturation(u0v,uv_max,uv_min);
  
  u1v = u0v; //update last time's control output
  e2v = e1v; //update last last time's error
  e1v = e0v; // update last time's error
  return u0v;
}

// This is a PID controller for the current

float pidi(float pid_input){
  float e_integration;
  e0i = pid_input;
  e_integration=e0i;
  
  //anti-windup
  if(u1i >= ui_max){
    e_integration = 0;
  } else if (u1i <= ui_min) {
    e_integration = 0;
  }
  
  delta_ui = kpi*(e0i-e1i) + kii*Ts*e_integration + kdi/Ts*(e0i-2*e1i+e2i); // incremental PID programming avoids integrations.
  u0i = u1i + delta_ui;  // this time's control output

  //output limitation
  saturation(u0i,ui_max,ui_min);
  
  u1i = u0i; // update last time's control output
  e2i = e1i; // update last last time's error
  e1i = e0i; // update last time's error
  return u0i;
}

ISR(TCA0_CMP1_vect){ //

  TCA0.SINGLE.INTFLAGS |= TCA_SINGLE_CMP1_bm;
  loopTrigger = true;

}

void setup() {

  // initialise INA219

  Wire.begin(); 
  Wire.setClock(700000);
  ina219.init();

  
  
  Serial.begin(9600);

  //analogReference(EXTERNAL);

  pinMode(13, OUTPUT); //

  pinMode(2, INPUT_PULLUP);
  pinMode(3, INPUT_PULLUP);

  pinMode(6, OUTPUT);
  TCB0.CTRLA = TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm;

  pwm_modulate(dutyref);

  // interrupt for checking output voltage every 1ms
  TCA0.SINGLE.PER = 999; 
  TCA0.SINGLE.CMP1 = 999; 
  TCA0.SINGLE.CTRLA = TCA_SINGLE_CLKSEL_DIV16_gc | TCA_SINGLE_ENABLE_bm; //16 prescaler, 1M.
  TCA0.SINGLE.INTCTRL = TCA_SINGLE_CMP1_bm;

  delay(5000);

  //starting logic required

}

void loop() {
  
  if (loopTrigger){

    count++;

    digitalWrite(13, HIGH);

    sampling();
    calculation(iL0, iL1, vb0, vb1);

    if (vb0 > 5.2 || vb0 < 4.5) {

      pwm_modulate(0);
      charger_state = off;

    }

    switch(charger_state){

      case on:

        digitalWrite(RELAY_BATTERY, LOW);
        charger_state = bulk;


      case bulk: 

        if (count >= 999) {

          count = 0;

          if (dp > 0) { // MPPT
            if (dv > 0) {
                vref += 0.1;
            }
            else {
                vref -= 0.1;
            }
          }
          else {
            if (dv > 0) {
                vref -= 0.1;
            }
            else {
                vref += 0.1;
            }
          }
        
          vb1 = vb0;
          iL1 = iL0;

        }

        if (vb0 > 5) { // limit for battery voltage

          charger_state = absorption;

        }

      case absorption: // constant voltage

          // vref = saturation(vref, 5.2, 4.5);

          if (iL0 < 0.05){

            charger_state = flt;

          }

      case flt:

          vref = 4.8; // floating voltage to be set

          if (vb0 < 4.5) {

            charger_state = bulk;

          }

      case off:

          digitalWrite(7, HIGH);

          if (vb0 > 4.5 && vb0 < 5.2) {

            charger_state = on;

          }

    }

    vref = saturation(vref, 5.2, 4.5);

    current_limit = 3;
    ev = vref - vb0;
    cv = pidv(ev);
    cv = saturation(cv, current_limit, 0);
    ei = cv-iL0;
    dutyref = pidi(ei);
    dutyref = saturation(dutyref, 0.99, 0.01);
    pwm_modulate(dutyref);

    loopTrigger = false;

  }

  Serial.print(dutyref/255.0);
  Serial.print("   ");
  Serial.print(vb0);
  Serial.print("   ");
  Serial.print(iL0);
  Serial.print("   ");
  Serial.print(p0);
  Serial.println("   ");

  digitalWrite(13,LOW);

}