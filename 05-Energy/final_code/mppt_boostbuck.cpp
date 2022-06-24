// Group 10
// Written by Feng Shen Foo, Weizheng Wang

#include <Arduino.h>
#include <string.h>
#include <Wire.h>
#include <INA219_WE.h>
#include <SPI.h>
#include <SD.h>

#define RELAY_PIN   7
#define RELAY_BUCK  8
#define RELAY_SHORT 9 
#define SUPPLY      4
#define PHOTODIODE  A1
#define VOUT        A2

INA219_WE ina219;

float curr_v;
float vm0, vm1, vin0 = 0, io, iin0 = 0, vout0, vout1;
float irradiance;
float p0, p1, dvin, dvm, dp, dpavg, di, vin1 = 0, iin1 = 0;
float dutyref = 10;
String discarded_data;
float stepsize;
bool loopTrigger;
unsigned int int_count = 0;
int sgn = 1;
unsigned long time;
Sd2Card card;
SdVolume volume;
SdFile root;
const int chipSelect = 10; //hardwired chip select for the SD card
String SDprint;

int pavg0, pavg1;
int INDEX = 0;
int VALUE = 0;
int SUM = 0;
int READINGS[5];
int AVERAGED = 0;

int ioavg0;
int INDEXi = 0;
int VALUEi = 0;
int SUMi = 0;
int READINGSi[5];
int AVERAGEDi = 0;

float eff;

enum state {idle, mppt, charge_limit, night, error, done} charger_state;

static const char *enum_str[] = {"idle", "mppt", "charge_limit", "night", "error", "done"};

String getStringForEnum( int enum_val )
{
    String tmp(enum_str[enum_val]);
    return tmp;
}

void sampling() {

  vin0 = ((analogRead(A0)*4.096/1023)*2);
  vm0 = ((analogRead(A3)*4.096/1023)/330*890);
  //io = (analogRead(A2)-575.8)*38;
  vout0 = (analogRead(A2)*4.096/1023)/2*3;
  iin0 = -ina219.getCurrent_mA();
  irradiance = analogRead(PHOTODIODE);
  time = millis();
  curr_v = vm0;

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

bool calculation(float iin0, float iin1, float vin0, float vin1, float vm0, float vm1) {

  if (iin0 < 1){
    return false;
  }
  
  p0 = vin0*iin0;
  p1 = vin1*iin1;
  dvin = vin0-vin1;
  dvm = vm0-vm1;
  di = iin0-iin1;
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

  SDprint = String(time) + "," + getStringForEnum(charger_state) + "," + String(irradiance) + "," + String(dutyref/255) + "," + String(vin0) + "," + String(iin0) + "," + String(pavg0) + "," + String(dpavg) + "," + String(vm0) + "," + String(vout0);
  
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

  TCA0.SINGLE.PER = 9999; 
  TCA0.SINGLE.CMP1 = 9999; 
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
    Serial.println("INITIAL ON");

  }
  else if (vm0 > 5.2) {
    
    digitalWrite(RELAY_PIN, LOW);
    dutyref = 0;
    Serial.println("INITIAL OFF TOO HIGH");
  }
  else {
    
    digitalWrite(RELAY_PIN, LOW);
    dutyref = 0;
    Serial.println("INITIAL OFF TOO LOW");

  }

  pwm_modulate(dutyref);
  Serial.println("initial duty cycle set at " + String(dutyref));

  digitalWrite(RELAY_BUCK, LOW);
  digitalWrite(RELAY_SHORT, HIGH);      

}

void loop () {

    if (loopTrigger) { // fast loop that runs in all states

        sampling();

        if (calculation(iin0, iin1, vin0, vin1, vm0, vm1)){ // discard random 0s from ina219
          
          // moving average implemented to reduce effect of the larger voltage ripple in boost
          SUM = SUM - READINGS[INDEX];       // Remove the oldest entry from the sum
          VALUE = p0;                        // Read the next sensor value
          READINGS[INDEX] = VALUE;           // Add the newest reading to the window
          SUM = SUM + VALUE;                 // Add the newest reading to the sum
          INDEX = (INDEX+1) % 5;            // Increment the index, and wrap to 0 if it exceeds the window size
          pavg0 = SUM / 5;

          SUMi = SUMi - READINGSi[INDEXi];       // Remove the oldest entry from the sum
          VALUEi = io;                        // Read the next sensor value
          READINGSi[INDEXi] = VALUEi;           // Add the newest reading to the window
          SUMi = SUMi + VALUEi;                 // Add the newest reading to the sum
          INDEXi = (INDEXi+1) % 5;            // Increment the index, and wrap to 0 if it exceeds the window size
          ioavg0 = SUMi / 5;

        }

        switch(charger_state) {

          case idle :

            digitalWrite(RELAY_PIN, HIGH);

            dutyref = (1-vin0/5);
            saturation(dutyref, 150, 0);
            pwm_modulate(dutyref);

            if (pavg0 > 100){ //battery plugged in

              charger_state = mppt;
            }

          break;

          case mppt :

            digitalWrite(RELAY_PIN, HIGH);

            
            if ((irradiance > 1000) && (pavg0 < 400)){

              charger_state = night;
            }
            else if ((vout0 > 5.2) || (vout0 < 4.5)){

                charger_state = error;
            }


          break;
          
        case night :

          dutyref = 0;
          pwm_modulate(dutyref);

          if ((irradiance < 500)){
            if ((vout0 < 5.2) && (vout0 > 4.5)){
              charger_state = mppt;
            }
          }

        break;

        case error :

          digitalWrite(RELAY_PIN, LOW);
          Serial.println('Error, please reconnect battery');

        break;
        
        case done : 

          Serial.println('Done charging!');

        break;

        default : charger_state = idle;

        }
        
        if (charger_state == mppt){

          
          if ((vout0 > 5.15) && (di < 200)){ // adjust to safe range only in constant irradiance conditions
            /*
            sgn = -sgn;
            dutyref += sgn*1;
*/            
            dutyref--;
            pwm_modulate(dutyref);
            vout1 = vout0;
          }

          if ((vout0 < 4.55) && (di < 200)){ // adjust to safe range only in constant irradiance conditions
            
            sgn = -sgn;
            dutyref += sgn*1;
            pwm_modulate(dutyref);
            vout1 = vout0;
          }
          
          if (vout0 < 4.55){
            dutyref++;
            pwm_modulate(dutyref);

          }
          

          if (dutyref < 0){ // prevent duty cycle from going into negative values
              
            dutyref = 0;
            pwm_modulate(dutyref);
          }
        }

        SD_fn();

        if ((int_count > 50) ){
          
          int_count = 0;
        }

        if ((int_count == 50) && (charger_state == mppt)){ // slow loop for mppt

          

          sampling();
          mvavg_powerdiff(pavg0, pavg1);

          pavg1 = pavg0;

          if ((calculation(iin0, iin1, vin0, vin1, vm0, vm1))){ // discard random 0s from ina219

            if ((irradiance < 200) && (iin0 < 50)){

              charger_state = done;
            
            }
      
            if ((dpavg < 0)){ // MPPT algorithm

              sgn = -sgn;
            }
            
            if (irradiance < 10){

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

          dutyref += sgn*1;
          pwm_modulate(dutyref);

          vin1 = vin0;
          iin1 = iin0;
          curr_v = vout0;

          SD_fn();


          Serial.println("`````````````````````MPPT (P&O)````````````````````");
          }

          int_count = 0;
      }

      if ((int_count == 50) && ((charger_state == night) || (charger_state == error) || (charger_state == done))){

        digitalWrite(RELAY_PIN, LOW);
        int_count = 0;
        
      }

      int_count++;
      loopTrigger = 0;

    }
}