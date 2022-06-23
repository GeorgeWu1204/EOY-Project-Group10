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

INA219_WE ina219;

float curr_v;
float current_mA, vpd0, vpd1, vb0 = 0, io, iL0 = 0;
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

enum state {idle, mppt, charge_limit, night, safety, done} charger_state;

static const char *enum_str[] = {"idle", "mppt", "charge_limit", "night", "safety", "done"};

String getStringForEnum( int enum_val )
{
    String tmp(enum_str[enum_val]);
    return tmp;
}

void sampling() {

  vb0 = ((analogRead(A0)*4.096/1023)*2);
  vpd0 = ((analogRead(A3)*4.096/1023)/330*890);
  io = (analogRead(A2)-575.8)*38;
  current_mA = ina219.getCurrent_mA();
  iL0 = -current_mA;
  lighting = analogRead(PHOTODIODE);
  time = millis();
  curr_v = vpd0;
  eff = (vpd0*io)/(vb0*iL0);

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

  if (iL0 < 1){
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

  SDprint = String(time) + "," + getStringForEnum(charger_state) + "," + String(lighting) + "," + String(dutyref/255) + "," + String(vb0) + "," + String(iL0) + "," + String(pavg0) + "," + String(dpavg) + "," + String(vpd0) + "," + String(ioavg0)+ "," + String(eff);
  
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
    sw0 = 1;
    Serial.println("INITIAL ON");

  }
  else if (vpd0 > 5.2) {
    
    digitalWrite(RELAY_PIN, LOW);
    sw0 = 0;
    dutyref = 0;
    Serial.println("INITIAL OFF TOO HIGH");
  }
  else {
    
    digitalWrite(RELAY_PIN, LOW);
    sw0 = 0;
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

        if (calculation(iL0, iL1, vb0, vb1, vpd0, vpd1)){ // discard random 0s from ina219
          
          // moving average implemented to reduce effect of the larger voltage ripple in boost
          SUM = SUM - READINGS[INDEX];       // Remove the oldest entry from the sum
          VALUE = p0;                        // Read the next sensor value
          READINGS[INDEX] = VALUE;           // Add the newest reading to the window
          SUM = SUM + VALUE;                 // Add the newest reading to the sum
          INDEX = (INDEX+1) % 5;            // Increment the index, and wrap to 0 if it exceeds the window size
          pavg0 = SUM / 5;

        }

        switch(charger_state) {

          case idle :

            digitalWrite(RELAY_PIN, HIGH);

            dutyref = 0;
            pwm_modulate(dutyref);

            if (pavg0 > 100){ //battery plugged in

              charger_state = mppt;
            }

          break;

          case mppt :

            digitalWrite(RELAY_PIN, HIGH);
            
              if ((vpd0 > 5.2) || (vpd0 < 4.5)){

                charger_state = safety;
              }

              if (((vpd0 > 5.1) && (dutyref < 3))){
                  
                charger_state = charge_limit;
              }

              if ((lighting > 1000) && (pavg0 < 250)){

                charger_state = night;
              }

          break;
          
          case charge_limit :

            digitalWrite(RELAY_PIN, HIGH);
            
            if ((vpd0 > 5.1) && (dutyref < 3)){ // good lighting condition it may go out of range when trying to limit current 

              dutyref = 0.95;
              pwm_modulate(dutyref);

              while ((vpd0 < 5.1) && (di > 3)){ // to be confirmed

                dutyref--;
                pwm_modulate(dutyref);
              }
            }

            if ((vpd0 > 5.2) || (vpd0 < 4.5)){

              charger_state = safety;
            }

            if ((lighting > 1000) && (pavg0 < 250)){

              charger_state = night;
            }

            if (pavg0 < 50){

              charger_state = done;
              Serial.println('Done charging!');
            }
          
          break;

        case night :

          digitalWrite(RELAY_PIN, LOW);
          dutyref = 0;
          pwm_modulate(dutyref);

          if ((lighting < 1000)){

            charger_state = mppt;
          }

        break;

        case safety :

          digitalWrite(RELAY_PIN, LOW);
          Serial.println('Error, please reconnect battery');

        break;
        
        case done : 

          digitalWrite(RELAY_PIN, LOW);

          if (pavg0 < 50){ // battery plugged out

            charger_state = idle;
          }

        break;

        default : charger_state = idle;

        }
        
        
        if (charger_state == mppt){
          
          if (((vpd0 < 4.6) || (vpd0 > 5.1)) && (di < 200)){ // adjust to safe range only in constant lighting conditions

            sgn = -sgn;
            dutyref += sgn*1;
            //dutyref = saturation(dutyref,170,0);
            pwm_modulate(dutyref);
            vpd1 = vpd0;

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

        if ((calculation(iL0, iL1, vb0, vb1, vpd0, vpd1))){ // discard random 0s from ina219
     
          if ((dpavg < 0)){ // MPPT algorithm

            sgn = -sgn;
          }
          
          if (lighting < 10){

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

        dutyref += sgn*stepsize;
        pwm_modulate(dutyref);

        vb1 = vb0;
        iL1 = iL0;
        curr_v = vpd0;

        SD_fn();


        Serial.println("`````````````````````MPPT (P&O)````````````````````");

        //Serial.println(SDprint);

        //Serial.println("``````````````````````````````````````````````````");
    
        //SD_fn();
        }

        int_count = 0;
    }

        int_count++;
        //Serial.println(int_count);
        loopTrigger = 0;

    }
}