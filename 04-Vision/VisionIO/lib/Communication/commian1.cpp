// #include <Arduino.h>
// #include "Wifi.h"
// #include "communication.h"

// WiFiClient client;

// void setup() {
//   Serial.begin(115200);
//   WiFi.disconnect(true);

//   delay(1000);

//   // Initialize Wifi events NOT WORKING NOW!
//   // WiFi.onEvent(WiFiStationConnected, WiFiEvent_t::ARDUINO_EVENT_WIFI_STA_CONNECTED);
//   // WiFi.onEvent(WiFiStationDisconnected, WiFiEvent_t::ARDUINO_EVENT_WIFI_STA_DISCONNECTED);

//   // Connect to Wifi
//   init_WiFi();
// }

// // These are useless stuff for fake data
// int i = 0;
// float x = 10.0;
// float y = 30.0;

// // These three things need to be defined outside loop() function
// bool serverConnected = false;
// String received = "";
// int receivedInfo[3] = {-1,0,0};

// // These three things are used for reconnection to Wifi
// unsigned long previousTime = 0;
// unsigned long reconnectWifiPeriod = 2000;  // Try to reconnect Wifi once every 2 seconds 
// bool disconnectionHappened = false;

// void loop() {
//   is_server_connected(serverConnected, disconnectionHappened);
//   if (serverConnected == false){
//     server_connection(client, serverConnected);
//   }
//   else if (disconnectionHappened == true && WiFi.status() == WL_CONNECTED){
//     Serial.println("hihihi");
//     rubbish_function_after_wifi_reconnected(disconnectionHappened);
//   }
//   else{
//     listen_for_instr(client, receivedInfo, received);
//     if (receivedInfo[0]==1){ // Start
//       rubbish_function_for_wifi_online_mode(client, x, y, i);
//     }
//     delay(100);
//   }
//   reconnect_WiFi(reconnectWifiPeriod, previousTime, disconnectionHappened);
// }
  

