// MPPT Boost

#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>
#include <SD.h>


#define RELAY_PIN   7
#define SUPPLY      4
#define PHOTODIODE  A1

INA219_WE ina219;

float curr_v;
float current_mA, vpd0, vpd1, vb0 = 0, vref, iL0 = 0;
float lighting;
float p0, p1, dvb, dvpd, dp, di, vb1 = 0, iL1 = 0;
int dutyref = 10;
float oc=0;
float open_loop;
float current_limit;

bool loopTrigger;
unsigned int int_count = 0;
int sgn = 1;

Sd2Card card;
SdVolume volume;
SdFile root;

const int chipSelect = 10; //hardwired chip select for the SD card
String SDprint;

// EDIT FILE NAME AND TYPE OF TEST HERE
String filename = "SD_boost_load_characterisation";
unsigned int testcase = 1;
// 1 - open loop load/battery characterisation
// 2 - mppt in constant lighting
// 3 - mppt in varying lighting

float power_avg;
//std::vector<float> p(10);

void sampling() {
  
  vb0 = ((analogRead(A0)*4.096/1023)/2*3)/0.375;
  vpd0 = ((analogRead(A3)*4.096/1023)/330*890);
  current_mA = ina219.getCurrent_mA();
  iL0 = -current_mA;
  lighting = analogRead(PHOTODIODE);
}

/*
float movingAverage (std::vector<float> &moving_sum, float input){

  moving_sum.erase(moving_sum.begin()); // erase first element in vector
  moving_sum.push_back(input); // add latest sample after last element
  
  return accumulate(moving_sum.begin(), moving_sum.end(), 0.0)/10;

}*/

float saturation(int sat_input, int uplim, int lowlim) {

  if (sat_input > uplim) sat_input = uplim;
  else if (sat_input < lowlim ) sat_input = lowlim;
  else;
  return sat_input;

}

void pwm_modulate(int pwm_input) {

  analogWrite(6,pwm_input);

}

void calculation(float iL0, float iL1, float vb0, float vb1, float vpd0, float vpd1) {

  p0 = vb0*iL0;
  p1 = vb1*iL1;
  dvb = vb0-vb1;
  dvpd = vpd0-vpd1;
  di = iL0-iL1;
  dp = p0-p1;

}

ISR(TCA0_CMP1_vect){

  TCA0.SINGLE.INTFLAGS |= TCA_SINGLE_CMP1_bm; //clear interrupt flag
  loopTrigger = 1;
  
}

void setup() {
  
  Serial.begin(115200);
  noInterrupts();

  analogReference(EXTERNAL);

  pinMode(13, OUTPUT);
  pinMode(2, INPUT_PULLUP);
  pinMode(3, INPUT_PULLUP);
  pinMode(SUPPLY, OUTPUT);

  TCA0.SINGLE.PER = 9999; //
  TCA0.SINGLE.CMP1 = 9999; //
  TCA0.SINGLE.CTRLA = TCA_SINGLE_CLKSEL_DIV16_gc | TCA_SINGLE_ENABLE_bm; //16 prescaler, 1M.
  TCA0.SINGLE.INTCTRL = TCA_SINGLE_CMP1_bm; 

  pinMode(6, OUTPUT);
  TCB0.CTRLA = TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm;

  pwm_modulate(dutyref);

  digitalWrite(RELAY_PIN, LOW);
  digitalWrite(SUPPLY, HIGH);

  interrupts();  // enable interrupts.
  Wire.begin(); // We need this for the i2c comms for the current sensor
  ina219.init(); // this initiates the current sensor
  Wire.setClock(700000); // set the comms speed for i2c

  //p.resize(10, 0);

  //Check for the SD Card

  Serial.println("\nInitializing SD card...");

  if (!SD.begin(chipSelect)) {

    Serial.println("* is a card inserted?");

    while (true) {} //It will stick here FOREVER if no SD is in on boot

  } else {

    Serial.println("Wiring is correct and a card is present.");

  }

  if (SD.exists(filename)) { // Wipe the datalog when starting

    SD.remove(filename);
    Serial.println("Wiring is correct and a card is present.");

  }

}

void loop() {

  switch(testcase){

    case 1 : // open loop load/battery characterisation

      if (loopTrigger){

        digitalWrite(13, HIGH);
        sampling();
        Serial.println("lighting : " + String(lighting));
        
        current_limit = 2; 
        oc = iL0-current_limit;
        if ( oc > 0) {
          open_loop=open_loop+0.001; 
        } else {
          open_loop=open_loop-0.001; 
        }
        // UNCOMMENT when testing w load
        //open_loop=saturation(open_loop,170,0);
        pwm_modulate(open_loop);

        digitalWrite(13,LOW);
        loopTrigger = 0;

      }
  
    case 2 :

      if (loopTrigger){ // fast loop
        
        digitalWrite(13, HIGH);
        sampling();
        calculation(iL0, iL1, vb0, vb1, vpd0, vpd1);
        Serial.println("lighting : " + String(lighting));
      
        if ((vpd0 < 4.6) || (vpd0 > 5.1)){ // adjust to safe range

          sgn = -sgn;
          dutyref += sgn*1;
          //dutyref = saturation(dutyref,170,0);
          pwm_modulate(dutyref);

        }

        vpd1 = vpd0;
        curr_v = vpd0;

        if ((curr_v > 4.5) && (curr_v < 5.2)){ // simplest relay logic

          digitalWrite(RELAY_PIN, HIGH);
        
        }
        else {
          
          digitalWrite(RELAY_PIN, LOW);

        }

        digitalWrite(13,LOW);
        loopTrigger = 0;
        int_count++;
      }


      if (int_count == 100){ // slow loop

        sampling();
        calculation(iL0, iL1, vb0, vb1, vpd0, vpd1);
      
      /* previous version
        if (dp > 0) {
          if (dvb > 0) {
            dutyref -= 1;
          }
          else {
            dutyref += 1;
          }
        }
        else {
          if (dvb > 0) {
            dutyref += 1;
          }
          else {
            dutyref -= 1;
          }
        }
      */
     
        if (dp < 0){

          sgn = -sgn;

        }

        dutyref += sgn*1;
        //dutyref = saturation(dutyref,170,0);
        pwm_modulate(dutyref);

        vb1 = vb0;
        iL1 = iL0;

        Serial.println("`````````````````````MPPT````````````````````");

        Serial.print(dutyref);
        Serial.print("   ");
        Serial.print(vb0);
        Serial.print("   ");
        Serial.print(iL0);
        Serial.print("   ");
        Serial.print(p0);
        Serial.println("   ");
        
        int_count = 0;

      }

    case 3:

      if (loopTrigger){ // fast loop
        
        digitalWrite(13, HIGH);
        sampling();
        calculation(iL0, iL1, vb0, vb1, vpd0, vpd1);
        Serial.println("lighting : " + String(lighting));

        if (((vpd0 < 4.6) || (vpd0 > 5.1)) && (di < 200)){ // adjust to safe range only in constant lighting conditions

          sgn = -sgn;
          dutyref += sgn*1;
          //dutyref = saturation(dutyref,170,0);
          pwm_modulate(dutyref);

        }

        vpd1 = vpd0;
        curr_v = vpd0;

        if ((curr_v > 4.5) && (curr_v < 5.2)){ // simplest relay logic

          digitalWrite(RELAY_PIN, HIGH);
        
        }
        else {
          
          digitalWrite(RELAY_PIN, LOW);

        }

        digitalWrite(13,LOW);
        loopTrigger = 0;
        int_count++;

      }


      if (int_count == 100){ // slow loop

        sampling();
        calculation(iL0, iL1, vb0, vb1, vpd0, vpd1);
      
      /* previous version
        if (dp > 0) {
          if (dvb > 0) {
            dutyref -= 1;
          }
          else {
            dutyref += 1;
          }
        }
        else {
          if (dvb > 0) {
            dutyref += 1;
          }
          else {
            dutyref -= 1;
          }
        }
      */
     
        if (dp < 0){

          sgn = -sgn;

        }

        dutyref += sgn*1;
        //dutyref = saturation(dutyref,170,0);
        pwm_modulate(dutyref);

        vb1 = vb0;
        iL1 = iL0;

        Serial.println("`````````````````````MPPT````````````````````");

        Serial.print(dutyref);
        Serial.print("   ");
        Serial.print(vb0);
        Serial.print("   ");
        Serial.print(iL0);
        Serial.print("   ");
        Serial.print(p0);
        Serial.println("   ");
        
        int_count = 0;

      }

      /*
      if (iL0 < 250){ // adjust Vo in low light conditions

        if (dvpd > 0 && vpd0 > 4.5){

          sgn = -sgn;
          dutyref += sgn*1;

        }
        else if (vpd0 > 5.2){

          dutyref = 0;

        }
        else if (vpd0 < 4.5){

          dutyref += sgn*1;

        }
        
        dutyref = saturation(dutyref,170,0);
        pwm_modulate(dutyref);

      }

      vpd1 = vpd0;
      */

      /* // for hysteresis
      unsigned int sw0, sw1; 
      

      if (curr_v > 4.5){

        digitalWrite(RELAY_PIN, HIGH);
        sw0 = 1;

      }
      
      else if ((curr_v < 4.6) && (sw1 == 1)){

        digitalWrite(RELAY_PIN, LOW);
        sw0 = 0;

      }
      else if ((curr_v > 5.1) && (sw1 == 1)){

        digitalWrite(RELAY_PIN, LOW);
        sw0 = 0;

      }
      else if ((curr_v < 5.2) && (sw1 == 0)){

        digitalWrite(RELAY_PIN, HIGH);
        sw0 = 1;

      }
      else {

        digitalWrite(RELAY_PIN, LOW);
        sw0 = 0;

      }*/
    }

  String title;

  //title = "duty cycle, vo, io, power";
  SDprint = String(lighting) + "," + String(dutyref) + "," + String(vb0) + "," + String(iL0) + "," + String(p0) + "," + String(vpd0);

  Serial.println(SDprint); 

  File dataFile = SD.open(filename, FILE_WRITE);

  if (dataFile){ 
    
    dataFile.println(title + SDprint); 

  } 
  else {

    Serial.println("File not open"); 

  }

  dataFile.close(); 

}