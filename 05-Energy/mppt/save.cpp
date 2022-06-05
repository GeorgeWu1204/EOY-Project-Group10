// max system clk - 16-20MHz
// https://docs.platformio.org/en/stable//boards/atmelmegaavr/nano_every.html
// control loop freq - 1-1.25kHz

#include <Arduino.h>
#include <SPI.h>
#include <Wire.h>
#include <INA219_WE.h>
#include <SD.h>

#define ARDUINO_LED_BUILT_IN    13
#define OPEN_OR_CLOSED_LOOP     2
#define BUCK_OR_BOOST           3
#define PWM                     6
#define VO_INDICATOR_LED        21
#define TEST_PIN                20

INA219_WE ina219;

Sd2Card card;
SdVolume volume;
SdFile root;
const int chipSelect = 10;

bool Boost_mode = 0;
bool CL_mode = 0;

unsigned int sensorValue0, sensorValue1, sensorValue2, sensorValue3;
float current_mA, vpd0, vb, vref, iL0, dutyref;
float p0, p1, dv, dp, vpd1, iL1;
float open_loop, oc = 0;

String dataString;
String header;
String filename; // name that includes conditions, type of algorithm, load resistor value

int count = 0;
int loopTrigger = 0;

//-------------------------------------------------------------------------------------------------------------

float saturation(float sat_input, float uplim, float lowlim)
{ 
  if (sat_input > uplim) sat_input=uplim;
  else if (sat_input < lowlim ) sat_input=lowlim;
  else;
  return sat_input;
}

void sampling(){

  // Make the initial sampling operations for the circuit measurements
  
  sensorValue0 = analogRead(A0); //sample Vb
  sensorValue2 = analogRead(A2); //sample Vref
  sensorValue3 = analogRead(A3); //sample Vpd
  current_mA = ina219.getCurrent_mA(); // sample the inductor current (via the sensor chip)
  
  vb = sensorValue0 * (4.096 / 1023.0); // Convert the Vb sensor reading to volts
  vref = sensorValue2 * (4.096 / 1023.0); // Convert the Vref sensor reading to volts
  vpd0 = sensorValue3 * (4.096 / 1023.0); // Convert the Vpd sensor reading to volts

  // The inductor current is in mA from the sensor so we need to convert to amps.
  // We want to treat it as an input current in the Boost, so its also inverted
  // For open loop control the duty cycle reference is calculated from the sensor
  // differently from the Vref, this time scaled between zero and 1.
  // The boost duty cycle needs to be saturated with a 0.67 maximum to prevent high output voltages
  
  if (Boost_mode == 1){
    iL0 = -current_mA/1000.0;
    dutyref = saturation(sensorValue2 * (1.0 / 1023.0), 0.99, 0.5);
  }else{
    iL0 = current_mA/1000.0;
    dutyref = sensorValue2 * (1.0 / 1023.0);
  }
}

void pwm_modulate(float pwm_input)
{
  analogWrite(PWM, (int)(255-pwm_input*255)); 
}

void calculation(float iL0, float iL1, float vpd0, float vpd1)
{
  p0 = (vpd0/330*890)*iL0;
  p1 = vpd1*iL1;
  dv = vpd0=vpd1;
  dp = p0-p1;
}


ISR(TCA0_CMP1_vect)
{
  TCA0.SINGLE.INTFLAGS |= TCA_SINGLE_CMP1_bm; //clear interrupt flag
  loopTrigger = 1;
}


void setup() // setup code ------------------------------------------------------------------------------------
{
  noInterrupts();
  
  Serial.begin(9600);
  // pin setup
  pinMode(ARDUINO_LED_BUILT_IN, OUTPUT);
  pinMode(OPEN_OR_CLOSED_LOOP, INPUT_PULLUP);
  pinMode(BUCK_OR_BOOST, INPUT_PULLUP);
  pinMode(VO_INDICATOR_LED, OUTPUT);
  pinMode(TEST_PIN, OUTPUT);
  analogReference(EXTERNAL);

  Serial.println("Start of setup");

  // TimerA0 initialization for control-loop interrupt.
  TCA0.SINGLE.PER = 999; // set period 
  TCA0.SINGLE.CMP1 = 999; // set compare value
  TCA0.SINGLE.INTCTRL = TCA_SINGLE_CMP1_bm; // enable compare with channel 1 interrupt
  TCA0.SINGLE.CTRLA = TCA_SINGLE_CLKSEL_DIV16_gc | TCA_SINGLE_ENABLE_bm; // system clock/16, ~1MHz.
  TCA0.SINGLE.EVCTRL &= ~(TCA_SINGLE_CNTEI_bm); // disable event counting
  
  // TimerB0 initialization for PWM output
  pinMode(PWM, OUTPUT);
  TCB0.CTRLA = TCB_CLKSEL_CLKDIV1_gc | TCB_ENABLE_bm; // 62.5kHz?
  pwm_modulate(0.5); //initial duty cycle
  Serial.println("Set initial duty cycle to 0.5");
  
  
  interrupts();
  Wire.begin(); 
  Wire.setClock(700000); // comms speed for i2c
  ina219.init();
  
  // Check SD card
  Serial.println("\nInitializing SD card...");
  
  if (!SD.begin(chipSelect)) 
  {
    Serial.println("* is a card inserted?");
    while (true) {}
  } 
  else {
    Serial.println("Wiring is correct and a card is present.");
  }

  if (SD.exists("SD_Test.csv")) { 
    Serial.println("file already exist, file will be rewritten");
    SD.remove("SD_Test.csv");
  }
  
  
  
}


void loop() // start of loop ---------------------------------------------------------------------------------------
{
  if (loopTrigger)
  {
    Serial.println("Set LED BUILTIN to high");
    digitalWrite(LED_BUILTIN, HIGH);
    
    sampling();

    vpd1 = vpd0;
    iL1 = iL0;

    calculation(iL0, iL1, vpd0, vpd1);

    if ((vpd0/330*890) > 5)
    {
      analogWrite(VO_INDICATOR_LED, 255*((vpd0/330*890-4)/11.8)); // LED turns on when output voltage has reached 4V
    }

    CL_mode = digitalRead(OPEN_OR_CLOSED_LOOP);
    Boost_mode = digitalRead(BUCK_OR_BOOST);

    if(Boost_mode)
    {
      if (CL_mode)
      {
        pwm_modulate(0);
        // yet to be implemented
      }
      else // mppt algorithm
      {
        int current_limit = 2; // 
        oc = iL0-current_limit; // Calculate the difference between current measurement and current limit
        if ( oc > 0) {
          open_loop=open_loop+0.001; // We are above the current limit so less duty cycle
        } else {
          open_loop=open_loop-0.001; // We are below the current limit so more duty cycle
        }
        open_loop=saturation(open_loop, 0.99, dutyref); // saturate the duty cycle at the reference or a min of 0.01
        pwm_modulate(open_loop); // and send it out
        /*
        if (dp > 0)
        {
          if (dv > 0)
          {
            pwm_modulate(dutyref+1);
          }
          else 
          {
            pwm_modulate(dutyref-1);
          }
        }
        else
        {
          if (dv > 0)
          {
            pwm_modulate(dutyref-1);
          }
          else
          {
            pwm_modulate(dutyref+1);
          }
        }
        
        count++;*/
      }
    }
    else //disable buck
    {      
      if (CL_mode) {
        pwm_modulate(1); 
      }
      else
      {
        pwm_modulate(1);
      }
    }

    header = "count, PV voltage, PV current, output voltage, power";
    dataString = String(count) + "," + String(vb) + "," + String(iL0) + "," + String(vpd0/330*890) + "," + String(p0); 

    Serial.println(dataString); 

    File dataFile = SD.open("SD_Test.csv", FILE_WRITE); 
    
    if (dataFile){ 
      dataFile.println(header + '\n' + dataString); 
    } else {
      Serial.println("File not open"); 
    }
    dataFile.close(); 
  }
}

