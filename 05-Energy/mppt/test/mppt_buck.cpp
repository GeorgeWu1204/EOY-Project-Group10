// MPPT Buck

#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>
#include <SD.h>

// A0 - Vb (output voltage)

#define OUTPUT_VOLTAGE A0
#define RELAY_BATTERY  7 

INA219_WE ina219;

unsigned int sensorValue0, sensorValue1, sensorValue2, sensorValue3;
float current_mA, vpd, vb0 = 0, iL0 = 0;
float p0, p1, dv, dp, vb1 = 0, iL1 = 0, ddelta;
unsigned int dutyref0, dutyref1;
float vref = 10, iref = 0.41;
float ev, ei, cv, ci, cl;

float ev=0,cv=0,ei=0,oc=0; //internal signals
float Ts=0.0008; //1.25 kHz control frequency. It's better to design the control period as integral multiple of switching period.
float kpv=0.05024,kiv=15.78,kdv=0; // voltage pid.
float u0v,u1v,delta_uv,e0v,e1v,e2v; // u->output; e->error; 0->this time; 1->last time; 2->last last time
float kpi=0.02512,kii=39.4,kdi=0; // current pid.
float u0i,u1i,delta_ui,e0i,e1i,e2i; // Internal values for the current controller
float uv_max=4, uv_min=0; //anti-windup limitation
float ui_max=1, ui_min=0; //anti-windup limitation
float current_limit = 1.0;

bool loopTrigger;
int slowloop_count = 0;
enum charger_mode {off, on, bulk, absorption, flt} charger_state;

Sd2Card card;
SdVolume volume;
SdFile root;

const int chipSelect = 10; //hardwired chip select for the SD card
String SDprint;


float saturation(unsigned int sat_input, unsigned int uplim, unsigned int lowlim) {

  if (sat_input > uplim) sat_input = uplim;
  else if (sat_input < lowlim ) sat_input = lowlim;
  else;
  return sat_input;

}

void sampling() {
  
  vb0 = analogRead((OUTPUT_VOLTAGE*4.096/1023)/0.5175); 
  iL0 = ina219.getCurrent_mA()/1000;

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
  ddelta = dutyref0 - dutyref1;

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
  
  delta_ui = kpi*(e0i-e1i) + kii*Ts*e_integration + kdi/Ts*(e0i-2*e1i+e2i); //incremental PID programming avoids integrations.
  u0i = u1i + delta_ui;  //this time's control output

  //output limitation
  saturation(u0i,ui_max,ui_min);
  
  u1i = u0i; // update last time's control output
  e2i = e1i; // update last last time's error
  e1i = e0i; // update last time's error

  return u0i;

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

  //Check for the SD Card

  Serial.println("\nInitializing SD card...");

  if (!SD.begin(chipSelect)) {

    Serial.println("* is a card inserted?");

    while (true) {} //It will stick here FOREVER if no SD is in on boot

  } else {

    Serial.println("Wiring is correct and a card is present.");

  }

  if (SD.exists("SD_Test.csv")) { // Wipe the datalog when starting

    SD.remove("SD_Test.csv");
    Serial.println("Wiring is correct and a card is present.");

  }

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
      if (vb0 < 4.58 || vb0 > 5.15){

        pwm_modulate(255);
        charger_state = off;

      }
      else {

        charger_state = bulk;
      
      }
      break;

    case bulk: // mppt implementation

      digitalWrite(RELAY_BATTERY, HIGH);

      if (slowloop_count == 1000){
        
        if (dp > 0) {
          if (ddelta > 0) {
              dutyref0 += 0.01;
          }
          else {
              dutyref0 -= 0.01;
          }
        }
        else {
          if (ddelta > 0) {
              dutyref0 -= 0.01;
          }
          else {
              dutyref0 += 0.01;
          }
        }
      
      }

      if (vb0 > 5 && vb0 < 5.15){ // limit for battery voltage
        
        charger_state = absorption;
      
      }

      break;

    case absorption: // constant voltage
      
      if (v == 5){

        dutyref0 == dutyref1;

      }
      else if (v < 5){

        dutyref0 += 0.01;

      }
      else {

        dutyref0 -= 0.01;

      }

      pwm_modulate(dutyref0);               

      if (iL0 < 0.05){

        charger_state = flt;

      }

      break;

    case flt:

      vref = 5; // floating voltage to be set
      ev = vref - vb0;  
      cv = pidv(ev); 
      pwm_modulate(cv);

      if (vb0 < 5 && vb0 > 4.5){

        charger_state = absorption;   
      
      }
      if (vb0 < 4.5) {

        charger_state = bulk;
      }
      
      break;

    case off:

      digitalWrite(RELAY_BATTERY, LOW);

      break;

    default: 
      charger_state = off;
        
  }

  pwm_modulate(dutyref0);

  vb1 = vb0;
  iL1 = iL0;
  dutyref1 = dutyref0;

  Serial.print(dutyref0/255.0);
  Serial.print("   ");
  Serial.print(vb0);
  Serial.print("   ");
  Serial.print(iL0);
  Serial.print("   ");
  Serial.print(p0);
  Serial.println("   ");

  String title;

  title = "charger state, duty cycle, vo, io, power";
  SDprint = String(charger_state) + "," + String(dutyref) + "," + String(vb0) + "," + String(iL0) + "," + String(p0); //build a datastring for the CSV file

  Serial.println(title + SDprint); 

  File dataFile = SD.open("SD_Test.csv", FILE_WRITE);
 
  if (dataFile){ 
    
    dataFile.println(title + SDprint); 
  } 
  else {

    Serial.println("File not open"); 

  }

  dataFile.close(); 

  loopTrigger = false;
  
  slowloop_count = 0;

  }

  digitalWrite(13,LOW);

}