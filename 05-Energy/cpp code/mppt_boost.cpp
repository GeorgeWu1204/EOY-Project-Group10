// MPPT boost code

#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>

INA219_WE ina219;

unsigned int sensorValue0, sensorValue1, sensorValue2, sensorValue3;
float current_mA, vpd, vb, vref, iL, dutyref = 0.5;

float saturation(float sat_input, float uplim, float lowlim)
{ 
  if (sat_input > uplim) sat_input=uplim;
  else if (sat_input < lowlim ) sat_input=lowlim;
  else;
  return sat_input;
}

void sampling(){
  
  sensorValue0 = analogRead(A0);
  current_mA = ina219.getCurrent_mA();
  
  vb = sensorValue0*5/1023.0;
  
  iL = current_mA/1000.0;

}

void pwm_modulate(float pwm_input)
{
  analogWrite(6,(int)(255-pwm_input*255));
}

void setup()
{

  Wire.begin(); 
  Wire.setClock(700000);
  ina219.init();
  
  Serial.begin(9600);

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

  if (vb < 4.6) {
    dutyref += 0.01;
  }
  else if (vb > 4.9) {
    dutyref -= 0.01;
  }
  else;

  dutyref = saturation(dutyref,1,0);
  pwm_modulate(dutyref);

  digitalWrite(13,LOW);

  Serial.print(dutyref);
  Serial.print("   ");
  Serial.print(vb);
  Serial.print("   ");
  Serial.print(iL);
  Serial.println("   ");

  delay(1);

}
