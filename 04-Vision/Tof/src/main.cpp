#include <Arduino.h>
#include "Adafruit_VL53L0X.h"
//#include <../lib/ultrasound.h>

// extern float avgDistanceFront, avgDistanceBack, avgDistanceLeft, avgDistanceRight;
float LeftToF, CenterToF, RightToF, TopToF;
float angle;

// address we will assign if dual sensor is present
#define LOX1_ADDRESS 0x30
#define LOX2_ADDRESS 0x31
#define LOX3_ADDRESS 0x32
#define LOX4_ADDRESS 0x33

// set the pins to shutdown
#define SHT_LOX1 6
#define SHT_LOX2 7
#define SHT_LOX3 8
// #define SHT_LOX4 9
// objects for the vl53l0x
Adafruit_VL53L0X lox1 = Adafruit_VL53L0X();
Adafruit_VL53L0X lox2 = Adafruit_VL53L0X();
Adafruit_VL53L0X lox3 = Adafruit_VL53L0X();
// Adafruit_VL53L0X lox4 = Adafruit_VL53L0X();

// this holds the measurement
VL53L0X_RangingMeasurementData_t measure1;
VL53L0X_RangingMeasurementData_t measure2;
VL53L0X_RangingMeasurementData_t measure3;
// VL53L0X_RangingMeasurementData_t measure4;

/*
    Reset all sensors by setting all of their XSHUT pins low for delay(10), then set all XSHUT high to bring out of reset
    Keep sensor #1 awake by keeping XSHUT pin high
    Put all other sensors into shutdown by pulling XSHUT pins low
    Initialize sensor #1 with lox.begin(new_i2c_address) Pick any number but 0x29 and it must be under 0x7F. Going with 0x30 to 0x3F is probably OK.
    Keep sensor #1 awake, and now bring sensor #2 out of reset by setting its XSHUT pin high.
    Initialize sensor #2 with lox.begin(new_i2c_address) Pick any number but 0x29 and whatever you set the first sensor to
 */
void setID()
{
  // all reset
  digitalWrite(SHT_LOX1, LOW);
  digitalWrite(SHT_LOX2, LOW);
  digitalWrite(SHT_LOX3, LOW);
//   digitalWrite(SHT_LOX4, LOW);
  delay(10);
  // all unreset
  digitalWrite(SHT_LOX1, HIGH);
  digitalWrite(SHT_LOX2, HIGH);
  digitalWrite(SHT_LOX3, HIGH);
 // digitalWrite(SHT_LOX4, HIGH);
  delay(10);

  // // activating LOX1 and resetting LOX2
  digitalWrite(SHT_LOX1, HIGH);
  digitalWrite(SHT_LOX2, LOW);
  digitalWrite(SHT_LOX3, LOW);
//  digitalWrite(SHT_LOX4, LOW);

  Serial.println("written");

  // //initing LOX1

  lox1.begin(LOX1_ADDRESS);

  Serial.println("attempted");

  if (!lox1.begin(LOX1_ADDRESS))
  {
    Serial.println(F("Failed to boot first VL53L0X"));
    while (1)
      ;
  }
  delay(10);

  Serial.println("oneset");

  // activating LOX2
  digitalWrite(SHT_LOX2, HIGH);
  delay(10);

  // initing LOX2
  if (!lox2.begin(LOX2_ADDRESS))
  {
    Serial.println(F("Failed to boot second VL53L0X"));
    while (1)
      ;
  }

  // activating LOX3
  digitalWrite(SHT_LOX3, HIGH);
  delay(10);

  // initing LOX3
  if (!lox3.begin(LOX3_ADDRESS))
  {
    Serial.println(F("Failed to boot third VL53L0X"));
    while (1)
      ;
  }

//   // activating LOX4
//   digitalWrite(SHT_LOX4, HIGH);
//   delay(10);

//   // initing LOX4
//   if (!lox4.begin(LOX4_ADDRESS))
//   {
//     Serial.println(F("Failed to boot fourth VL53L0X"));
//     while (1)
//       ;
//   }
}

void read_dual_sensors()
{

  lox1.rangingTest(&measure1, false); // pass in 'true' to get debug data printout!
  lox2.rangingTest(&measure2, false); // pass in 'true' to get debug data printout!
  lox3.rangingTest(&measure3, false); // pass in 'true' to get debug data printout!
//  lox4.rangingTest(&measure4, false); // pass in 'true' to get debug data printout!

  // print sensor one reading
  Serial.print(F("1: "));
  if (measure1.RangeStatus != 4)
  { // Center
    Serial.print(measure1.RangeMilliMeter);
    CenterToF = float(measure1.RangeMilliMeter);
  }
  else
  {
    Serial.print(F("Out of range"));
  }

  Serial.print(F(" "));

  // print sensor two reading
  Serial.print(F("2: "));
  if (measure2.RangeStatus != 4)
  { // Right
    Serial.print(measure2.RangeMilliMeter);
    RightToF = float(measure2.RangeMilliMeter);
  }
  else
  {
    Serial.print(F("Out of range"));
  }
  Serial.print(F(" "));

  // print sensor three reading
  Serial.print(F("3: "));
  if (measure3.RangeStatus != 4)
  { // Left
    Serial.print(measure3.RangeMilliMeter);
    LeftToF = float(measure3.RangeMilliMeter);
  }
  else
  {
    Serial.print(F("Out of range"));
  }
  Serial.print(F(" "));

  // print sensor three reading
//   Serial.print(F("4: "));
//   if (measure4.RangeStatus != 4)
//   { // TOP
//     Serial.print(measure4.RangeMilliMeter);
//     TopToF = float(measure4.RangeMilliMeter);
//   }
//   else
//   {
//     Serial.print(F("Out of range"));
//   }
//   Serial.print(F(" "));
//   Serial.println();
}
void send_message()
{
  if (Serial1.available())
  {
    char incomingByte = char(Serial1.read());
    if (incomingByte == 'r')
    {
      Serial.println(incomingByte);
      // This is the part bring the whole demo down   GGGGGGGGGGGG
      // left center right top    {                         top: 2 }
      //String message = '<' + String(measure3.RangeMilliMeter) + ',' + String(0) + ',' + String(measure2.RangeMilliMeter) + ',' + String(measure1.RangeMilliMeter) + '>';

       String message = '<' + String(measure3.RangeMilliMeter) + ',' + String(900) + ',' + String(measure2.RangeMilliMeter) + ',' + String(measure1.RangeMilliMeter) + '>';
      //  String message = '<'+ String(800) +',' + String(800) + ',' + String(800) + ',' + String(800) + '>';
      Serial1.print(message);
      Serial.println(message);
    }
  }
}
void setup()
{
  Serial1.begin(9600);
  Serial.begin(115200);

  // wait until serial port opens for native USB devices
  while (!Serial)
  {
    delay(1);
  }
  delay(50);
  pinMode(SHT_LOX1, OUTPUT);
  pinMode(SHT_LOX2, OUTPUT);
  pinMode(SHT_LOX3, OUTPUT);
 // pinMode(SHT_LOX4, OUTPUT);

  Serial.println(F("Shutdown pins inited..."));

  digitalWrite(SHT_LOX1, LOW);
  digitalWrite(SHT_LOX2, LOW);
  digitalWrite(SHT_LOX3, LOW);
  //digitalWrite(SHT_LOX4, LOW);

  Serial.println(F("Both in reset mode...(pins are low)"));

  Serial.println(F("Starting..."));
  delay(50);
  setID();
}

void loop()
{
  Serial.println("inloop");
  read_dual_sensors();
  send_message();
  delay(100);
}
