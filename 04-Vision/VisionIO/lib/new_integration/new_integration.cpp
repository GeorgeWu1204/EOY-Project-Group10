
#ifndef INTEGRATION_H
#define INTEGRATION_H

#include <Arduino.h>
#include <SPI.h>
#include <bitset>
#include <map>
#include <rover_drive.h>
#include <bits/stdc++.h>
#include <string>
#include <iostream>
#include <vector>
#include <math.h>
#include <new_integration.h>
#include <../fpga/fpga.h>
#include <../exploration/exploration.h>
#include <../A_star/A_star.h>
//#include <../Communication/Communication.h>
//#include "Wifi.h"

SPIClass *hspi = NULL;

roverdrive rover;
exploration explore;
fpga fpga_module;
A_star a_star_module;
//Communication communication_module;

int received;
bool FPGA_ready = false;
// define VSPI_SS  SS

int special_code, previous_special_code;
int distance_messaage_count = 0;
int loop_start = 10;
int loop_end = 14;
bool distance_bool;
std::map<std::string, std::vector<double>> alien_location_storage;
std::vector<std::string> error_alien_detected;
int export_map[11][17];

//
void export_alien_location_map(int map[11][17]){
    for(int i=0; i<11; i++){
        for(int j=0; j<17; j++){
            if(map[i][j]==900){
                 export_map[i][j] = 0;
            }else{
                 export_map[i][j] = 1;
            }
        }
    }
}

integration::integration(){
    #define HSPI_MISO 12
    #define HSPI_MOSI 13
    #define HSPI_SCK 14
    #define HSPI_SS 15
    #define xBound 11
    #define yBound 17
}

void integration::start(){
    Serial.begin(115200);
    rover.start();
    hspi = new SPIClass(HSPI);
    hspi->begin(HSPI_SCK, HSPI_MISO, HSPI_MOSI, HSPI_SS);
    special_code = loop_start;
    // pinMode(HSPI_SS,OUTPUT);
    // pinMode(HSPI_MISO,INPUT);
    // pinMode(HSPI_MOSI,OUTPUT);
    // pinMode(HSPI_SCK,OUTPUT);
    pinMode(hspi->pinSS(), OUTPUT);
    while (!FPGA_ready)
    {
        hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
        digitalWrite(hspi->pinSS(), LOW);
        Serial.print("<------------Transfer----------->");
        Serial.println(70);
        received = hspi->transfer16(70);
        Serial.println(received);
        digitalWrite(hspi->pinSS(), HIGH);
        hspi->endTransaction();
        if (received == 60)
        {
            FPGA_ready = true;
            Serial.println("<=========================****************===========================+>");
        }
    }
    // initialize wifi module
    //WiFi.disconnect(true);
    //communication_module.init_WiFi();
}

// Vision part
// loop for one node detection :: calling Vision_main_loop multiple time {returning all the detected objects colour map}
bool integration::fpga_loop(std::map<std::string, std::vector<double>> &colour_map, bool start_detection){
    bool all_object_is_detected = false;
    double continue_angle;
    while (true)
    {
        int colour, distance;

        hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
        digitalWrite(hspi->pinSS(), LOW);
        // SOS
        Serial.print("<------------Transfer----------->");
        Serial.println(special_code);
        received = hspi->transfer16(special_code);
        std::string received_in_binary = std::bitset<16>(received).to_string();
        digitalWrite(hspi->pinSS(), HIGH);
        hspi->endTransaction();

        std::string type;
        Serial.print("special_code: ");
        switch (previous_special_code)
        {
        // case 10:
        //     type = "Distance-R    ||";
        //     break;
        // case 11:
        //     type = "RED-R    ||";
        //     break;
        // case 12:
        //     type = "Formate valid    ||";
        //     break;
        case 10:
            type = "lock    ||";
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
        // TODO: .h 
        all_object_is_detected = Vision_main_loop(received, special_code, colour_map, continue_angle, start_detection); //------> all objects are detected
        if (all_object_is_detected)
        {
            if (colour_map.size() == 0)
                return false;
            else
                return true;
        }
    }
}
// loop for one target detection
bool integration::Vision_main_loop(int received, int special_code, std::map<std::string, std::vector<double>> &detected_alien_set, double& continue_rotate_angle, bool start_detection){
    bool all_objects_are_detected = false;
    std::pair<std::string, std::vector<double>> colour_map;
    bool stop;
    int colour_first;
    int pixel_first, distance_first;
    int distance_final;
    std::map<int, int> distance_count;
    std::string received_in_binary = std::bitset<16>(received).to_string();

    if (received != 0 && received != 0b1111111111111111)
    {
        // Message is valid
        Serial.print("Distance_bool: ");
        Serial.print(distance_bool);
        Serial.print(", special_code: ");
        Serial.print(special_code);
        Serial.print(", distance_message_c: ");
        Serial.println(distance_messaage_count);
        if (received_in_binary.at(0) == '0' && distance_messaage_count == 0 && distance_bool == true)
        {
            // Message is either distance type or special case
            // meaning full distance information
            fpga_module.distance_decode(received_in_binary, colour_first, distance_first);
            if (special_code == 10)
            {
                // if(start_detection){
                //     rover.brake();
                //     rover.measure();
                //     double brake_angle = rover.phideg;
                //     // <- ++ positive angle ++ || -- negative angle -- -> //
                //     if(brake_angle < 0){
                //     continue_rotate_angle = -90 - brake_angle;
                //     }
                //     else {
                //     continue_rotate_angle = 90 - brake_angle;
                //     }    
                // }
                //Message is distance type
                int received_tmp, distance_tmp, colour_tmp;
                Serial.println("<----------------------MEANSURE DISTANCE------------------->");
                Serial.print("COLOUR FIRST: ");
                Serial.print(colour_first);
                Serial.println("<----------------------MEANSURE DISTANCE------------------->");

                for (int i = 0; i < 50; i++)
                {
                    // try to stabilize the distance inform

                    hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
                    digitalWrite(hspi->pinSS(), LOW);
                    Serial.print("<------------Transfer----------->");
                    Serial.println(4);
                    received_tmp = hspi->transfer16(14);
                    previous_special_code = 14;
                    std::string distance_tmp_in_binary = std::bitset<16>(received_tmp).to_string();

                    digitalWrite(hspi->pinSS(), HIGH);
                    hspi->endTransaction();
                    delay(100);

                    fpga_module.distance_decode(distance_tmp_in_binary, colour_tmp, distance_tmp);
                    // Serial.print(i);
                    // Serial.print("  Distance Mesaage : ");
                    // Serial.println(distance_tmp_in_binary.c_str());

                    if (received_in_binary.at(0) == '0' && colour_tmp == colour_first)
                    {
                        // the message is belone to the same colour
                        Serial.print(i);
                        Serial.print(" Colour: ");
                        Serial.print(colour_tmp);
                        Serial.print(" Distance: ");
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
                            Serial.print(i);
                            Serial.print(" Unexpected behaviour, Colour Change changed :: ");
                            Serial.print("  Distance Mesaage : ");
                            Serial.println(distance_tmp_in_binary.c_str());
                            
                        }
                        else
                        Serial.print(i);
                        Serial.println("  Unexpected behaviour, received message should be distance type");
                    }
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
                    Serial.println("XXXXXXXXXXXXXXXXXXX Invalid distance count XXXXXXXXXXXXXXXXXXX");
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
                    Serial.print("<------------Transfer----------->");
                    Serial.println(select_message);
                    received = hspi->transfer16(select_message);
                    previous_special_code = select_message;
                    digitalWrite(hspi->pinSS(), HIGH);
                    hspi->endTransaction();
                    delay(100);
                    Serial.println("********************* SUCCESS SUCCESS SUCCESS *********************");
                    Serial.print("Finalized Distance :: ");
                    Serial.println(distance_final);
                    int scale = 1;
                    int sum_binary_to_decimal = 0;
 
                    while (true)
                    {
                        if (distance_final % 10 == 1)
                        {
                            sum_binary_to_decimal += 1 * scale;
                        }
                        scale *= 2;
                        if(distance_final / 10 == 0){
                            break;
                        }
                        else{
                            distance_final /= 10;
                        }
                    }
                    Serial.print(distance_final);
                    
                    Serial.print(" -------> CONVERT TO ----------->");
                    Serial.println(sum_binary_to_decimal);

                    std::vector<double> position_detail;
                    rover.measure();
                    double angle = -rover.phideg;
                    position_detail.push_back(sum_binary_to_decimal);
                    position_detail.push_back(angle);
                    colour_map = std::make_pair(block_colour, position_detail);
                    detected_alien_set.insert(colour_map);
                    Serial.println("<------------------------------------ BLOCKING ----------------------------------->");
                    Serial.println("<------------------------------------ BLOCKING ----------------------------------->");
                    Serial.println("<------------------------------------ BLOCKING ----------------------------------->");
                    Serial.print("Block: ");
                    Serial.println(block_colour.c_str());
                    // TODO: Rotate back AND THEN Transmit block.
                    Serial.println(rover.phideg);
                    rover.rotateBack();
                    Serial.println("################################### ROTATE BACK ########################################");
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
            fpga_module.pixel_decode(received_in_binary, colour_first, pixel_first);
            if (special_code == 10)
            {
                
                // rover.brake();
                // rover.measure();
                // double brake_angle = rover.phideg;
                // // <- ++ positive angle ++ || -- negative angle -- -> //
                
                // if(brake_angle < 0){
                //    continue_rotate_angle = -90 - brake_angle;
                // }
                // else {
                //    continue_rotate_angle = 90 - brake_angle;
                // }
                
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
                    Serial.print("<------------Transfer----------->");
                    Serial.println(14);
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
                    // TODO: check if this is still needed? if you r with in this "if" meaning lock is on? so 1111 wonldnt be the case
                    // else if (distance_tmp_in_binary == "1111111111111111")
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
                    // TODO: LOCK? 
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
            Serial.println("NOT started");
        }
        else if (received == 0b1111111111111111)
        {
            if (special_code == 10)
            {
                int received_not_detected;
                int received_not_detected_count = 0;
                Serial.println("enter nothing is detected state");
                for (int i = 0; i < 15; i++)
                {
                    hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
                    digitalWrite(hspi->pinSS(), LOW);
                    Serial.print("<------------Transfer----------->");
                    Serial.println(14);
                    received_not_detected = hspi->transfer16(14);
                    previous_special_code = 14;
                    // std::string distance_tmp_in_binary = std::bitset<16>(received_not_detected).to_string();

                    digitalWrite(hspi->pinSS(), HIGH);
                    hspi->endTransaction();
                    
                    Serial.println(" ");
                    
                    hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
                    digitalWrite(hspi->pinSS(), LOW);
                    int cross_check;
                    Serial.print("<------------Transfer----------->");
                    Serial.println(12);
                    cross_check = hspi->transfer16(12);
                    previous_special_code = 12;
                    digitalWrite(hspi->pinSS(), HIGH);
                    hspi->endTransaction();

                    hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
                    digitalWrite(hspi->pinSS(), LOW);
                    Serial.print("<------------Transfer----------->");
                    Serial.println(14);
                   // int cross_check;
                    cross_check = hspi->transfer16(14);
                    previous_special_code = 14;
                    std::string not_ok = std::bitset<16>(cross_check).to_string();
                    Serial.print("select: ");
                    Serial.println(not_ok.c_str());
                    digitalWrite(hspi->pinSS(), HIGH);
                    hspi->endTransaction();

                    Serial.print(i);
                    delay(100);
                    if (received_not_detected == 0b1111111111111111)
                    {
                        Serial.println(" :: NONE");
                        received_not_detected_count++;
                    }
                }
                if (received_not_detected_count > 10)
                {
                    // Indeed theres nothing there
                    hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
                    digitalWrite(hspi->pinSS(), LOW);
                    // Transmit moving forward signal
                    Serial.print("<------------Transfer----------->");
                    Serial.println(50);
                    received_not_detected = hspi->transfer16(50);
                    previous_special_code = 50;
                    digitalWrite(hspi->pinSS(), HIGH);
                    hspi->endTransaction();
                    Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
                    Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
                    Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
                    Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
                    //rover.rotateToTarget(continue_rotate_angle, 0.5);
                    all_objects_are_detected = true;
                    
                }
            }
        }
    }
    return all_objects_are_detected;
}

// Exploration part
//  Exploration mode with defined starting position. Expected to be call for once;
void integration::exploration_loop(){
    std::vector<double> alien_posi;
    std::string colour;
    //std::map<std::string, std::vector<double>> alien_set;
    int map[xBound][yBound] = {0};
    std::pair<std::string, std::vector<double>> FPGA_ESP32_input; // colour, distance, angle

    std::vector<int> current_rover_position;
    // std::vector<int> next_rover_position;
    int movement; // movement of rover in next step
    // initialize position
    bool exploration_complete;
    //std::vector<std::string> wrong_detected_alien;
    bool step_taken = false;
    std::vector<int> xHistory, yHistory;
    xHistory.push_back(0);
    yHistory.push_back(0);
    current_rover_position.push_back(0);
    current_rover_position.push_back(0);
    map[0][0] = 1;

    int current_car_altitude = 10;
    std::vector<int> pre_next_rover_position, next_rover_position;
    pre_next_rover_position.push_back(0);
    pre_next_rover_position.push_back(0);
    while (true)
    {
        // step 1: detect alien and refresh map
        // TODO: method to reduce possible rotation
        std::vector<int> tmp = explore.next_step(map, xHistory, yHistory, movement);
        pre_next_rover_position[0] = tmp[0];
        pre_next_rover_position[1] = tmp[1]; 
        Serial.println("<----------------Pre Next Rover Position------------------>");
        Serial.print(pre_next_rover_position[0]);
        Serial.print(" : ");
        Serial.println(pre_next_rover_position[1]);
        Serial.println("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
        int gg = relative_rotation(current_car_altitude, movement);
        Serial.print(gg);
        Serial.println("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
        drive_command(relative_rotation(current_car_altitude, movement));
        bool start_detection = false;
        current_car_altitude = movement;
        while (!step_taken)
        {
            current_rover_position[0] = xHistory.back();
            current_rover_position[1] = yHistory.back();
            //
            int detection_code;
            hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
            digitalWrite(hspi->pinSS(), LOW);
            // Transmit moving forward signal
            Serial.print("<------------Transfer----------->");
            Serial.println(100);
            detection_code = hspi->transfer16(100);
            previous_special_code = 100;
            digitalWrite(hspi->pinSS(), HIGH);
            hspi->endTransaction();
            listen_map_alien(current_rover_position, map, alien_location_storage, error_alien_detected, current_car_altitude, start_detection);
            Serial.println("<--------------------MAP------------------->");
            for (int i = 0; i < xBound; i++){
                for (int j = 0; j < yBound; j++)
                {
                    Serial.print(map[i][j]);
                    Serial.print(" ");
                }
                Serial.println("");
            }
            Serial.println("<--------------------MAP------------------->");

            // step 2: calculate next step position
            Serial.println("<-------------------xhistory content after 1------------------>");
            for (int m = 0; m < xHistory.size(); m++){
                Serial.print(xHistory[m]);
                Serial.print(", ");
            }
            Serial.println("<-------------------yhistory content after 1------------------>");
            for (int n = 0; n < yHistory.size(); n++){
                Serial.println("<-------yHistory size------>");
                Serial.println(yHistory.size());
                Serial.print(yHistory[n]);
                Serial.print(", ");    
            }
            Serial.println("End y history");
            next_rover_position = explore.next_step(map, xHistory, yHistory, movement);
            Serial.println("<----------------Next Rover Position------------------>");
            Serial.print("next_rover_position: ");
            Serial.print(next_rover_position[0]);
            Serial.print(" : ");
            Serial.println(next_rover_position[1]);
            
            Serial.println("<----------------Pre Rover Position------------------>");
            Serial.print("pre_rover_position: ");
           // Serial.print(pre_next_rover_position.size());
            Serial.print(pre_next_rover_position[0]);
            Serial.print(" : ");
            Serial.println(pre_next_rover_position[1]);

            Serial.println("<----------------Pre Rover Position------------------>");


            if (next_rover_position[0] == pre_next_rover_position[0] && next_rover_position[1] == pre_next_rover_position[1]){
                step_taken = true;
                Serial.println("<--------------STEP TAKEN------------->");
                xHistory.push_back(next_rover_position[0]);
                Serial.println("*******Next_Rover_Position*******");
                Serial.println(next_rover_position[1]);
                yHistory.push_back(next_rover_position[1]);
                map[next_rover_position[0]][next_rover_position[1]] += 1;
            }
            else{
                // TODO: rotate
                Serial.println("<----------------ROTATE-------------->");
                Serial.print("current_car_altitude:  ");
                Serial.println(current_car_altitude);
                Serial.print("movement:  ");
                Serial.println(movement);
                Serial.println(relative_rotation(current_car_altitude, movement));
                drive_command(relative_rotation(current_car_altitude, movement));
                pre_next_rover_position = next_rover_position;
                current_car_altitude = movement;
            }
        }
        step_taken = false;
        // step 3: move to the position
        Serial.println("316");
        std::string direction;
        switch (movement)
        {
        case 10:
            direction = "UP";
            break;
        case 11:
            direction = "DOWN";
            break;
        case 12:
            direction = "LEFT";
            break;
        case 13:
            direction = "RIGHT";
            break;
        }
        Serial.println(direction.c_str());
        rover.translateToTarget(200);
        // step 4: check if the map is completely detected
        exploration_complete = false;
        for (int i = 0; i < xBound; i++)
        {
            Serial.print("Row ");
            Serial.println(i);
            for (int g = 0; g < yBound; g++)
            {
                Serial.print(map[i][g]);
                Serial.print(", ");
                if (map[i][g] == 0)
                {
                    exploration_complete = false;
                }
            }
            Serial.println(" ");
        }
        Serial.println("<----------END MAP-------->");
        if (exploration_complete)
        {
            Serial.println("Exploration Completed!");
            break;
        }
    }
}
void integration::listen_map_alien(std::vector<int> rover_position, int map[11][17], std::map<std::string, std::vector<double>> &alien_storage, std::vector<std::string> wrong_detect_alien, int current_car_altitude, bool start_detection){
    // alien_storage key:color value: [0] x_coordinate [1] y_coordinate [2] count_number
    //  2*2 block
    Serial.println("inside listen_map_alien");
    Serial.println("inside listen_map_alien");
    Serial.println("inside listen_map_alien");
    std::map<std::string, std::vector<double>> node_tmp_colour_map;
    double alienx, alieny;
    int xLow, xHigh, yLow, yHigh;

    // pair already exited in the loop
    std::map<std::string, std::vector<double>>::iterator it_1;
    if (fpga_loop(node_tmp_colour_map, start_detection))
    {
        Serial.println("------------------- OBJECT DETECTED ---------------");
        std::map<std::string, std::vector<double>>::iterator it_2;

        for (it_2 = node_tmp_colour_map.begin(); it_2 != node_tmp_colour_map.end(); it_2++)
        {
            double alienx = explore.locate_alien(rover_position, it_2->second, current_car_altitude)[0];
            double alieny = explore.locate_alien(rover_position, it_2->second, current_car_altitude)[1];
            Serial.println("<----------------------ALIEN POSITION----------------------->");
            Serial.println(alienx);
            Serial.println(alieny);
            Serial.println("<----------------------ALIEN POSITION----------------------->");
            // alien_position double tile
            int xLow = explore.normal_round(alienx - 0.25);
            int xHigh = explore.normal_round(alienx + 0.25);
            int yLow = explore.normal_round(alieny - 0.25);
            int yHigh = explore.normal_round(alieny + 0.25);

            Serial.println("<========map location==========>");
            Serial.print("xlow ");
            Serial.print(xLow);
            Serial.print("xHigh ");
            Serial.print(xHigh);
            Serial.print("yLow ");
            Serial.print(yLow);
            Serial.print("yHigh ");
            Serial.println(yHigh);
            Serial.println("<========map location==========>");
            std::vector<double> alien_infor_storage;
            std::vector<double> alien_message_prepare;
            std::pair<std::string, std::vector<double>> send_alien_message;
            alien_infor_storage.push_back(it_2->second[0]);
            alien_infor_storage.push_back(it_2->second[1]);
            it_1 = alien_storage.find(it_2->first);
            if (it_1 != alien_storage.end())
            {
                // alien already detected.
                // update map
                if (((xLow - 1) * 20 < it_1->second[0] < (xHigh + 1) * 20) || ((yLow - 1) * 20 < it_1->second[1] < (yLow + 1) * 20))
                {
                    Serial.println("Same alien detected ");
                    Serial.print("color: ");
                    Serial.print(it_1->first.c_str());
                    //SOS not sure
                    // it_1->second[2] += 1;
                    // alien_message_prepare.push_back(it_1->second[0]);
                    // alien_message_prepare.push_back(it_1->second[1]);
                    // alien_message_prepare.push_back(it_1->second[2]);
                    // send_alien_message = std::make_pair(it_1->first, alien_message_prepare);
                    if (0 <= xLow < xBound && 0 <= yLow < yBound)
                    {
                        map[xLow][yLow] = 900;
                    }
                    if (0 <= xLow < xBound && 0 <= yHigh < yBound)
                    {
                        map[xLow][yHigh] = 900;
                    }
                    if (0 <= xHigh < xBound && 0 <= yLow < yBound)
                    {
                        map[xHigh][yLow] = 900;
                    }
                    if (0 <= xHigh < xBound && 0 <= yHigh < yBound)
                    {
                        map[xHigh][yHigh] = 900;
                    }
                    return;
                }
                else
                {

                    Serial.println("Wrong alien detected, position change");
                    Serial.print("color: ");
                    Serial.println(it_1->first.c_str());
                    wrong_detect_alien.push_back(it_1->first);
                    Serial.print("erasing it from the stable list");
                    alien_storage.erase(it_1);
                    //SOS not sure
                    // it_1->second[2] += 1;
                    // alien_message_prepare.push_back(it_1->second[0]);
                    // alien_message_prepare.push_back(it_1->second[1]);
                    // alien_message_prepare.push_back(-1);
                    // send_alien_message = std::make_pair(it_1->first, alien_message_prepare);
                }
            }
            else
            {
                Serial.println(" New alien detected ");
                // send to server
                //SOS not sure
                // it_1->second[2] += 1;
                // alien_message_prepare.push_back(it_2->second[0]);
                // alien_message_prepare.push_back(it_2->second[1]);
                // alien_message_prepare.push_back(1);
                // send_alien_message = std::make_pair(it_1->first, alien_message_prepare);

                alien_storage.insert(std::make_pair(it_2->first, it_2->second));
                if (0 <= xLow < xBound && 0 <= yLow < yBound)
                {
                    map[xLow][yLow] = 900;
                }
                if (0 <= xLow < xBound && 0 <= yHigh < yBound)
                {
                    map[xLow][yHigh] = 900;
                }
                if (0 <= xHigh < xBound && 0 <= yLow < yBound)
                {
                    map[xHigh][yLow] = 900;
                }
                if (0 <= xHigh < xBound && 0 <= yHigh < yBound)
                {
                    map[xHigh][yHigh] = 900;
                }
                Serial.println("Detected Alien Map");
                Serial.print("(Low Low) ");
                Serial.print(xLow);
                Serial.print(", ");
                Serial.println(yLow);

                Serial.print("(Low High) ");
                Serial.print(xLow);
                Serial.print(", ");
                Serial.println(yHigh);

                Serial.print("(High Low) ");
                Serial.print(xHigh);
                Serial.print(", ");
                Serial.println(yLow);

                Serial.print("(High High) ");
                Serial.print(xHigh);
                Serial.print(", ");
                Serial.println(yHigh);
            }
        }
    }
    // TODO: CHECK Bound
}

// A_star

//void integration::move_to_dest(int map[11][17], int initial_car_altitude, Pair initial_position, Pair destination){
void integration::move_to_dest(int initial_car_altitude, Pair initial_position, Pair destination){
    std::stack<Pair> path;
    // export_map is the global map
    path = a_star_module.aStarSearch(export_map, initial_position, destination);
    std::pair<int, int> current_location;
    current_location = path.top();
    std::pair<int, int> next_location;
    int current_car_altitude = initial_car_altitude;
    int delta_x, delta_y;
    int relative_movement;
    path.pop();
    while (!path.empty())
    {
        next_location = path.top();
        path.pop();
        Serial.println("Path Content -------");
        Serial.print(next_location.first);
        Serial.print(", ");
        Serial.println(next_location.second);
        delta_x = next_location.first - current_location.first;
        delta_y = next_location.second - current_location.second;
        Serial.print("<-----------Current Car Location ----------->  ");
        Serial.print(current_location.first);
        Serial.print(", ");
        Serial.println(current_location.second);
        Serial.print("<-----------Next Car Location----------->  ");
        Serial.print(next_location.first);
        Serial.print(", ");
        Serial.println(next_location.second);

        // up
        if (delta_x == 0 && delta_y == 1)
        {
            relative_movement = relative_rotation(current_car_altitude, 10);
            current_car_altitude = 10;
        }
        // down
        else if (delta_x == 0 && delta_y == -1)
        {
            relative_movement = relative_rotation(current_car_altitude, 11);
            current_car_altitude = 11;
        }
        // right
        else if (delta_x == 1 && delta_y == 0)
        {
            relative_movement = relative_rotation(current_car_altitude, 12);
            current_car_altitude = 12;
        }
        // left
        else if (delta_x == -1 && delta_y == 0)
        {
            relative_movement = relative_rotation(current_car_altitude, 13);
            current_car_altitude = 13;
        }
        else if (delta_x == 0 && delta_y == 0)
        {
            Serial.println("<-------------error message------------>");
            Serial.print("current");
            Serial.print(current_location.first);
            Serial.println(current_location.second);
            Serial.print("next");
            Serial.print(next_location.first);
            Serial.print(next_location.second);
            Serial.println("<-------------error message------------>");
        }
        else
        {
            Serial.print("invalid algorithm");
            return;
        }

        rotate_translate_drive_command(relative_movement);
        current_location = next_location;
    }
}

// Drive part
//  :: Exploration
void integration::drive_command(int relative_movement){
    Serial.println("<inside drive commaand>");
    Serial.println(relative_movement);
    if (relative_movement == 10)
    {
        // 90 up
        Serial.println("Remain Still");
    }
    else if (relative_movement == 11)
    {
        // -90 down
        Serial.println("11");
        rover.rotateToTarget(M_PI, 0.5);
        Serial.println("Go to opposite direction");
    }
    else if (relative_movement == 12)
    {
        // 0 right
        Serial.println("12");
        rover.rotateToTarget(-M_PI / 2, 0.5);
        Serial.println("Rotate right by 90 degree done");
    }
    else if (relative_movement == 13)
    {
        // 180 left
        Serial.println("13");
        rover.rotateToTarget( M_PI / 2, 0.5);
        // rover.translateToTargt(100);
        Serial.println("Rotate left by 90 degree done");
    }
}
int integration::relative_rotation(int original_car_angle, int target_angle){
    Serial.println("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    if (original_car_angle == 10)
    {
        // 0
        return target_angle;
    }
    else if (original_car_angle == 11)
    {
        // originally at -90
        if (target_angle == 10)
        {
            return 11;
        }
        else if (target_angle == 11)
        {
            return 10;
        }
        else if (target_angle == 12)
        {
            return 13;
        }
        else if (target_angle == 13)
        {
            return 12;
        }
        else
        {
            return 0;
        }
    }

    else if (original_car_angle == 12)
    {
        // originally toward right
        if (target_angle == 10)
        {
            return 13;
        }
        else if (target_angle == 11)
        {
            return 12;
        }
        else if (target_angle == 12)
        {
            return 10;
        }
        else if (target_angle == 13)
        {
            return 11;
        }
        else
        {
            return 0;
        }
    }

    else if (original_car_angle == 13)
    {
        // originally at -90
        if (target_angle == 10)
        {
            return 12;
        }
        else if (target_angle == 11)
        {
            return 13;
        }
        else if (target_angle == 12)
        {
            return 11;
        }
        else if (target_angle == 13)
        {
            return 10;
        }
        else
        {
            return 0;
        }
    }
}
//  :: FPGA
void integration::pixel_rotation(int pixel, bool stop){
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
// :: Astar
void integration::rotate_translate_drive_command(int relative_movement){
    if (relative_movement == 10)
    {
        // 90 up
        rover.translateToTarget(200);
        Serial.println("Remain Still");
    }
    else if (relative_movement == 11)
    {
        // -90 down
        rover.rotateToTarget(M_PI, 0.5);
        rover.translateToTarget(200);
        Serial.println("Go to opposite direction");
    }
    else if (relative_movement == 12)
    {
        // 0 right
        rover.rotateToTarget(-M_PI / 2, 0.5);
        rover.translateToTarget(200);
        Serial.println("Rotate right by 90 degree done");
    }
    else if (relative_movement == 13)
    {
        // 180 left
        rover.rotateToTarget(M_PI / 2, 0.5);
        rover.translateToTarget(200);
        Serial.println("Rotate left by 90 degree done");
    }
}
#endif