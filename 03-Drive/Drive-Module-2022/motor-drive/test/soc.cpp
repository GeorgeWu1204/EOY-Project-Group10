#include <Arduino.h>
#include <rover_drive.h>
#include <vector>
#include <cmath>
#include <numeric>

bool arrive = false;



void setup() {

  pinMode(25, INPUT);
  
  roverBegin();
  Serial.begin(115200);
  delay(2000);


}

void loop() {


  //roverTranslate(0.5);

  readCapacity();
  
  Serial.println("current value: " + String(roverGetCurrent()));

  Serial.println("battery capacity: "+ String(roverGetSOC()));

}