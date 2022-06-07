#include <Arduino.h>
#include <vector>
#include <cmath>
#include <numeric>

#define RADAR_PIN 2 // to be finalised
#define DETECTED_PIN 4

float signal_amplitude;
std::vector<float> v(10);

hw_timer_t* timer = NULL;
volatile bool sample = false;
float Ts = 0.1;

float moving_average;

void ARDUINO_ISR_ATTR onTimer() { // sampling for radar signal measurement 

  sample = true;

}

float movingAverage (std::vector<float> &moving_sum, float input){

  moving_sum.erase(moving_sum.begin()); // erase first element in vector
  moving_sum.push_back(input); // add latest sample after last element
  
  return accumulate(moving_sum.begin(), moving_sum.end(), 0.0)/10;

}


void setup() {

  Serial.begin(115200);

  pinMode(RADAR_PIN, INPUT);

  pinMode(DETECTED_PIN, OUTPUT);

  v.resize(10, 0);

  timer = timerBegin(0, 80, true); //divide 80 MHz clock to give 1 micro second
  timerAttachInterrupt(timer, &(onTimer), true);
  timerAlarmWrite(timer, Ts/1e-6, true); // 1 milli second sampling time
  timerAlarmEnable(timer);

}

void loop() {

  if (sample){

    signal_amplitude = analogRead(RADAR_PIN)*3.3/4095;
    
    moving_average = movingAverage(v, signal_amplitude);

    Serial.println("signal amplitude : " + String(signal_amplitude));
    Serial.println("moving_average : " + String(moving_average));

    if (moving_average > 1){

      Serial.println("Underground power station detected");

      digitalWrite(DETECTED_PIN, HIGH);
  
    }
    else {

      Serial.println("Locating fan......");

      digitalWrite(DETECTED_PIN, LOW);

    }

    sample = false;

  }
  
  // alternatively, constantly send data to database and locate fan at the end of movement by retrieving coordinates at maximum

}