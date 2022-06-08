#include <Arduino.h>
#include <WiFi.h>
#include<Communication.h>
#ifndef COMMUNICATION_H
#define COMMUNICATION_H

// const char* ssid = "BT-HWC2G8";
// const char* password = "RMtXdgLqxDRh3e";

const char* ssid = "mengyuan";
const char* password = "22222222";
const uint16_t port = 12000;
const char * host = "184.72.191.237";

// --------------------------------------------------------------- WIFI ----------------------------------------------------------------//
void Communication::init_WiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi ..");
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
  }
  Serial.println(WiFi.localIP());
  Serial.println("Connected");
}


void Communication::rubbish_function_for_wifi_offline_mode(){
    Serial.println("hahahahah");
    delay(100);
}

void Communication::reconnect_WiFi(unsigned long reconnectWifiPeriod, unsigned long& previousTime, bool& disconnectionHappened){
    unsigned long currentTime = millis(); // number of milliseconds since the upload

    // checking for WIFI connection
    if (WiFi.status() != WL_CONNECTED){
        if (currentTime - previousTime >= reconnectWifiPeriod){
            Serial.println("Try Reconnect to WIFI network");
            WiFi.disconnect();
            WiFi.reconnect();
            previousTime = currentTime;
        }
        else{
            rubbish_function_for_wifi_offline_mode();
        }
        disconnectionHappened == true;
    }         
}
void Communication::rubbish_function_after_wifi_reconnected(bool& disconnectionHappened){
    Serial.println("Sending offline mode collected information to server");
    disconnectionHappened = false;
}
// --------------------------------------------------------------- SERVER ----------------------------------------------------------------//
void Communication::server_connection(WiFiClient& client, bool &serverConnected){
    if (!client.connect(host, port)) {
        Serial.println("Connection to server failed");
        delay(100);
        serverConnected = false;
        return;
    }
    Serial.println("Connected to server successful!");
    client.print("Hello from ESP32!");
    serverConnected = true;
}

void Communication::is_server_connected(bool& serverConnected, bool disconnectionHappened){
    if (serverConnected == false || (disconnectionHappened == true && WiFi.status() == WL_CONNECTED && serverConnected ==true)){
        serverConnected = false;
    }
}

// --------------------------------------------------------------- RECEIVE & SEND ----------------------------------------------------------------//

// Listen to data sent from server: 
// receivedInfo[0] == 1: start, receivedInfo[0]==0: end
// receivedInfo[1] == x coordinate if there is destination, receivedInfo[1] == 0 if not in reaching destination mode
// receivedInfo[2] == y coordinate if there is destination, receivedInfo[2] == 0 if not in reaching destimation mode
void Communication::listen_for_instr(WiFiClient& client, int* receivedInfo, String& received){
    if(client.available()>0){
        char receivedByte = client.read();
        if (receivedByte != '$') {
            received = String(received + receivedByte);
        }
        else{
            received = String(received + receivedByte);
            Serial.println(received);
            if (received.charAt(1) == 's'){  // !start$
                receivedInfo[0] = 1;
            }
            else if (received.charAt(1) == 'e'){  // !end$
                receivedInfo[0] = 0;
            }
            else if (received.charAt(1) == 'x'){   // reaching coordinates
                receivedInfo[0] = 1;
                int index;
                int comma_index;
                while (index < received.length()) {
                    if (received.charAt(index) == ','){
                        comma_index = index;
                    }
                }
                int x = received.substring(2, comma_index).toInt();
                int y = received.substring(comma_index+2, received.length()-1).toInt();
                receivedInfo[1] = x;
                receivedInfo[2] = y;
            }
            received = "";
        }
    }
}

void Communication::send_alien_msg(WiFiClient& client, int alienIndex, float x, float y, String color, int count){
    // color is single letter
    // x and y coordinates rounded to 2dp
    String send_info = "!a" + String(alienIndex) + color + "x" + String(x,2) + ",y" + String(y,2)+ ",c"+String(count)+"$";
    client.print(send_info);
}

void Communication::send_coord_msg(WiFiClient& client, float x, float y){
    String send_info = "!cx" + String(x,2) + ",y" + String(y,2) + "$";
    client.print(send_info);
}

void Communication::rubbish_function_for_wifi_online_mode(WiFiClient& client, float& x, float& y, int& i){
    send_coord_msg(client, x, y);
      if ((i%30) == 0){
        send_alien_msg(client, 1, 35.26 , 75, "g", 1);
      }
      x += 1;
      y += 1;
      i += 1;
}
