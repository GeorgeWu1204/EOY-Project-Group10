#include <Arduino.h>
#include <WiFi.h>
#include <ArduinoWebsockets.h>
#include <rover_drive_v2.h>
#include <new_integration.h>
#include <Communication.h>

using namespace websockets;


// const char* ssid = "BT-HWC2G8";
// const char* password = "RMtXdgLqxDRh3e";
const char* ssid = "xxx";
const char* password = "hahaha010101";
// const char* ssid = "mengyuan";
// const char* password = "22222222";

std::vector<std::pair<int,int>> offline_path;
std::pair<int,int> previousPosition;
std::pair<int,int> currentPlace, previousCurrentPlace;

const char* websockets_server = "ws://52.90.54.21:14000"; //server adress and port
int status = -1;
//int radarmode = 0;

// --------------------------------------------------------------- SEND ----------------------------------------------------------------//

void send_coord_msg(WebsocketsClient& client, float x, float y, float t){
    String send_info = "!cx" + String(x,2) + ",y" + String(y,2) + ",t" + String(t,2) + "$";
    client.send(send_info);
}

void send_planned_coord_msg(WebsocketsClient& client, int px, int py){
    String send_info = "!px" + String(px) + ",y" + String(py) + "$";
    client.send(send_info);
}

void send_alien_msg(WebsocketsClient& client, float x, float y, String color, int count){
    // color is single letter
    // x and y coordinates rounded to 2dp
    String send_info = "!a" + color + "x" + String(x,2) + ",y" + String(y,2)+ ",e"+String(count)+"$";
    client.send(send_info);
}

void send_tower_msg(WebsocketsClient& client, int index ,float x, float y, float w, int count){
    // color is single letter
    // x and y coordinates rounded to 2dp
    String send_info = "!t" + String(index) + "x" + String(x,2) + ",y" + String(y,2) + ",w " + String(w, 2) + ",e" + String(count)+"$";
    client.send(send_info);
}

void send_alien_msg_control(WebsocketsClient& client, float distance, float angle, String color){
    // !ard12.2,a5.2$
    String send_info = "!a" + color + "d" + String(distance,2) + ",a" + String(angle,2) + "$";
    client.send(send_info);
    Serial.println(send_info);
}

void send_radar_msg(WebsocketsClient& client, float x, float y, float intensity){
    String send_info = "!rx" + String(x,2) + ",y" + String(y,2) + ",i" + String(intensity,2) + "$";
    client.send(send_info);
    Serial.println(send_info);
}

// --------------------------------------------------------------- WIFI ----------------------------------------------------------------//

void init_WiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi ..");
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
  }
  Serial.println(WiFi.localIP());
  Serial.println("Connected");
}

void rubbish_function_for_wifi_offline_mode(){
    currentPlace = returnCurrentPosition();
    if(offline_path.size() != 0){
        previousCurrentPlace = offline_path[-1];
    }

    if((currentPlace.first != previousCurrentPlace.first && currentPlace.second != previousCurrentPlace.second)|| offline_path.size() == 0){
        offline_path.push_back(currentPlace);
    }
        //TODO::offline
    Serial.println("Storing current Path");
    delay(100);
}


void reconnect_WiFi(WebsocketsClient& client, unsigned long reconnectWifiPeriod, unsigned long& previousTime, bool& disconnectionWifiHappened){
    unsigned long currentTime = millis(); // number of milliseconds since the upload

    // checking for WIFI connection
    if (WiFi.status() != WL_CONNECTED){
        disconnectionWifiHappened = true;
        if (currentTime - previousTime >= reconnectWifiPeriod){
            Serial.println("Try Reconnect to WIFI network");
            WiFi.disconnect();
            WiFi.reconnect();
            previousTime = currentTime;
        }
        else{
            rubbish_function_for_wifi_offline_mode();
        }
    }         
}

void rubbish_function_after_server_reconnected(WebsocketsClient& client, bool& disconnectionHappened){
    
    Serial.println("Sending offline mode collected information to server");
    String reconnectInfo = "restart";
    client.send(reconnectInfo); 
    //current power
    // for(int i = 0; i < offline_path.size(); i++){
    //     send_planned_coord_msg(client, offline_path[i].second,  offline_path[i].first);
    //    // send_planned_coord_msg(WebsocketsClient& client, int px, int py)
    // }
    // //alien
    // std::map<std::string, std::vector<double>> tmp = get_complete_alien_storage();
    //  std::map<std::string, std::vector<double>>::iterator it;
    // for (it = tmp.begin(); it != tmp.end(); it++){//TODO:: check coordinate
    //     send_alien_msg(client, 1,  it->second[1], it->second[0], it->first.c_str(),  it->second[2]);
    // }

    // offline_path.clear();
    disconnectionHappened = false;
}

// --------------------------------------------------------------- SERVER ----------------------------------------------------------------//

void server_connection(WebsocketsClient& client) {
  if (!client.connect(websockets_server)) {
    Serial.println("Connection to server failed");
    delay(100);
    return;
  }
    Serial.println("Connected to server successful!");
}

void onMessageCallback(WebsocketsMessage message) {
    String received = message.data();
    Serial.println(received);
    if (received == "!start1$"){ // start from top
        modeBegin(0);
        roverResetGlobalCoords();
        status = 1;
    }

    else if (received == "!start0$"){ // start from bottom
        modeBegin(1);
        roverResetGlobalCoords();
        status = 1;
    }

    else if (received.substring(0,8) == "!control"){
        int comma_index_1 = received.indexOf(',');
        int comma_index_2 = received.lastIndexOf(',');
        float xResetCoord = received.substring(comma_index_1+2, comma_index_2).toFloat();
        float yResetCoord = received.substring(comma_index_2+2, (received.length()-1)).toFloat();
        roverSetGlobalCoords(xResetCoord, yResetCoord,0);
        status = 1;
    }

    else if (received == "!node$"){
        status = 1;
        roverResetGlobalCoords();
    }

    else if (received == "!startradar$"){
        status = 1;
        radarmode = 1;
        roverTranslateToTarget(1000,0.5);
    }

    else if (received == "!endradar$"){
        status = 0;
        radarmode = 0;
        roverStop();
    }

    else if (received == "!cw$"){
        roverTranslate(0.5);
    }
    else if (received == "!cs$"){
        roverTranslate(-0.5);
    }
    else if (received == "!ca$"){
        roverRotate(0.5);
    }
    else if (received == "!cd$"){
        roverRotate(-0.5);
    }
    else if (received = "!cr$"){
        roverStop();
    }

    else if (received == "!detect$"){
        //std::map<std::string, std::vector<double>> tmp;
        Serial.println("ENter detectde");
        //tmp = remote_detect();
        //Serial.println ("detected complete");
        //std::map<std::string, std::vector<double>>::iterator it_2;

        //for (it_2 = tmp.begin(); it_2 != tmp.end(); it_2++){
        //     send_alien_msg_control(client, it_2->second[0], it_2->second[1], it_2->first.c_str());
        //}
    }

    else if (received.substring(0,2) == "!x"){
        int comma_index = received.indexOf(',');
        int xCoord = received.substring(2, comma_index).toInt();
        int yCoord = received.substring(comma_index+2, (received.length()-1)).toInt();
        
        // 去坐标 (in node)
    }
    // else if (received.substring(0,2) == "!b"){
    //     int ball_index = received.indexOf('b');
    //     String ballColor = received.substring(ball_index+1,received.length()-1);
    //     // 去球 
    // }
    else if (received == "!stopexp$"){
        
    }
    else if (received == "!end$"){
        status = 0;
        Serial.print("-------------------------END------------------------");
        //stopAllTask();
        //roverStop();
    }
}

void onEventsCallback(WebsocketsEvent event, String data) {
    if(event == WebsocketsEvent::ConnectionOpened) {
        Serial.println("Connnection Opened");
    } else if(event == WebsocketsEvent::ConnectionClosed) {
        Serial.println("Connnection Closed");
        Serial.println();
        
    } else if(event == WebsocketsEvent::GotPing) {
        Serial.println("Got a Ping!");
    } else if(event == WebsocketsEvent::GotPong) {
        Serial.println("Got a Pong!");
    }
}


// with rover
void wifi_online_mode(WebsocketsClient& client){
    if (status == 1){
        float x = getRoverX();
        float y = getRoverY();
        float t = getRoverTheta(true);
        send_coord_msg(client, x, y, t);
    }
    else if (status == 0){
        client.send("E");
        status = -1;
    }
}