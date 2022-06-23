// MPPT Boost

#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>
#include <SPI.h>
#include <SD.h>

#define RELAY_PIN   7
#define RELAY_BUCK  8
#define RELAY_SHORT 9 
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
unsigned long time;

Sd2Card card;
SdVolume volume;
SdFile root;

const int chipSelect = 10; //hardwired chip select for the SD card
String SDprint;

// EDIT FILE NAME AND TYPE OF TEST HERE
String fileName = "SD_Test.csv";
unsigned int testcase = 1;
// 1 - mppt in varying lighting
// 2 - inc in varying lighting

int pavg0, pavg1;
int INDEX = 0;
int VALUE = 0;
int SUM = 0;
int READINGS[5];
int AVERAGED = 0;

void sampling() {

  //0.375
  vb0 = ((analogRead(A0)*4.096/1023)*2);
  vpd0 = ((analogRead(A3)*4.096/1023)/330*890);
  vref = ((analogRead(A2)*4.096/1023));
  current_mA = ina219.getCurrent_mA();
  iL0 = -current_mA;
  //Serial.println(iL0);
  lighting = analogRead(PHOTODIODE);
  time = millis();
  curr_v = vpd0;

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

void mvavg_powerdiff(float pavg0, float pavg1){

  dpavg = pavg0 - pavg1;

}

ISR(TCA0_CMP1_vect){

  TCA0.SINGLE.INTFLAGS |= TCA_SINGLE_CMP1_bm; //clear interrupt flag
  loopTrigger = 1;
  
}

void SD_fn(){

  SDprint = String(time) + "," + String(lighting) + "," + String(dutyref/255) + "," + String(vb0) + "," + String(iL0) + "," + String(pavg0) + "," + String(dpavg) + "," + String(vpd0);
  
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

void set_dutyref(float irradiance){ // when relay is off

  off_dutyref = (0.23 - 0.0001125*irradiance)*255;

}

void set_mppt_stepsize(float irradiance){

  stepsize = 0.01*dp;

}

void setup() {
    
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
  pinMode(RELAY_PIN, OUTPUT);

  TCA0.SINGLE.PER = 9999; //
  TCA0.SINGLE.CMP1 = 9999; //
  TCA0.SINGLE.CTRLA = TCA_SINGLE_CLKSEL_DIV16_gc | TCA_SINGLE_ENABLE_bm; //16 prescaler, 1M.
  TCA0.SINGLE.INTCTRL = TCA_SINGLE_CMP1_bm; 

  pinMode(6, OUTPUT);
  TCB0.CTRLA = TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm;

  digitalWrite(RELAY_PIN, LOW);
  digitalWrite(SUPPLY, HIGH);

  interrupts();  // enable interrupts.

  sampling();

  if ((curr_v > 4.5) && (curr_v < 5.2)){

    digitalWrite(RELAY_PIN, HIGH);
    sw0 = 1;
    Serial.println("INITIAL ON");

  }
  else if (vb0 > 5.2) {
    
    digitalWrite(RELAY_PIN, LOW);
    sw0 = 0;
    dutyref = 0;
    Serial.println("INITIAL OFF TOO HIGH");
  }
  else {
    
    digitalWrite(RELAY_PIN, LOW);
    sw0 = 0;
    dutyref = 0;
    Serial.println("INITIAL OFF");

  }

  pwm_modulate(dutyref);
  Serial.println("initial duty cycle set at " + String(dutyref));

  digitalWrite(RELAY_BUCK, LOW);
  digitalWrite(RELAY_SHORT, HIGH);
          

}

void loop() {

  switch(testcase){

    case 1: 

      if (loopTrigger){ // fast loop
        
        digitalWrite(13, HIGH);
        sampling();
        
        if (calculation(iL0, iL1, vb0, vb1, vpd0, vpd1)){ // discard random 0s from ina219
          
          // moving average implemented to reduce effect of the larger voltage ripple in boost

          SUM = SUM - READINGS[INDEX];       // Remove the oldest entry from the sum
          VALUE = p0;                        // Read the next sensor value
          READINGS[INDEX] = VALUE;           // Add the newest reading to the window
          SUM = SUM + VALUE;                 // Add the newest reading to the sum
          INDEX = (INDEX+1) % 5;            // Increment the index, and wrap to 0 if it exceeds the window size
          //Serial.println(pavg0);
          //Serial.println(p0);
          pavg0 = SUM / 5;


          if (((vpd0 < 4.6) || (vpd0 > 5.1)) && (di < 200)){ // adjust to safe range only in constant lighting conditions

            sgn = -sgn;
            dutyref += sgn*1;
            //dutyref = saturation(dutyref,170,0);
            pwm_modulate(dutyref);
            vpd1 = vpd0;

          }

          if ((pavg0 > 100) && (dutyref < 0)){ // when battery plugged in
            
            dutyref = 50;
            pwm_modulate(dutyref);

          }

          if (vpd0 > 5.8){

            digitalWrite(RELAY_BUCK, HIGH);
            digitalWrite(RELAY_SHORT, LOW);

          }
        }

          /*if ((curr_v > 5.2) && (sw1 == 1)){

            digitalWrite(RELAY_PIN, LOW);
            sw0 = 0;
            set_dutyref(lighting);
            dutyref = 0;
            pwm_modulate(0);
            Serial.println("OFF hysteresis");
            Serial.println("currently duty cycle set at " + String(dutyref));

          }
          else if ((curr_v < 5.1) && (sw1 == 0)){

            digitalWrite(RELAY_PIN, HIGH);
            sw0 = 1;
            Serial.println("ON");

          }*/

          sw1 = sw0;

        digitalWrite(13,LOW);
        loopTrigger = 0;
        int_count++;

      }

      if (int_count == 50){ // slow loop

        sampling();
        mvavg_powerdiff(pavg0, pavg1);

        pavg1 = pavg0;
        
        if ((calculation(iL0, iL1, vb0, vb1, vpd0, vpd1))){ // discard random 0s from ina219
     
          if ((dpavg < 0)){ // MPPT algorithm

            sgn = -sgn;
      
          }
          
          if (lighting < 5){

            if (pavg0 < 2000){
              stepsize = 5;
            }  
            else if ((pavg0 > 2000) && (pavg0 < 4000)){
              stepsize = 2;
            }
            else {
              stepsize = 1;
            }

          }
          else {

            stepsize = 1;
          
          }

          
          if (sw0 == 1){

            dutyref += sgn*stepsize;
            //dutyref = saturation(dutyref,170,0);
            pwm_modulate(dutyref);

          }

          vb1 = vb0;
          iL1 = iL0;
          curr_v = vpd0;


          Serial.println("`````````````````````MPPT (P&O)````````````````````");

          Serial.print(dutyref/255);
          Serial.print("   ");
          Serial.print(iL0);
          Serial.println("   ");
          Serial.print(p0);
          Serial.println("   ");

          if ((curr_v > 4.5) && (curr_v < 5.2)){
            
            set_dutyref(lighting);
            digitalWrite(RELAY_PIN, HIGH);
            sw0 = 1;
            //Serial.println("ON");

          }
          else if ((curr_v > 5.2) || (curr_v < 4.5)){
            
            digitalWrite(RELAY_PIN, LOW);
            sw0 = 0;
            set_dutyref(lighting);
            dutyref = 0;
            pwm_modulate(0);
            Serial.println("OFF here?");
            Serial.println("currently duty cycle set at " + String(dutyref));

          }


          SD_fn();

        }

        
        int_count = 0;

      }
      break;

    case 2: // incremental conductance mppt
      
      if (loopTrigger){ // fast loop
        
        digitalWrite(13, HIGH);
        sampling();
        
        if (calculation(iL0, iL1, vb0, vb1, vpd0, vpd1)){ // discard random 0s from ina219
          
          // moving average implemented to reduce effect of the larger voltage ripple in boost

          SUM = SUM - READINGS[INDEX];       // Remove the oldest entry from the sum
          VALUE = p0;                        // Read the next sensor value
          READINGS[INDEX] = VALUE;           // Add the newest reading to the window
          SUM = SUM + VALUE;                 // Add the newest reading to the sum
          INDEX = (INDEX+1) % 5;            // Increment the index, and wrap to 0 if it exceeds the window size
          //Serial.println(pavg0);
          //Serial.println(p0);
          pavg0 = SUM / 5;


          if ((vpd0 < 4.6) || (vpd0 > 5.1) && (di < 200)){ // adjust to safe range only in constant lighting conditions

            sgn = -sgn;
            dutyref += sgn*1;
            //dutyref = saturation(dutyref,170,0);
            pwm_modulate(dutyref);

            vpd1 = vpd0;
            curr_v = vpd0;

          }

          if ((pavg0 > 100) && (dutyref < 0)){ // when battery plugged in
            
            dutyref = 50;
            pwm_modulate(dutyref);

          }
        }

        digitalWrite(13,LOW);
        loopTrigger = 0;
        int_count++;

      }

      if (int_count == 50){ // slow loop

        sampling();
        mvavg_powerdiff(pavg0, pavg1);

        pavg1 = pavg0;
        
        if (calculation(iL0, iL1, vb0, vb1, vpd0, vpd1)){ // discard random 0s from ina219
     
          // incremental conductance algorithm
          if (pavg0 > 50){
            if (((di == 0) && (dvb == 0)) || (di/dvb == -iL0/vb0)){

              sgn = 0;

            }
            else if (((dvb == 0) && (di > 0)) || ((di/dvb > -iL0/vb0) && (dp > 0) && (dvb > 0)) || ((di/dvb > -iL0/vb0) && (dp < 0))){

              sgn = -1;

            }
            else if ((di/dvb > -iL0/vb0) && (dp > 0) && (dvb > 0) || (di/dvb < -iL0/vb0) || ((dvb == 0) && (di < 0))){

              sgn = 1;

            }

            dutyref += sgn*2;
            dutyref = saturation(dutyref,180,1); //prevent it from going wrong region
            pwm_modulate(dutyref);

            vb1 = vb0;
            iL1 = iL0;

            Serial.println("`````````````````````MPPT (INC)````````````````````");

            Serial.print(dutyref);
            Serial.print("   ");
            Serial.print(p0);
            Serial.println("   ");
          }

          SD_fn();


          if ((curr_v > 4.5) && (curr_v < 5.2)){
            
            set_dutyref(lighting);
            digitalWrite(RELAY_PIN, HIGH);
            sw0 = 1;
            //Serial.println("ON");

          }
          else if ((curr_v > 5.2) || (curr_v < 4.5)){
            
            digitalWrite(RELAY_PIN, LOW);
            sw0 = 0;
            set_dutyref(lighting);
            dutyref = 0;
            pwm_modulate(0);
            Serial.println("OFF here?");
            Serial.println("currently duty cycle set at " + String(dutyref));

          }
        }

        int_count = 0;
      }

    break;
  }
}