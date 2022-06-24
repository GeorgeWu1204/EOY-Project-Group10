// Group 10
// Written by Feng Shen Foo, Weizheng Wang

#include <Wire.h>
#include <INA219_WE.h>

INA219_WE ina219; // this is the instantiation of the library for the current sensor

float open_loop, closed_loop; // Duty Cycles
float vm, iout, vout, dutyref,current_mA; // Measurement Variables
unsigned int sensorValue0,sensorValue1,sensorValue2,sensorValue3;  // ADC sample values declaration
float oc=0; //internal signals
float Ts=0.0008; //1.25 kHz control frequency. It's better to design the control period as integral multiple of switching period.

float current_limit;

unsigned int loopTrigger;

// Timer A CMP1 interrupt. Every 800us the program enters this interrupt. 
// This, clears the incoming interrupt flag and triggers the main loop.

ISR(TCA0_CMP1_vect){

  TCA0.SINGLE.INTFLAGS |= TCA_SINGLE_CMP1_bm; //clear interrupt flag
  loopTrigger = 1;

}

// This subroutine processes all of the analogue samples, creating the required values for the main loop

float saturation( float sat_input, float uplim, float lowlim){ // Saturation function

  if (sat_input > uplim) sat_input=uplim;
  else if (sat_input < lowlim ) sat_input=lowlim;
  else;
  return sat_input;
}

void sampling(){

  iout = ina219.getCurrent_mA();   
  vout = analogRead(A0) * (4.096 / 1023.0)*2;
  vm = analogRead(A3) * (4.096 / 1023.0)*890/330;
}


void pwm_modulate(float pwm_input){ // PWM function

  analogWrite(6,(int)(255-pwm_input*255)); 

}

void setup() {

  //Basic pin setups
  
  noInterrupts(); //disable all interrupts
  pinMode(13, OUTPUT);  //Pin13 is used to time the loops of the controller
  analogReference(EXTERNAL); // We are using an external analogue reference for the ADC

  // TimerA0 initialization for control-loop interrupt.
  
  TCA0.SINGLE.PER = 9999; //
  TCA0.SINGLE.CMP1 = 9999; //
  TCA0.SINGLE.CTRLA = TCA_SINGLE_CLKSEL_DIV16_gc | TCA_SINGLE_ENABLE_bm; //16 prescaler, 1M.
  TCA0.SINGLE.INTCTRL = TCA_SINGLE_CMP1_bm; 

  // TimerB0 initialization for PWM output
  
  pinMode(6, OUTPUT);
  TCB0.CTRLA=TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm; //62.5kHz
  pwm_modulate(0.85);

  interrupts();  //enable interrupts.
  Wire.begin(); // We need this for the i2c comms for the current sensor
  ina219.init(); // this initiates the current sensor
  Wire.setClock(700000); // set the comms speed for i2c
  Serial.begin(115200);
  
}

 void loop() {

  if(loopTrigger) { 
    
    digitalWrite(13, HIGH);  
    sampling();

    current_limit = 2000; 
    oc = iout-current_limit; 
    if ( oc > 0) {

      open_loop=open_loop-0.001; 

    } else {

      open_loop=open_loop+0.001; 

    }
      open_loop=saturation(open_loop,dutyref,0); 
      pwm_modulate(open_loop); 
    }

    if (iout < 25){

      dutyref = 5/vm;
      dutyref = saturation(dutyref, 1.0, 0.1);

    }
    else if (iout < 150){

      dutyref = 1;
    }
    else {

      dutyref = 0.85;
    }
    // closed loop control path

    pwm_modulate(dutyref);
    Serial.println(dutyref);

    digitalWrite(13, LOW);   // reset pin13.
    loopTrigger = 0;
  
}
