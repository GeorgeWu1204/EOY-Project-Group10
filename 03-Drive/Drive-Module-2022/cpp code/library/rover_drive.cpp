#include <Arduino.h>
#include <SPI.h>
#include <rover_drive.h>
#include <cmath>

// rover state machine

enum roverstate {

  idle, 
  measurement, 
  rotation, 
  translation, 
  rotationToTarget, 
  translationToTarget, 
  slowRotation, 
  slowRotationBack

};

volatile roverstate state = idle;

// rover global coordinates, never reset unless requested

float x = 0;
float y = 0;
float theta = 0;

// local coodinates, reset during movements to target and rotation back

float r = 0;
float phi = 0;

// rover coordinate changes, with respect to optical flow sensor

float dx;
float dy;
float dr;
float dphi;

// surface quality seen by optical flow sensor

int squal;

// readings of optical flow sensor registers

int motion;
int squalreg;
int dxreg;
int dyreg;
int shutter;
int max_pix;

// tunable parameters, to be tuned more carefully, just a rough estimate for now

float opticalFlowScale = 0.2;
float distanceToCenter = 120;

float Pphi = 1;
float Pr = 0.01;

// direction of movement

int sgn = 1;

// movement target and speed to reach target

volatile float target;
volatile float speed;

// task handles for Core 0, setup task and loop task respectively

TaskHandle_t startTask;
TaskHandle_t driveTask;

// semaphore handle to check for movement completion

SemaphoreHandle_t driveSemaphore;

// timing logic for sampling and control

hw_timer_t* timer = NULL;
volatile bool sample = false;
float Ts = 0.001;
volatile int count = 0;

void IRAM_ATTR sampling() {

  sample = true;
  count++;

}

// ESP32 pins, parameters and addresses of optical flow sensor

#define PIN_SS      5
#define PIN_MISO    19
#define PIN_MOSI    23
#define PIN_SCK     18

#define PIN_MOUSECAM_RESET  22
#define PIN_MOUSECAM_CS     5

#define ADNS3080_PIXELS_X   30
#define ADNS3080_PIXELS_Y   30

#define ADNS3080_PRODUCT_ID                     0x00
#define ADNS3080_REVISION_ID                    0x01
#define ADNS3080_MOTION                         0x02
#define ADNS3080_DELTA_X                        0x03
#define ADNS3080_DELTA_Y                        0x04
#define ADNS3080_SQUAL                          0x05
#define ADNS3080_PIXEL_SUM                      0x06
#define ADNS3080_MAXIMUM_PIXEL                  0x07
#define ADNS3080_CONFIGURATION_BITS             0x0a
#define ADNS3080_EXTENDED_CONFIG                0x0b
#define ADNS3080_DATA_OUT_LOWER                 0x0c
#define ADNS3080_DATA_OUT_UPPER                 0x0d
#define ADNS3080_SHUTTER_LOWER                  0x0e
#define ADNS3080_SHUTTER_UPPER                  0x0f
#define ADNS3080_FRAME_PERIOD_LOWER             0x10
#define ADNS3080_FRAME_PERIOD_UPPER             0x11
#define ADNS3080_MOTION_CLEAR                   0x12
#define ADNS3080_FRAME_CAPTURE                  0x13
#define ADNS3080_SROM_ENABLE                    0x14
#define ADNS3080_FRAME_PERIOD_MAX_BOUND_LOWER   0x19
#define ADNS3080_FRAME_PERIOD_MAX_BOUND_UPPER   0x1a
#define ADNS3080_FRAME_PERIOD_MIN_BOUND_LOWER   0x1b
#define ADNS3080_FRAME_PERIOD_MIN_BOUND_UPPER   0x1c
#define ADNS3080_SHUTTER_MAX_BOUND_LOWER        0x1d
#define ADNS3080_SHUTTER_MAX_BOUND_UPPER        0x1e
#define ADNS3080_SROM_ID                        0x1f
#define ADNS3080_OBSERVATION                    0x3d
#define ADNS3080_INVERSE_PRODUCT_ID             0x3f
#define ADNS3080_PIXEL_BURST                    0x40
#define ADNS3080_MOTION_BURST                   0x50
#define ADNS3080_SROM_LOAD                      0x60

// ESP32 pins of motors and H-bridge

#define PWMA  17
#define AI1   21
#define AI2   16

#define PWMB  2
#define BI1   4
#define BI2   27

#define STOPPIN 25

// optical flow sensor functions already provided

int convTwosComp(int b) {

  if (b & 0x80) {
      b = -1 * ((b ^ 0xff) + 1);
  }
  return b;

}

void mousecam_reset() {

  digitalWrite(PIN_MOUSECAM_RESET,HIGH);
  delay(1);
  digitalWrite(PIN_MOUSECAM_RESET,LOW);
  delay(35);

}

void mousecam_init() {

  pinMode(PIN_MOUSECAM_RESET,OUTPUT);
  pinMode(PIN_MOUSECAM_CS,OUTPUT);

  digitalWrite(PIN_MOUSECAM_CS,HIGH);

  mousecam_reset();

}

void mousecam_write_reg(int reg, int val) {

  digitalWrite(PIN_MOUSECAM_CS, LOW);
  SPI.transfer(reg | 0x80);
  SPI.transfer(val);
  digitalWrite(PIN_MOUSECAM_CS,HIGH);
  delayMicroseconds(50);

}

int mousecam_read_reg(int reg) {

  digitalWrite(PIN_MOUSECAM_CS, LOW);
  SPI.transfer(reg);
  delayMicroseconds(75);
  int ret = SPI.transfer(0xff);
  digitalWrite(PIN_MOUSECAM_CS,HIGH);
  delayMicroseconds(1);
  return ret;

}

void mousecam_read_motion() {

  digitalWrite(PIN_MOUSECAM_CS, LOW);
  SPI.transfer(ADNS3080_MOTION_BURST);
  delayMicroseconds(75);
  motion =  SPI.transfer(0xff);
  dxreg =  SPI.transfer(0xff);
  dyreg =  SPI.transfer(0xff);
  squalreg =  SPI.transfer(0xff);
  shutter =  SPI.transfer(0xff)<<8;
  shutter |=  SPI.transfer(0xff);
  max_pix =  SPI.transfer(0xff);
  digitalWrite(PIN_MOUSECAM_CS,HIGH);
  delayMicroseconds(5);

}

//----------------------------

// driving functions on Core 0

//----------------------------

void start(void * param) {  // setup the drive subsystem

  noInterrupts();

  pinMode(PIN_SS,OUTPUT);
  pinMode(PIN_MISO,INPUT);
  pinMode(PIN_MOSI,OUTPUT);
  pinMode(PIN_SCK,OUTPUT);

  SPI.begin();
  SPI.setClockDivider(SPI_CLOCK_DIV32);
  SPI.setDataMode(SPI_MODE3);
  SPI.setBitOrder(MSBFIRST);

  mousecam_init();

  pinMode(AI1, OUTPUT);
  pinMode(AI2, OUTPUT);
  pinMode(BI1, OUTPUT);
  pinMode(BI2, OUTPUT);

  pinMode(STOPPIN, INPUT);

  ledcSetup(1,5000,12);
  ledcAttachPin(PWMA,1);
  ledcSetup(2,5000,12);
  ledcAttachPin(PWMB,2);

  int econfig = mousecam_read_reg(ADNS3080_EXTENDED_CONFIG);
  mousecam_write_reg(ADNS3080_EXTENDED_CONFIG, econfig | 0x01);

  timer = timerBegin(0, 80, true);
  timerAttachInterrupt(timer, &(sampling), true);
  timerAlarmWrite(timer, Ts/1e-6, true);
  timerAlarmEnable(timer);

  driveSemaphore = xSemaphoreCreateBinary();
  xSemaphoreGive(driveSemaphore);

  interrupts();

  vTaskDelete(startTask);

}

void measure() {  // optical flow sensor measurements

    mousecam_read_motion();

    dr = convTwosComp(dyreg)*opticalFlowScale;
    dphi = convTwosComp(dxreg)*opticalFlowScale/distanceToCenter;

    dx = dr*std::cos(theta);
    dy = dr*std::sin(theta);

    x += dx;
    y += dy;
    theta += dphi;

    r += dr;
    phi += dphi;

    squal = squalreg*4;

}

void motorA(float v) {  // rotate motor A

  if (v < 0) {
    digitalWrite(AI1, HIGH);
    digitalWrite(AI2, LOW);
  }
  else {
    digitalWrite(AI1, LOW);
    digitalWrite(AI2, HIGH);
  }
  if (std::abs(v) > 1) {
    ledcWrite(1,4095);
  }
  else {
    ledcWrite(1,std::abs(v)*4095);
  }

}

void motorB(float v) {  // move motor B

  if (v < 0) {
    digitalWrite(BI1, LOW);
    digitalWrite(BI2, HIGH);
  }
  else {
    digitalWrite(BI1, HIGH);
    digitalWrite(BI2, LOW);
  }
  if (std::abs(v) > 1) {
    ledcWrite(2,4095);
  }
  else {
    ledcWrite(2,std::abs(v)*4095);
  }

}

void brake() {  // brake the rover, both motors brake

  digitalWrite(BI1, HIGH);
  digitalWrite(BI2, HIGH);
  digitalWrite(AI1, HIGH);
  digitalWrite(AI2, HIGH);

}

void translate(float v) { // continuously translate

  if (sample) {

    measure();

    motorA(sgn*v+Pphi*phi);
    motorB(sgn*v-Pphi*phi);

    sample = false;

  }

}

void rotate(float omega) {  // continuously rotate

  if (sample) {

    measure();

    motorA(sgn*(-omega)-Pr*r);
    motorB(sgn*omega-Pr*r);

    sample = false;

  }

}

void translateToTarget(float rtarget, float v) {  // translate to distance

  if (rtarget < 0) {
    sgn = -1;
  }
  else {
    sgn = 1;
  }

  if (sample) {

    measure();

    motorA(sgn*v+Pphi*phi);
    motorB(sgn*v-Pphi*phi);

    if (sgn*(r-rtarget) > 0) {

      brake();

      r = 0;
      phi = 0;

      xSemaphoreGive(driveSemaphore);
      state = idle;

    }

    sample = false;

  }

}

void rotateToTarget(float phitarget, float omega) { // rotate to angle

  if (phitarget < 0) {
    sgn = -1;
  }
  else {
    sgn = 1;
  }

  if (sample){

    measure();

    motorA(sgn*(-omega)-Pr*r);
    motorB(sgn*omega-Pr*r);

    if (sgn*(phi-phitarget) > 0) {

      brake();

      r = 0;
      phi = 0;

      xSemaphoreGive(driveSemaphore);
      state = idle;

    }

    sample = false;
  
  }

}

void slowRotate(float omega) {  // rotate with reduced sampling time

  if (count >= 99) {

    measure();

    count = 0;
    
  }

  motorA(-omega);
  motorB(omega);

}

void slowRotateBack(float omega) {  // rotate back with reduced sampling time

  if (phi > 0) {
    sgn = -1;
  }
  else {
    sgn = 1;
  }

  while (sgn*phi < 0) {

    if (count >= 99) {

      measure();

      count = 0;
    
    }

    motorA(sgn*(-omega));
    motorB(sgn*omega);

  }

  if (sgn*phi > 0) {

    brake();

    r = 0;
    phi = 0;

    xSemaphoreGive(driveSemaphore);
    state = idle;

  }

}

void drive(void * param) {  // main loop for drive subsystem

  for (;;) {

    switch (state) {

      case idle:
      brake();
      break;

      case measurement:
      measure();
      break;

      case translation:
      translate(speed);
      break;

      case rotation:
      rotate(speed);
      break;

      case translationToTarget:
      translateToTarget(target,speed);
      break;

      case rotationToTarget:
      rotateToTarget(target,speed);
      break;

      case slowRotation:
      slowRotate(speed);
      break;

      case slowRotationBack:
      slowRotateBack(speed);
      break;

    }

    if (digitalRead(STOPPIN) == HIGH) {

      brake();

      vTaskDelete(driveTask);

    }

  }

}

//---------------------------------------------------------------------

// functions available on Core 1 to control driving functions on Core 0

// --------------------------------------------------------------------

void roverBegin() { // set up rover tasks on Core 0

  xTaskCreatePinnedToCore(start,"start",10000,NULL,1,&startTask,0);

  xTaskCreatePinnedToCore(drive,"drive",10000,NULL,0,&driveTask,0);

}

void roverStop() {  // stops the current movement by returning to idle state

  xSemaphoreGive(driveSemaphore);

  state = idle;

}

void roverWait() {  // wait until the current movement is complete

  while (true) {

    if (xSemaphoreTake(driveSemaphore, (TickType_t) 0) == pdTRUE) {

      xSemaphoreGive(driveSemaphore);

      break;

    }

  }

}

void roverTranslate(float v) {  // continuously translate

  if (xSemaphoreTake(driveSemaphore, (TickType_t) 0) == pdTRUE) {

    speed = v;
    state = translation;

  }

}

void roverRotate(float omega) { // continuously rotate

  if (xSemaphoreTake(driveSemaphore, (TickType_t) 0) == pdTRUE) {
    
    speed = omega;
    state = rotation;

  }

}

void roverTranslateToTarget(float rtarget, float v) {  // translate to target distance

  if (xSemaphoreTake(driveSemaphore, (TickType_t) 0) == pdTRUE) {

    target = rtarget;
    speed = v;
    state = translationToTarget;

  }

}

void roverRotateToTarget(float phitarget, float omega) { // rotate to target angle

  if (xSemaphoreTake(driveSemaphore, (TickType_t) 0) == pdTRUE) {

    target = phitarget;
    speed = omega;
    state = rotationToTarget;

  }

}

void roverSlowRotate(float omega) { // rotate with reduced sampling time

  if (xSemaphoreTake(driveSemaphore, (TickType_t) 0) == pdTRUE) {

    speed = omega;
    state = slowRotation;

  }

}

void roverSlowRotateBack(float omega) { // rotate back with reduced sampling time

  if (xSemaphoreTake(driveSemaphore, (TickType_t) 0) == pdTRUE) {

    speed = omega;
    state = slowRotationBack;

  }

}

float getRoverX() { // returns the global x coordinate

  return x;

}

float getRoverY() { // returns the global y coordinate

  return y;
  
}

float getRoverTheta(bool degrees) { // returns the global orientation

  if (degrees) {

    return theta*180/PI;

  }

  else {

    return theta;

  }
  
}

float getRoverR() { // returns local r coordinate

  return r;

}

float getRoverPhi(bool degrees) { // returns local phi coordinate

  if (degrees) {

    return phi*180/PI;

  }

  else {

    return phi;

  }

}
