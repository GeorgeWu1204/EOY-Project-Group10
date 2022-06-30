#include <Arduino.h>
#include <ArduinoWebsockets.h>
#include <SPI.h>
#include <bitset>
#include <map>
#include <../lib/rover_drive_v2/rover_drive_v2.h> 
#include <../lib/fpga/fpga.h> 
#include <../lib/exploration/exploration.h>
#include <../lib/A_star/A_star.h>
#include <bits/stdc++.h>
#include <string>
#include <iostream>
#include <vector>
#include <math.h>
#include <WiFi.h>
#include <../lib/Communication/Communication.h>
//#include <uartReceive.cpp>
#include <new_integration.h>


using namespace websockets;

std::pair<std::string,std::vector<double>> received_alien_message;
std::pair<std::string, std::vector<double>> new_detected_alien_message;
std::pair<int, std::vector<double>> received_tower_message;
std::pair<int, std::vector<double>> new_detected_tower_message;

//std::vector<std::pair<int,int> > offline_path; // this path would be past to the server when connection is restablish.

// void adding_node_to_offline_path(){  // function called at offline mode
//   currentPlace = returnCurrentPosition();

//   if(currentPlace != previousCurrentPlace){
//       offline_path.push_back(currentPlace);
//   }
// }



void setup() {
  Serial2.begin(9600);
  Serial.begin(115200);
  Serial.print("setting complete");
  init_WiFi();
 
  delay(1000);
  roverBegin();
  client.onMessage(onMessageCallback);
  client.onEvent(onEventsCallback);    

}

// float leftToF, centerToF, rightToF, topToF;
// // These three things are used for reconnection to Wifi
unsigned long previousTime = 0;
unsigned long reconnectWifiPeriod = 2000;  // Try to reconnect Wifi once every 2 seconds 
bool disconnectionHappened = false;

int x_leave_position;
int y_leave_position;
double received_alien_message_x;
double received_alien_message_y;
double received_alien_message_count;
double received_tower_diameter;
std::vector<int> tmp_store_leave_message;
std::string received_alien_message_colour;

float currentRadarDistance, previousRadarDistance = 0;

void loop() {
//   // return_ToF(leftToF, centerToF, rightToF, topToF);
//   // Serial.print("Left: ");
//   // Serial.print(leftToF);
//   // Serial.print(" ");
//   // Serial.print("center: ");
//   // Serial.print(centerToF);
//   // Serial.print(" ");
//   // Serial.print("Right: ");
//   // Serial.print(rightToF);
//   // Serial.print(" ");
//   // Serial.print("Top: ");
//   // Serial.println(topToF);
//   // Serial.print(" ");
 


  if (!client.available() && WiFi.status() == WL_CONNECTED){
    server_connection(client);
  }
  else if (disconnectionHappened == true && WiFi.status() == WL_CONNECTED){
     // rubbish_function_after_server_reconnected(client, disconnectionHappened);
  }
  else {
    if (client.available()){
      client.poll();
      wifi_online_mode(client);

      if (radarmode == 1){
        currentRadarDistance = getRoverR();
        if ((currentRadarDistance - previousRadarDistance) >= 40){
          send_radar_msg(client, getRoverX(), getRoverY(), roverDetectRadar());
          previousRadarDistance = currentRadarDistance;
        }
      }

      else{         
        if(execution_check() == true){
          if(leaving_detected() == true){
            // Serial.println("----------------Leaving detected ");
            // Serial.print(getLeave_position()[0]);
            // Serial.print(" , ");
            // Serial.println(getLeave_position()[1]);
            tmp_store_leave_message.clear();
            tmp_store_leave_message = getLeave_position();
            Serial.println("line 84");
            x_leave_position = tmp_store_leave_message[0];
            Serial.println("line 85");
            y_leave_position = tmp_store_leave_message[1];
            Serial.println("line 87");
            send_planned_coord_msg(client, y_leave_position, x_leave_position);
          }
          new_detected_alien_message = getAlien_message();
          if(received_alien_message != new_detected_alien_message){
            received_alien_message = new_detected_alien_message;
            received_alien_message_x =  received_alien_message.second[0];
            received_alien_message_y =  received_alien_message.second[1];
            received_alien_message_colour =  received_alien_message.first.c_str();
            received_alien_message_count = received_alien_message.second[2];
            send_alien_msg(client, received_alien_message_y, received_alien_message_x, received_alien_message_colour.c_str(), received_alien_message_count);
          }
          received_tower_message = getTower_message();
          if(received_tower_message != new_detected_tower_message){
            send_tower_msg(client, received_tower_message.first, received_tower_message.second[1], received_tower_message.second[0],received_tower_message.second[3], received_tower_message.second[2]);
            new_detected_tower_message = received_tower_message;
          }
        } 
        delay(100);
      }    
    }
  }
  reconnect_WiFi(client, reconnectWifiPeriod, previousTime, disconnectionHappened);

}
  








  // while (true) {
  //     if (xSemaphoreTake(TofWriteSemaphore, (TickType_t) 0) == pdTRUE) { // wait until the semaphore is free
  //     break;  // exit the waiting loop
  //     }
  // }
  // Serial.print("Writing TOF");
  // return_ToF(leftToF, centerToF, rightToF, topToF);
  // xSemaphoreGive(TofWriteSemaphore);
  