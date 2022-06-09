#include <Arduino.h>
#include <Wire.h>
#include <INA219_WE.h>

#define RELAY_PIN 7
#define POTENTIOMETER A0

float curr_v;
INA219_WE ina219;
unsigned int loopTrigger;
unsigned int sensorValue0,sensorValue1,sensorValue2,sensorValue3;
float vpd,vb,vref,iL,dutyref,current_mA;
float oc=0; //internal signals
float Ts=0.0008; //1.25 kHz control frequency. It's better to design the control period as integral multiple of switching period.
float current_limit = 3.0;
float open_loop;

void sampling(){

  // Make the initial sampling operations for the circuit measurements
  
  sensorValue0 = analogRead(A0); //sample Vb
  sensorValue2 = analogRead(A2); //sample Vref
  sensorValue3 = analogRead(A3); //sample Vpd
  current_mA = ina219.getCurrent_mA(); // sample the inductor current (via the sensor chip)

  // Process the values so they are a bit more usable/readable
  // The analogRead process gives a value between 0 and 1023 
  // representing a voltage between 0 and the analogue reference which is 4.096V
  
  vb = sensorValue0 * (4.096 / 1023.0); // Convert the Vb sensor reading to volts
  vref = sensorValue2 * (4.096 / 1023.0); // Convert the Vref sensor reading to volts
  vpd = sensorValue3 * (4.096 / 1023.0)* (890/330); // Convert the Vpd sensor reading to volts

  // The inductor current is in mA from the sensor so we need to convert to amps.
  // We want to treat it as an input current in the Boost, so its also inverted
  // For open loop control the duty cycle reference is calculated from the sensor
  // differently from the Vref, this time scaled between zero and 1.
  // The boost duty cycle needs to be saturated with a 0.33 minimum to prevent high output voltages
  
  iL = -current_mA/1000.0;
  dutyref = sensorValue2 * (1.0 / 1023.0);

}

float saturation (float sat_input, float uplim, float lowlim){ // Saturatio function
  if (sat_input > uplim) sat_input=uplim;
  else if (sat_input < lowlim ) sat_input=lowlim;
  else;
  return sat_input;
}

void pwm_modulate(float pwm_input){ // PWM function
  analogWrite(6,(int)(255-pwm_input*255)); 
}

ISR(TCA0_CMP1_vect){
  TCA0.SINGLE.INTFLAGS |= TCA_SINGLE_CMP1_bm; //clear interrupt flag
  loopTrigger = 1;
}

void setup() {

  Serial.begin(115200);

  noInterrupts();
  pinMode(13, OUTPUT);

  pinMode(RELAY_PIN, OUTPUT);
  analogReference(EXTERNAL);

  // TimerA0 initialization for control-loop interrupt.
  
  TCA0.SINGLE.PER = 999; 
  TCA0.SINGLE.CMP1 = 999; 
  TCA0.SINGLE.CTRLA = TCA_SINGLE_CLKSEL_DIV16_gc | TCA_SINGLE_ENABLE_bm; //16 prescaler, 1M.
  TCA0.SINGLE.INTCTRL = TCA_SINGLE_CMP1_bm; 

  // TimerB0 initialization for PWM output
  
  pinMode(6, OUTPUT);
  TCB0.CTRLA=TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm; //62.5kHz
  analogWrite(6, 120); 

  digitalWrite(RELAY_PIN, LOW);

  interrupts();  // enable interrupts.
  Wire.begin(); // We need this for the i2c comms for the current sensor
  ina219.init(); // this initiates the current sensor
  Wire.setClock(700000); // set the comms speed for i2c
  
}

void loop() {

  if(loopTrigger){

    digitalWrite(13, HIGH);

    sampling();

    current_limit = 2; // 
    oc = iL-current_limit; // Calculate the difference between current measurement and current limit
    if ( oc > 0) {
      open_loop=open_loop+0.001; // We are above the current limit so less duty cycle
    } else {
      open_loop=open_loop-0.001; // We are below the current limit so more duty cycle
    }
    open_loop=saturation(open_loop,0.99,dutyref); // saturate the duty cycle at the reference or a min of 0.01
    pwm_modulate(open_loop); // and send it out
    
    curr_v = vpd;
    Serial.println("open loop duty cycle : " + String(open_loop));
    Serial.println("output voltage : " + String(curr_v));
    //Serial.println("output current : " + String(iL));

    unsigned int sw0, sw1;
    
    if ((curr_v > 3.4) && (sw1 == 0)){

      digitalWrite(RELAY_PIN, HIGH);
      sw0 = 1;
      Serial.println("--------------------------------- ON -----------------------------------");

    }
    else if ((curr_v < 3.3) && (sw1 == 1)){

      digitalWrite(RELAY_PIN, LOW);
      sw0 = 0;
      Serial.println("OFF");

    }
    else if ((curr_v > 3.9) && (sw1 = 0)){

      digitalWrite(RELAY_PIN, LOW);
      sw0 = 0;
      Serial.println("OFF");

    }
    else if ((curr_v < 3.8) && (sw1 = 1)){

      digitalWrite(RELAY_PIN, HIGH);
      sw0 = 1;
      Serial.println("--------------------------------- ON -----------------------------------");

    }
    
    /*
    if ((curr_v < 3.8) && (curr_v > 3.4)){

      digitalWrite(RELAY_PIN, HIGH);
      Serial.println("--------------------------------- ON -----------------------------------");

    }
    else{

      digitalWrite(RELAY_PIN, LOW);
      Serial.println("OFF");

    }*/
    
    digitalWrite(13, LOW);
    loopTrigger = 0;
  
  }
}

// rising edge
// 4.6V
// 5.06V

// falling edge
// 5.12V