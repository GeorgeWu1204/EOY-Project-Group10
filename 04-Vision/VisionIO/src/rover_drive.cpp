#ifndef ROVER_DRIVE_H
#define ROVER_DRIVE_H

#include <Arduino.h>
#include <SPI.h>
#include <rover_drive.h>
#include <cmath>

hw_timer_t* timer = NULL;
volatile bool sample = false;

int sgn = 1;

float Ts = 0.001;

float e1r = 0, u1r = 0;
float e1phi = 0, u1phi = 0;
float e1vl = 0, u1vl = 0;
float e1vr = 0, u1vr = 0;

float rtarget = 0, phitarget = 0;
float rref = 0, phiref = 0;
float velref = 0, omegaref = 0;
float rerr = 0, phierr = 0;
float velerr = 0, omegaerr = 0;
float dleft = 0, dright = 0;
float vleft = 0, vright = 0;
float tminphi = 0;
float tminr = 0;
float phi0 = 0;
float r0 = 0;

int count = 0;

void ARDUINO_ISR_ATTR onTimer() {

  sample = true;
  count++;

}

roverdrive::roverdrive () {

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

  #define PWMA  17
  #define AI1   21
  #define AI2   16

  #define PWMB  2
  #define BI1   4
  #define BI2   27

}

// private

int roverdrive::convTwosComp(int b) {

  if (b & 0x80) {
      b = -1 * ((b ^ 0xff) + 1);
  }
  return b;

}

void roverdrive::mousecam_reset() {

  digitalWrite(PIN_MOUSECAM_RESET,HIGH);
  delay(1);
  digitalWrite(PIN_MOUSECAM_RESET,LOW);
  delay(35);

}

void roverdrive::mousecam_init() {

  pinMode(PIN_MOUSECAM_RESET,OUTPUT);
  pinMode(PIN_MOUSECAM_CS,OUTPUT);

  digitalWrite(PIN_MOUSECAM_CS,HIGH);

  this->mousecam_reset();

}

void roverdrive::mousecam_write_reg(int reg, int val) {

  digitalWrite(PIN_MOUSECAM_CS, LOW);
  SPI.transfer(reg | 0x80);
  SPI.transfer(val);
  digitalWrite(PIN_MOUSECAM_CS,HIGH);
  delayMicroseconds(50);

}

int roverdrive::mousecam_read_reg(int reg) {

  digitalWrite(PIN_MOUSECAM_CS, LOW);
  SPI.transfer(reg);
  delayMicroseconds(75);
  int ret = SPI.transfer(0xff);
  digitalWrite(PIN_MOUSECAM_CS,HIGH);
  delayMicroseconds(1);
  return ret;

}

void roverdrive::mousecam_read_motion() {

  digitalWrite(PIN_MOUSECAM_CS, LOW);
  SPI.transfer(ADNS3080_MOTION_BURST);
  delayMicroseconds(75);
  this->motion =  SPI.transfer(0xff);
  this->dxreg =  SPI.transfer(0xff);
  this->dyreg =  SPI.transfer(0xff);
  this->squalreg =  SPI.transfer(0xff);
  this->shutter =  SPI.transfer(0xff)<<8;
  this->shutter |=  SPI.transfer(0xff);
  this->max_pix =  SPI.transfer(0xff);
  digitalWrite(PIN_MOUSECAM_CS,HIGH);
  delayMicroseconds(5);

}

// public

void roverdrive::start() {

  noInterrupts();

  pinMode(PIN_SS,OUTPUT);
  pinMode(PIN_MISO,INPUT);
  pinMode(PIN_MOSI,OUTPUT);
  pinMode(PIN_SCK,OUTPUT);

  //Serial.begin(9600);

  SPI.begin();
  SPI.setClockDivider(SPI_CLOCK_DIV32);
  SPI.setDataMode(SPI_MODE3);
  SPI.setBitOrder(MSBFIRST);

  this->mousecam_init();

  pinMode(AI1, OUTPUT);
  pinMode(AI2, OUTPUT);
  pinMode(BI1, OUTPUT);
  pinMode(BI2, OUTPUT);

  ledcSetup(1,5000,12);
  ledcAttachPin(PWMA,1);
  ledcSetup(2,5000,12);
  ledcAttachPin(PWMB,2);

  int econfig = this->mousecam_read_reg(ADNS3080_EXTENDED_CONFIG);
  this->mousecam_write_reg(ADNS3080_EXTENDED_CONFIG, econfig | 0x01);

  timer = timerBegin(0, 80, true); //divide 80 MHz clock to give 1 micro second
  timerAttachInterrupt(timer, &(onTimer), true);
  timerAlarmWrite(timer, Ts/1e-6, true); // 1 milli second sampling time
  timerAlarmEnable(timer);

  //pinMode(21, OUTPUT); // timing check

  //Serial.println(sample);

  interrupts();

}

void roverdrive::measure() {

    this->mousecam_read_motion();

    this->dr = this->convTwosComp(this->dyreg)*this->scale;
    this->dphi = this->convTwosComp(this->dxreg)*this->scale/120;

    this->dx = this->dr*std::cos(this->theta);
    this->dy = this->dr*std::sin(this->theta);

    this->x = this->x+this->dx;
    this->y = this->y+this->dy;
    this->theta = this->theta+this->dphi;

    this->r = this->r+this->dr;
    this->phi = this->phi+this->dphi;

    this->vel = this->dr/Ts;
    this->omega = this->dphi/Ts;

    this->squal = this->squalreg/4;

}

void roverdrive::motorA(float v) {

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
  else{
    ledcWrite(1,std::abs(v)*4095);
  }

}

void roverdrive::motorB(float v) {

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
  else{
    ledcWrite(2,std::abs(v)*4095);
  }

}

void roverdrive::brake() {

  digitalWrite(BI1, HIGH);
  digitalWrite(BI2, HIGH);
  digitalWrite(AI1, HIGH);
  digitalWrite(AI2, HIGH);

}

void roverdrive::translateToTarget(float rtarget) {

  if (rtarget < 0) {
    sgn = -1;
  }
  else {
    sgn = 1;
  }

  while (sgn*(this->r-rtarget) < 0) {

    if (sample) {

      this->measure();

      this->motorA(sgn*0.5+this->phi);
      this->motorB(sgn*0.5-this->phi);

      sample = false;

    }

  }

  if (sgn*(this->r-rtarget) > 0) {

    this->brake();

    this->r = 0;
    this->phi = 0;

  }

}

/*void roverdrive::translateToTarget(float rtarget) {

  if (rtarget < 0) {
    sgn = -1;
  }
  else {
    sgn = 1;
  }

  if (sample) {

    this->measure();

    this->motorA(sgn*0.5+this->phi);
    this->motorB(sgn*0.5-this->phi);

    if (sgn*(this->r-rtarget) > 0) {

      this->brake();

      delay(1000);

      this->r = 0;
      this->phi = 0;

      this->state++;

    }

    sample = false;

  }

}*/

void roverdrive::rotate(float omega, bool stop) {

  if (stop == false) {

    this->motorA(-omega);
    this->motorB(omega);

  }
  else {

    this->brake();

  }

}

/*void roverdrive::rotateToTarget(float phitarget) {

  if (phitarget < 0) {
    sgn = -1;
  }
  else {
    sgn = 1;
  }

  while (sgn*(this->phi-phitarget) < 0) {

    if (sample) {

      this->measure();

      this->motorA(sgn*(-0.5)-0.02*this->r);
      this->motorB(sgn*0.5-0.02*this->r);

      sample = false;

    }

  }

  this->brake();

  delay(1000);

  this->r = 0;
  this->phi = 0;

  this->state++;

}*/

void roverdrive::rotateBack() {

  this->measure();

  if (this->phi > 0) {
    sgn = -1;
  }
  else {
    sgn = 1;
  }

  while (sgn*(this->phi) < 0) {

    if (count >= 99) {

      count = 0;

      this->measure();
    
    }

    this->motorA(sgn*-0.2);
    this->motorB(sgn*0.2);

  }

  if (sgn*(this->phi-phitarget) > 0) {

    this->brake();

    this->r = 0;
    this->phi = 0;

  }

}

void roverdrive::rotateToTarget(float phitarget, float omega) {

  if (phitarget < 0) {
    sgn = -1;
  }
  else {
    sgn = 1;
  }

  while (sgn*(this->phi-phitarget) < 0) {

    if (sample){

      this->measure();

      this->motorA(sgn*(-omega)-0.01*this->r);
      this->motorB(sgn*omega-0.01*this->r);

      sample = false;
    
    }

  }

  if (sgn*(this->phi-phitarget) > 0) {

    this->brake();

    this->r = 0;
    this->phi = 0;

  }

}

// DO NOT USE

float roverdrive::pid(float input, float kp, float ki, bool limit, float& e1, float& u1) {

  float e_int = input;

  if (limit) {
    if(u1 >= 1 || u1 <= -1) {
      e_int = 0;
    }
  }

  float u0 = u1 + kp*(input-e1) + ki*Ts*e_int;

  if (limit) {
    if (u0 < -1) {
      u0 = -1; 
    } 
    else if (u0 > 1) {
      u0 = 1;
    }
  }
  
  u1 = u0;
  return u0;

}

void roverdrive::twopoint (float x, float y) {

  if (this->state == 0){

    this->measure();

    rtarget = std::sqrt(std::pow(x-this->x,2)+std::pow(y-this->y,2));
    phitarget = std::atan((y-this->y)/(x-this->x));

    tminphi = (phitarget-this->phi)/(2.5*Ts);
    phi0 = this->phi;

    tminr = (rtarget-this->r)/(200*Ts);
    r0 = this->r;

    this->state = 2;

  }

  if (sample && this->state == 2) {

    this->measure();

    rerr = rref-this->r;
    phierr = phiref-this->phi;

    velref = this->pid(rerr,8.63,0.0052,false,e1r,u1r);
    omegaref = this->pid(phierr,8.4,0.00178,false,e1phi,u1phi);

    velerr = velref-this->vel;
    omegaerr = omegaref-this->omega;

    dleft = -0.1815*velerr + 15.86*omegaerr;
    dright = 1.363*velerr + 5.335*omegaerr;

    vleft = this->pid(dleft,-0.272,-2.13,true,e1vl,u1vl);
    vright = this->pid(dright,0.0719,1.69,true,e1vr,u1vr);

    /*vleft = 0.8051*dleft + -3.369*dright;
    vright = 0.4139*dleft + 34.7*dright;

    dleft = this->pid(velerr,0.0796,0.579,true,e1vl,u1vl);
    dright = this->pid(omegaerr,0.0849,0.617,true,e1vr,u1vr);*/

    this->motorA(vleft);
    this->motorB(vright);

    sample = false;

    if (this->state == 1) {

      if (count < tminphi) {

        phiref = phi0+count*(phitarget-phi0)/tminphi;

      }
      else {

        this->motorA(0);
        this->motorB(0);

        this->state = 2;

        count = 0;

      }

    }

    if (this->state == 2) {

      if (count < tminr) {

        rref = r0+count*(rtarget-r0)/tminr;

      }

      else {

        this->motorA(0);
        this->motorB(0);

        this->state = 3;

        count = 0;

      }

    }

  }

}

void roverdrive::fixedvel(float velref) {

  if (sample) {

    velref = count*velref/5000;

    this->measure();

    velerr = velref-this->vel;
    omegaerr = 0-this->omega;

    dleft = -0.1815*velerr + 15.86*omegaerr;
    dright = 1.363*velerr + 5.335*omegaerr;

    vleft = this->pid(dleft,-0.272,-2.13,true,e1vl,u1vl);
    vright = this->pid(dright,0.0719,1.69,true,e1vr,u1vr);

    this->motorA(vleft);
    this->motorB(vright);

  }

}

#endif