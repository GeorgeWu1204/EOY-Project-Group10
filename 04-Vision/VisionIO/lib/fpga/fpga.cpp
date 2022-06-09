
#ifndef FPGA_H
#define FPGA_H

#include <Arduino.h>
#include <SPI.h>
#include <bitset>
#include <map>
#include <bits/stdc++.h>
#include<fpga.h>
#include <string>


// decode logic for distance :: "0"
void fpga::distance_decode(std::string received_message, int &colour, int &distance)
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
void fpga::pixel_decode(std::string received_message, int &colour, int &pixel)
{
  colour = std::stoi(received_message.substr(1, 3));
  pixel = std::stoi(received_message.substr(4, 15));
}


#endif