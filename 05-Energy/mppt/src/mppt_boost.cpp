// MPPT Boost

#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>

#define RELAY_PIN 7

INA219_WE ina219;
float curr_v;

unsigned int sensorValue0, sensorValue1, sensorValue2, sensorValue3;
float current_mA, vpd, vb0 = 0, vref, iL0 = 0;
float p0, p1, dv, dp, vb1 = 0, iL1 = 0;
int dutyref = 20;

bool loopTrigger;
unsigned int int_count = 0;

float saturation(int sat_input, int uplim, int lowlim) {

  if (sat_input > uplim) sat_input = uplim;
  else if (sat_input < lowlim ) sat_input = lowlim;
  else;
  return sat_input;

}

void sampling() {
  
  sensorValue0 = analogRead(A0);
  current_mA = ina219.getCurrent_mA();

  analogReference(EXTERNAL);
  
  vb0 = (sensorValue0*4.096/1023)/0.5175;
  iL0 = -current_mA/1000.0;

}

void pwm_modulate(int pwm_input) {

  analogWrite(6,pwm_input);

}

void calculation(float iL0, float iL1, float vb0, float vb1) {

  p0 = vb0*iL0;
  p1 = vb1*iL1;
  dv = vb0-vb1;
  dp = p0-p1;

}

ISR(TCA0_CMP1_vect){
  TCA0.SINGLE.INTFLAGS |= TCA_SINGLE_CMP1_bm; //clear interrupt flag
  loopTrigger = 1;
  
}


void setup() {

  Wire.begin(); 
  Wire.setClock(700000);
  ina219.init();
  
  Serial.begin(115200);
  noInterrupts();

  analogReference(EXTERNAL);

  pinMode(13, OUTPUT);
  pinMode(2, INPUT_PULLUP);
  pinMode(3, INPUT_PULLUP);

  TCA0.SINGLE.PER = 999; //
  TCA0.SINGLE.CMP1 = 999; //
  TCA0.SINGLE.CTRLA = TCA_SINGLE_CLKSEL_DIV16_gc | TCA_SINGLE_ENABLE_bm; //16 prescaler, 1M.
  TCA0.SINGLE.INTCTRL = TCA_SINGLE_CMP1_bm; 

  pinMode(6, OUTPUT);
  TCB0.CTRLA = TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm;

  pwm_modulate(dutyref);

  digitalWrite(RELAY_PIN, LOW);

  interrupts();  // enable interrupts.
  Wire.begin(); // We need this for the i2c comms for the current sensor
  ina219.init(); // this initiates the current sensor
  Wire.setClock(700000); // set the comms speed for i2c

}

void loop() {

  if (loopTrigger){

    int_count++;

    digitalWrite(13, HIGH);

    if (int_count == 1000){
        
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

        int_count = 0;
    }

    curr_v = vb0;
    unsigned int sw0, sw1;
    /*
    sw1 = 0;

    if ((curr_v > 4.6) && (sw1 == 0)){

      digitalWrite(RELAY_PIN, HIGH);
      sw0 = 1;
      Serial.println("--------------------------------- ON -----------------------------------");

    }
    else if ((curr_v < 4.5) && (sw1 == 1)){

      digitalWrite(RELAY_PIN, LOW);
      sw0 = 0;
      Serial.println("OFF");

    }
    else if ((curr_v > 5.2) && (sw1 = 0)){

      digitalWrite(RELAY_PIN, LOW);
      sw0 = 0;
      Serial.println("OFF");

    }
    else if ((curr_v < 5.1) && (sw1 = 1)){

      digitalWrite(RELAY_PIN, HIGH);
      sw0 = 1;
      Serial.println("--------------------------------- ON -----------------------------------");

    }

    sw1 = sw0;*/

    digitalWrite(13,LOW);

    loopTrigger = 0;

  }

}