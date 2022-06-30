#include <Arduino.h>

#define SOUND_SPEED 0.034

const int usTrigFront = 12; 
const int usEchoFront = 11;

const int usTrigBack = 8;
const int usEchoBack = 7;

const int usTrigLeft = 6;
const int usEchoLeft = 5;

const int usTrigRight = 10;
const int usEchoRight = 9;

float distanceFront, distanceBack, distanceLeft, distanceRight = 0.0;
float avgDistanceFront, avgDistanceBack, avgDistanceLeft, avgDistanceRight = 0.0;

const int average_times = 3;
int index = 0;
float front[average_times], back[average_times], left[average_times], right[average_times];
double frontTotal, backTotal, leftTotal, rightTotal = 0.0;

float radarOffset = 4.00;


void moving_average(float newFront, float newBack, float newLeft, float newRight){
  float average;
  frontTotal -= front[index];
  front[index] = newFront;
  frontTotal += newFront;

  backTotal -= back[index];
  back[index] = newBack;
  backTotal += newBack;

  leftTotal -= left[index];
  left[index] = newLeft;
  leftTotal += newLeft;

  rightTotal -= right[index];
  right[index] = newRight;
  rightTotal += newRight;

  index += 1;
  if (index >= average_times){
    index = 0;
  }
  avgDistanceFront = double(long(frontTotal / average_times * 100))/100;
  avgDistanceBack = double(long(backTotal / average_times * 100))/100;
  avgDistanceLeft = double(long(leftTotal / average_times * 100))/100;
  avgDistanceRight = double(long(rightTotal / average_times * 100))/100;
}

float measure_distance(int trigPin, int echoPin){
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(1, LOW);
    float distance = pulseIn(echoPin, HIGH) * SOUND_SPEED/2;
    
    return distance;
}

void measure_all_distance(){
    distanceFront = measure_distance(usTrigFront, usEchoFront) + radarOffset; 
    distanceBack = measure_distance(usTrigBack, usEchoBack) + radarOffset;
    distanceLeft = measure_distance(usTrigLeft, usEchoLeft) + radarOffset;
    distanceRight = measure_distance(usTrigRight, usEchoRight) + radarOffset;

    moving_average(distanceFront, distanceBack, distanceLeft, distanceRight);

    // Serial.print(avgDistanceFront);
    // Serial.print(" ");
    // Serial.print(avgDistanceBack);
    // Serial.print(" ");
    // Serial.print(avgDistanceLeft);
    // Serial.print(" ");
    // Serial.println(avgDistanceRight);
}