#include <Arduino.h>
#include "SPI.h"
#include <rover_drive.h>

#define BUTTON 

roverdrive rover;


// initialize timer -----------------------------------------------------------------------------
/*
hw_timer_t* timer = NULL;
volatile SemaphoreHandle_t timerSemaphore;
portMUX_TYPE timerMux = portMUX_INITIALIZER_UNLOCKED;

volatile uint32_t isrCounter = 0;
volatile uint32_t lastIsrAt = 0;


void ARDUINO_ISR_ATTR onTimer() 
{
  portENTER_CRITICAL_ISR(&timerMux);
  isrCounter++;
  lastIsrAt = millis();
  portEXIT_CRITICAL_ISR(&timerMux);
  xSemaphoreGiveFromISR(timerSemaphore, NULL);

}*/


// setup code ------------------------------------------------------------------------------------


void setup()
{
  Serial.begin(9600);

  rover.start();
}


// run code ---------------------------------------------------------------------------------------

void loop()
{
  rover.tracktimer();
  
}
  