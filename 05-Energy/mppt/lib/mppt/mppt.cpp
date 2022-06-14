#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>
#include <SPI.h>
#include <SD.h>
#include <mppt.h>

#define RELAY_PIN   7
#define SUPPLY      4
#define PHOTODIODE  A1

INA219_WE ina219;

float curr_v;
float current_mA, vpd0, vpd1, vb0 = 0, vref, iL0 = 0;
float lighting;
float p0, p1, dvb, dvpd, dp, dpavg, di, vb1 = 0, iL1 = 0;
float dutyref = 10;
float oc=0;
float open_loop;
float current_limit;
String discarded_data;
float off_dutyref;
float stepsize;

bool loopTrigger;
unsigned int int_count = 0;
int sgn = 1;

unsigned int sw0, sw1;
float acc;

Sd2Card card;
SdVolume volume;
SdFile root;

const int chipSelect = 10; //hardwired chip select for the SD card
String SDprint;

// EDIT FILE NAME AND TYPE OF TEST HERE
String fileName = "SD_Test.csv";
unsigned int testcase = 2;
// 1 - open loop load/battery characterisation
// 2 - mppt in varying lighting
// 3 - inc in varying lighting

int pavg0, pavg1;
int INDEX = 0;
int VALUE = 0;
int SUM = 0;
int READINGS[10];
int AVERAGED = 0;

void sampling() {

  //0.375
  vb0 = ((analogRead(A0)*4.096/1023)*2);
  vpd0 = ((analogRead(A3)*4.096/1023)/330*890);
  current_mA = ina219.getCurrent_mA();
  iL0 = -current_mA;
  lighting = analogRead(PHOTODIODE);

}

float movingAverage (Vector<float> &moving_sum, float input) {

  moving_sum.remove(0); 
  moving_sum.push_back(input); 
  
  for (int i = 0; i < 10; i++){
    acc = acc + moving_sum[i];
  }
  return acc/10;

}

float saturation(int sat_input, int uplim, int lowlim) {

  if (sat_input > uplim) sat_input = uplim;
  else if (sat_input < lowlim ) sat_input = lowlim;
  else;
  return sat_input;

}

void pwm_modulate(int pwm_input) {

  analogWrite(6,pwm_input);

}

bool calculation(float iL0, float iL1, float vb0, float vb1, float vpd0, float vpd1) {

  if (iL0 == 0){
    return false;
  }
  
  p0 = vb0*iL0;
  p1 = vb1*iL1;
  dvb = vb0-vb1;
  dvpd = vpd0-vpd1;
  di = iL0-iL1;
  dp = p0-p1;

  return true;

}

void mvavg_powerdiff(float pavg0, float pavg1) {

  dpavg = pavg0 - pavg1;

}

ISR(TCA0_CMP1_vect) {

  TCA0.SINGLE.INTFLAGS |= TCA_SINGLE_CMP1_bm; //clear interrupt flag
  loopTrigger = 1;
  
}

void SD_fn() {

  SDprint = String(lighting) + "," + String(dutyref/255) + "," + String(vb0) + "," + String(iL0) + "," + String(p0) + "," + String(vpd0);

  Serial.println(SDprint); 

  File dataFile = SD.open("SD_Test.csv", FILE_WRITE);

  if (dataFile){ 
    
    dataFile.println(SDprint); 

  } 
  else {

    Serial.println("File not open"); 

  }
  dataFile.close(); 

}

void set_dutyref(float irradiance) { // when relay is off

  off_dutyref = 0.23 - 0.0001125*irradiance;

}

void set_mppt_stepsize(float dpavg) {

  if (dpavg < 50){

    stepsize = 1;

  }
  else if (50 < dpavg < 500){

    stepsize = 3;

  }
  else if (dpavg > 500){

    stepsize = 6;

  }
}

void setup_code() {

  Wire.begin(); // We need this for the i2c comms for the current sensor
  Wire.setClock(700000); // set the comms speed for i2c
  ina219.init(); // this initiates the current sensor
  
  Serial.begin(115200);

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
    Serial.println("Wiring is correct and a card is present, rewriting-----------");

  }

  noInterrupts();
  analogReference(EXTERNAL);

  pinMode(13, OUTPUT);
  pinMode(2, INPUT_PULLUP);
  pinMode(3, INPUT_PULLUP);
  pinMode(SUPPLY, OUTPUT);
  pinMode(PHOTODIODE, INPUT);

  TCA0.SINGLE.PER = 9999; //
  TCA0.SINGLE.CMP1 = 9999; //
  TCA0.SINGLE.CTRLA = TCA_SINGLE_CLKSEL_DIV16_gc | TCA_SINGLE_ENABLE_bm; //16 prescaler, 1M.
  TCA0.SINGLE.INTCTRL = TCA_SINGLE_CMP1_bm; 

  pinMode(6, OUTPUT);
  TCB0.CTRLA = TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm;

  digitalWrite(RELAY_PIN, LOW);
  digitalWrite(SUPPLY, HIGH);

  interrupts();  // enable interrupts.
  pwm_modulate(dutyref);

}