#include <Arduino.h>
#include <rover_drive.h>

bool arrive = false;

void setup() {
  
  roverBegin();
  Serial.begin(115200);
  delay(2000);

}

void loop() {
  
  delay(100);
  
  roverTranslateToTarget(600, 0.5);
  
  if(getRoverX() < 605){

    Serial.println(String(getRoverX()) + ", " + String(roverDetectRadar()));
  }
  /*
  if (arrive == false){
    //roverRotateToTarget(2*PI, 0.5);
    Serial.println(String(getRoverTheta(true)) + ", " + String(roverDetectRadar()));

  }

  if (getRoverTheta(true) >360){
    arrive = true;
    roverStop();

  }

*/
}