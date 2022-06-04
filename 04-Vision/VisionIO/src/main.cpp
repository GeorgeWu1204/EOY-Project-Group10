#include <Arduino.h>
#include <SPI.h>
#include <bitset>
#include <map>
#include <rover_drive.h>
#include <bits/stdc++.h>
#include <string>
#define HSPI_MISO 12
#define HSPI_MOSI 13
#define HSPI_SCK 14
#define HSPI_SS 15
SPIClass *hspi = NULL;

roverdrive rover;

int received;
bool FPGA_ready = false;
// define VSPI_SS  SS

int special_code, previous_special_code;
int distance_messaage_count = 0;
int loop_start = 10;
int loop_end = 14;
bool distance_bool;

void setup()
{
  Serial.begin(9600);
  rover.start();
  hspi = new SPIClass(HSPI);
  hspi->begin(HSPI_SCK, HSPI_MISO, HSPI_MOSI, HSPI_SS);
  special_code = loop_start;
  // pinMode(HSPI_SS,OUTPUT);
  // pinMode(HSPI_MISO,INPUT);
  // pinMode(HSPI_MOSI,OUTPUT);
  // pinMode(HSPI_SCK,OUTPUT);
  pinMode(hspi->pinSS(), OUTPUT);

  // pinMode(VSPI_SS, OUTPUT);
  // digitalWrite(VSPI_SS, LOW);
  //  put your setup code here, to run once:
}

// decode logic for distance :: "0"
void distance_decode(std::string received_message, int &colour, int &distance)
{
  colour = std::stoi(received_message.substr(1, 3));
  if (received_message.at(4) == '1')
  {
    // distance case :: nothing is detected;
    distance = 0;
  }
  else
  {
    distance = std::stoi(received_message.substr(4, 15));
  }
}
// decode logic for pixel ::  "1"
void pixel_decode(std::string received_message, int &colour, int &pixel)
{
  colour = std::stoi(received_message.substr(1, 3));
  pixel = std::stoi(received_message.substr(4, 15));
}
// rotation function
void pixel_rotation(int pixel, bool stop)
{
  if (pixel < 100101100)
  {
    Serial.println("<><><><><><><><><><><><><><><>Rotate Left<><><><><><><><><><><><><><><>");
    rover.rotate(0.2, stop);
  }
  else if (pixel > 101010100)
  {
    Serial.println("<><><><><><><><><><><><><><><>Rotate Right<><><><><><><><><><><><><><><>");
    rover.rotate(-0.2, stop);
  }
}

void main_loop(int received, int special_code, bool distance)
{
  bool stop;
  int colour_first;
  int pixel_first, distance_first;
  int distance_final;
  std::map<int, int> distance_count;
  std::string received_in_binary = std::bitset<16>(received).to_string();

  if (received != 0 && received != 0b1111111111111111)
  {
    // Message is valid
    Serial.print("distance_bool: ");
    Serial.print(distance_bool);
    Serial.print(", special_code: ");
    Serial.print(special_code);
    Serial.print(", distance_message_c: ");
    Serial.print(distance_messaage_count);
    if (received_in_binary.at(0) == '0' && distance_messaage_count == 0 && distance_bool == true)
    {
      // Message is either distance type or special case

      // meaning full distance information
      distance_decode(received_in_binary, colour_first, distance_first);
      if (special_code == 10)
      {
        // Message is distance type
        int received_tmp, distance_tmp, colour_tmp;
        Serial.println("<----------------------Distance------------------->");
        for (int i = 0; i < 50; i++)
        {
          // try to stabilize the distance inform

          hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
          digitalWrite(hspi->pinSS(), LOW);

          received_tmp = hspi->transfer16(14);
          previous_special_code = 14;
          std::string distance_tmp_in_binary = std::bitset<16>(received_tmp).to_string();

          digitalWrite(hspi->pinSS(), HIGH);
          hspi->endTransaction();

          Serial.println(i);
          delay(100);

          distance_decode(distance_tmp_in_binary, colour_tmp, distance_tmp);
          Serial.print("Distance Mesaage : ");
          Serial.println(distance_tmp_in_binary.c_str());

          if (received_in_binary.at(0) == '0' && colour_tmp == colour_first)
          {
            // the message is belone to the same colour
            Serial.print("Colour: ");
            Serial.print(colour_tmp);
            Serial.print("distance count: ");
            Serial.print(i);
            Serial.print(" distance: ");
            Serial.println(distance_tmp);
            if (distance_tmp != 0)
            {
              std::map<int, int>::iterator it = distance_count.find(distance_tmp);
              if (it != distance_count.end())
              {
                it->second++;
              }
              else
              {
                distance_count.insert(std::make_pair(distance_tmp, 1));
              }
            }
          }
          else
          {
            // unexpect warning;
            if (colour_tmp != colour_first)
            {
              Serial.println("Unexpected behaviour, target changed?");
              Serial.print("Special code: ");
              Serial.print(special_code);
              Serial.print(" Case: ");
              Serial.print(colour_first);
              Serial.print(" Content: ");
              Serial.println(distance_first);
            }
            else
              Serial.println("received message should be distance type");
          }

          Serial.print("Loop count:   ");
          Serial.print(i);
        }
        // stablization done
        int max_key, max_number = 0;
        std::map<int, int>::iterator it;
        for (it = distance_count.begin(); it != distance_count.end(); it++)
        {
          if (max_number < it->second)
          {
            max_number = it->second;
            max_key = it->first;
          }
        }
        if (max_number <= 10)
        {
          Serial.println("Invalid distance count ");
          // TODO: Rotate back AND THEN Transmit Unknow.
        }
        else
        {
          distance_final = max_key;
          int select_message;
          std::string block_colour;
          switch (colour_first)
          {
          case 0:
            // red
            select_message = 30;
            block_colour = "red";
            break;

          case 1:
            select_message = 31;
            block_colour = "pink";
            break;

          case 10:
            select_message = 32;
            block_colour = "green";
            break;

          case 11:
            select_message = 33;
            block_colour = "orange";
            break;

          case 100:
            select_message = 34;
            block_colour = "black";
            break;
          }
          hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
          digitalWrite(hspi->pinSS(), LOW);
          Serial.println("<-----------------------------------------165-------------------------------------->");
          Serial.println("<-----------------------------------------165-------------------------------------->");
          Serial.println("<-----------------------------------------165-------------------------------------->");
          received = hspi->transfer16(select_message);
          previous_special_code = select_message;
          digitalWrite(hspi->pinSS(), HIGH);
          hspi->endTransaction();
          delay(100);

          Serial.print("Finalized distance");
          Serial.println(distance_final);
          Serial.println("<---------------------------------------------------------------------------------->");
          Serial.println("<---------------------------------------------------------------------------------->");
          Serial.println("<---------------------------------------------------------------------------------->");
          Serial.print("Block: ");
          Serial.println(block_colour.c_str());
          Serial.println("<---------------------------------------------------------------------------------->");
          Serial.println("<---------------------------------------------------------------------------------->");
          Serial.println("<---------------------------------------------------------------------------------->");
           // TODO: Rotate back AND THEN Transmit block.
          Serial.println("<--------------------------------------->");
          Serial.println(rover.phi);
          rover.rotateBack();
          Serial.println("######BACK######");
        }
        // END stablization finish
        // Transmitting BLOCK signal;
      }
      else
      {
        // Handling special case

        // std::string type;
        // Serial.print("");
        // switch(special_code - 1){
        //   case 9:  type = "Distance ||"; break;
        //   case 10: type = "Lock     ||"; break;
        //   case 11: type = "Valid    ||"; break;
        //   case 12: type = "Select   ||"; break;
        //   default : "False" ;
        // };
        // Serial.print(type.c_str());
        // Serial.println(distance_first);
      }
    }
    else if (received_in_binary.at(0) == '1')
    {
      // pixel message
      pixel_decode(received_in_binary, colour_first, pixel_first);
      if (special_code == 10)
      {
        stop = false;
        Serial.print("Colour: ");
        Serial.print(colour_first);
        Serial.print(" pixel: ");
        Serial.println(pixel_first);

        Serial.println("Rotation start");
        pixel_rotation(pixel_first, stop);

        int out = 1;
        int received_tmp;
        int non_detected_count = 0;
        hspi->endTransaction();
        while (out)
        {
          hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
          digitalWrite(hspi->pinSS(), LOW);
          received_tmp = hspi->transfer16(14);
          previous_special_code = 14;
          std::string distance_tmp_in_binary = std::bitset<16>(received_tmp).to_string();
          digitalWrite(hspi->pinSS(), HIGH); // pull ss high to signify end of data transfer
          hspi->endTransaction();
          delay(100);

          Serial.print("<------------WHILE CHECK----------->");
          Serial.print("<------------1------------>");
          Serial.print("<------------2------------>");
          Serial.print("Rotating message: ");
          Serial.println(distance_tmp_in_binary.c_str());

          if (distance_tmp_in_binary.at(0) == '0')
          {
            out = 0;
            Serial.println("<><><><><><><><><><><><><><>BRAKE<><><><><><><><><><><><><><>");
            rover.brake();
            Serial.print("<-------------OUT------------>: ");
            Serial.println(distance_tmp_in_binary.c_str());
            Serial.println("<><><><><><><><><><><><><><>BRAKE<><><><><><><><><><><><><><>");
          }
          // TODO: check if this is still needed? if you r with in this if meaning lock is on? so 1111 wonldnt be the case
          //else if (distance_tmp_in_binary == "1111111111111111")
          // {
          //   //target lost in detection
          //   non_detected_count++;
          //   if (non_detected_count > 10)
          //   {
          //     Serial.println("<-----------Target Lost---------->");
          //     rover.brake();
          //     break;
          //   }
          // }
        }

        if (non_detected_count > 10)
        {
          Serial.println("Fail return back");
          // TODO: rotate back;
        }
        else
        {
          Serial.println("Rotation done");
        }
        delay(100);
      }
    }
  }
  else
  {
    // Message not started
    if (received == 0)
    {
      Serial.println("received equal to 0 not started");
    }
    else if(received == 0b1111111111111111){     
      if(special_code == 10){
        int received_not_detected;
        int received_not_detected_count = 0;
        Serial.println("enter nothing is detected state");
        for(int i = 0; i < 15; i++)
        {
          hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
          digitalWrite(hspi->pinSS(), LOW);

          received_not_detected = hspi->transfer16(14);
          previous_special_code = 14;
          //std::string distance_tmp_in_binary = std::bitset<16>(received_not_detected).to_string();
        
          digitalWrite(hspi->pinSS(), HIGH); 
          hspi->endTransaction();
          Serial.print(i);
          delay(100);
          if(received_not_detected ==  0b1111111111111111){
            Serial.println(" :: NONE");
            received_not_detected_count++;
          }
        }
        if(received_not_detected_count > 10){
          //Indeed theres nothing there
          hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
          digitalWrite(hspi->pinSS(), LOW);
          //Transmit moving forward signal
          received_not_detected = hspi->transfer16(50);
          previous_special_code = 50;     
          digitalWrite(hspi->pinSS(), HIGH); 
          hspi->endTransaction();
          Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
          Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
          Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
          Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
        }
      }
    }
  }
}

// the start of special code

void loop()
{
  int colour, distance;

  while (!FPGA_ready)
  {
    hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
    digitalWrite(hspi->pinSS(), LOW);
    received = hspi->transfer16(70);
    Serial.println(received);
    digitalWrite(hspi->pinSS(), HIGH);
    hspi->endTransaction();
    if (received == 60)
    {
      FPGA_ready = true;
      Serial.println("<=========================****************===========================+>");
    };
  }

  hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
  digitalWrite(hspi->pinSS(), LOW);
  received = hspi->transfer16(special_code);
  std::string received_in_binary = std::bitset<16>(received).to_string();
  digitalWrite(hspi->pinSS(), HIGH);
  hspi->endTransaction();

  std::string type;
  Serial.print("special_code: ");
  switch (previous_special_code)
  {
  case 10:
    type = "CONDITION||";
    break;
  case 11:
    type = "Valid    ||";
    break;
  case 12:
    type = "Select   ||";
    break;
  case 13:
    type = "MOVING   ||";
    break;
  case 14:
    type = "Distance ||";
  break;
  default:
    type = "False";
  }

  Serial.println(type.c_str());
  Serial.print("MAIN: ");
  Serial.println(received_in_binary.c_str());
  delay(100);
  // Distance code has to be sent twice
  if (special_code != loop_end)
  {
    previous_special_code = special_code;
    special_code++;
    distance_bool = false;
  }
  else
  { // sent(13) count =0;
    if (distance_messaage_count == 1)
    {
      previous_special_code = special_code;
      special_code = loop_start;
      distance_messaage_count = 0;
      distance_bool = true;
    }
    else
    {
      previous_special_code = special_code;
      special_code = loop_end;
      distance_messaage_count = 1;
      distance_bool = true;
    }
  }
  main_loop(received, special_code, distance_bool);
}
// void debug(std::string received_message, int special_code)
// {

//   Serial.println("")
// }