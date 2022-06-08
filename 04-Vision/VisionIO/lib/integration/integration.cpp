
// #ifndef INTEGRATION_H
// #define INTEGRATION_H

// #include <Arduino.h>
// #include <SPI.h>
// #include <bitset>
// #include <map>
// #include <rover_drive.h>
// #include <bits/stdc++.h>
// #include<fpga.h>
// #include <string>
// #include <iostream>
// #include <vector>
// #include <math.h>
// #include <integration.h>

// SPIClass *hspi = NULL;

// roverdrive rover;

// int received;
// bool FPGA_ready = false;
// // define VSPI_SS  SS

// int special_code, previous_special_code;
// int distance_messaage_count = 0;
// int loop_start = 10;
// int loop_end = 14;
// bool distance_bool;

// integration::integration () {
//     #define HSPI_MISO 12
//     #define HSPI_MOSI 13
//     #define HSPI_SCK 14
//     #define HSPI_SS 15
//     #define matrix_size
//     #define xBound 10
//     #define yBound 16
// }


// void integration::start()
// {
//     Serial.begin(9600);
//     rover.start();
//     hspi = new SPIClass(HSPI);
//     hspi->begin(HSPI_SCK, HSPI_MISO, HSPI_MOSI, HSPI_SS);
//     special_code = loop_start;
//     // pinMode(HSPI_SS,OUTPUT);
//     // pinMode(HSPI_MISO,INPUT);
//     // pinMode(HSPI_MOSI,OUTPUT);
//     // pinMode(HSPI_SCK,OUTPUT);
//     pinMode(hspi->pinSS(), OUTPUT);
//     while (!FPGA_ready)
//         {
//             hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
//             digitalWrite(hspi->pinSS(), LOW);
//             received = hspi->transfer16(70);
//             Serial.println(received);
//             digitalWrite(hspi->pinSS(), HIGH);
//             hspi->endTransaction();
//             if (received == 60)
//             {
//             FPGA_ready = true;
//             Serial.println("<=========================****************===========================+>");
//             };
//         }
// }


// // decode logic for distance :: "0"
// void integration::distance_decode(std::string received_message, int &colour, int &distance)
// {
//   colour = std::stoi(received_message.substr(1, 3));
//   if (received_message.at(4) == '1')
//   {
//     // distance case :: nothing is detected;
//     distance = 0;
//   }
//   else
//   {
//     distance = std::stoi(received_message.substr(4, 15));
//   }
// }
// // decode logic for pixel ::  "1"
// void integration::pixel_decode(std::string received_message, int &colour, int &pixel)
// {
//   colour = std::stoi(received_message.substr(1, 3));
//   pixel = std::stoi(received_message.substr(4, 15));
// }
// // rotation function
// void integration::pixel_rotation(int pixel, bool stop)
// {
//   if (pixel < 100101100)
//   {
//     Serial.println("<><><><><><><><><><><><><><><>Rotate Left<><><><><><><><><><><><><><><>");
//     rover.rotate(0.2, stop);
//   }
//   else if (pixel > 101010100)
//   {
//     Serial.println("<><><><><><><><><><><><><><><>Rotate Right<><><><><><><><><><><><><><><>");
//     rover.rotate(-0.2, stop);
//   }
// }

// bool integration::main_loop(int received, int special_code, std::map<std::string, std::vector<double>>& detected_alien_set)
// {
//     bool all_objects_are_detected = false;
//     std::pair<std::string, std::vector<double>> colour_map;
//     bool stop;
//     int colour_first;
//     int pixel_first, distance_first;
//     int distance_final;
//     std::map<int, int> distance_count;
//     std::string received_in_binary = std::bitset<16>(received).to_string();

//     if (received != 0 && received != 0b1111111111111111)
//     {
//         // Message is valid
//         Serial.print("Distance_bool: ");
//         Serial.print(distance_bool);
//         Serial.print(", special_code: ");
//         Serial.print(special_code);
//         Serial.print(", distance_message_c: ");
//         Serial.println(distance_messaage_count);
//         if (received_in_binary.at(0) == '0' && distance_messaage_count == 0 && distance_bool == true)
//         {
//         // Message is either distance type or special case
//         // meaning full distance information
//         distance_decode(received_in_binary, colour_first, distance_first);
//         if (special_code == 10)
//         {
//             // Message is distance type
//             int received_tmp, distance_tmp, colour_tmp;
//             Serial.println("<----------------------MEANSURE DISTANCE------------------->");
//             Serial.print("COLOUR FIRST: ");
//             Serial.print(colour_first);
//             Serial.println("<----------------------MEANSURE DISTANCE------------------->");
           
//             for (int i = 0; i < 50; i++)
//             {
//             // try to stabilize the distance inform

//                 hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
//                 digitalWrite(hspi->pinSS(), LOW);

//                 received_tmp = hspi->transfer16(14);
//                 previous_special_code = 14;
//                 std::string distance_tmp_in_binary = std::bitset<16>(received_tmp).to_string();

//                 digitalWrite(hspi->pinSS(), HIGH);
//                 hspi->endTransaction();
//                 delay(100);

//                 distance_decode(distance_tmp_in_binary, colour_tmp, distance_tmp);
//                 //Serial.print(i);
//                 //Serial.print("  Distance Mesaage : ");
//                 //Serial.println(distance_tmp_in_binary.c_str());

//                 if (received_in_binary.at(0) == '0' && colour_tmp == colour_first)
//                 {
//                     // the message is belone to the same colour
//                     Serial.print(i);
//                     Serial.print(" Colour: ");
//                     Serial.print(colour_tmp);
//                     Serial.print(" Distance: ");
//                     Serial.println(distance_tmp);
//                     if (distance_tmp != 0)
//                     {
//                     std::map<int, int>::iterator it = distance_count.find(distance_tmp);
//                     if (it != distance_count.end())
//                     {
//                         it->second++;
//                     }
//                     else
//                     {
//                         distance_count.insert(std::make_pair(distance_tmp, 1));
//                     }
//                     }
//                 }
//                 else
//                 {
//                     // unexpect warning;
//                     if (colour_tmp != colour_first)
//                     {
//                         Serial.print(i);
//                         Serial.print(" Unexpected behaviour, Colour Change changed :: ");
//                         Serial.print("  Distance Mesaage : ");
//                         Serial.println(distance_tmp_in_binary.c_str());
//                         // Serial.print("Special code: ");
//                         // Serial.print(special_code);
//                         // Serial.print(" Case: ");
//                         // Serial.print(colour_first);
//                         // Serial.print(" Content: ");
//                         // Serial.println(distance_first);
//                     }
//                     else
//                     Serial.print(i);
//                     Serial.println("  Unexpected behaviour, received message should be distance type");
//                 }
//             }
//             // stablization done
//             int max_key, max_number = 0;
//             std::map<int, int>::iterator it;
//             for (it = distance_count.begin(); it != distance_count.end(); it++)
//             {
//             if (max_number < it->second)
//             {
//                 max_number = it->second;
//                 max_key = it->first;
//             }
//             }
//             if (max_number <= 10)
//             {
//             Serial.println("XXXXXXXXXXXXXXXXXXX Invalid distance count XXXXXXXXXXXXXXXXXXX");
//             // TODO: Rotate back AND THEN Transmit Unknow.
//             }
//             else
//             {
//                 distance_final = max_key;
//                 int select_message;
//                 std::string block_colour;
//                 switch (colour_first)
//                 {
//                 case 0:
//                     // red
//                     select_message = 30;
//                     block_colour = "red";
//                     break;

//                 case 1:
//                     select_message = 31;
//                     block_colour = "pink";
//                     break;

//                 case 10:
//                     select_message = 32;
//                     block_colour = "green";
//                     break;

//                 case 11:
//                     select_message = 33;
//                     block_colour = "orange";
//                     break;

//                 case 100:
//                     select_message = 34;
//                     block_colour = "black";
//                     break;
//                 }
//                 hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
//                 digitalWrite(hspi->pinSS(), LOW);
//                 received = hspi->transfer16(select_message);
//                 previous_special_code = select_message;
//                 digitalWrite(hspi->pinSS(), HIGH);
//                 hspi->endTransaction();
//                 delay(100);
//                 Serial.println("********************* SUCCESS SUCCESS SUCCESS *********************");
//                 Serial.print("Finalized Distance :: ");
//                 Serial.println(distance_final);
//                 int scale = 1;
//                 int sum_binary_to_decimal = 0;

//                 while(distance_final / 10 != 0){
//                     if(distance_final % 10 == 1){
//                         sum_binary_to_decimal += 1 * scale;
//                     }
//                     scale *= 2;
//                     distance_final /=  10;
//                 }

//                 std::vector<double> position_detail;
//                 double angle = rover.phi;
//                 position_detail.push_back(sum_binary_to_decimal);
//                 position_detail.push_back(angle);
//                 colour_map = std::make_pair(block_colour, position_detail);
//                 detected_alien_set.insert(colour_map);
//                 Serial.println("<------------------------------------ BLOCKING ----------------------------------->");
//                 Serial.println("<------------------------------------ BLOCKING ----------------------------------->");
//                 Serial.println("<------------------------------------ BLOCKING ----------------------------------->");
//                 Serial.print("Block: ");
//                 Serial.println(block_colour.c_str());
//                 // TODO: Rotate back AND THEN Transmit block.
//                 Serial.println(rover.phi);
//                 rover.rotateBack();
//                 Serial.println("################################### ROTATE BACK ########################################");
//             }
//             // END stablization finish
//             // Transmitting BLOCK signal;
//         }
//         else
//         {
//             // Handling special case

//             // std::string type;
//             // Serial.print("");
//             // switch(special_code - 1){
//             //   case 9:  type = "Distance ||"; break;
//             //   case 10: type = "Lock     ||"; break;
//             //   case 11: type = "Valid    ||"; break;
//             //   case 12: type = "Select   ||"; break;
//             //   default : "False" ;
//             // };
//             // Serial.print(type.c_str());
//             // Serial.println(distance_first);
//         }
//         }
//         else if (received_in_binary.at(0) == '1')
//         {
//         // pixel message
//         pixel_decode(received_in_binary, colour_first, pixel_first);
//         if (special_code == 10)
//         {
//             stop = false;
//             Serial.print("Colour: ");
//             Serial.print(colour_first);
//             Serial.print(" pixel: ");
//             Serial.println(pixel_first);

//             Serial.println("Rotation start");
//             pixel_rotation(pixel_first, stop);

//             int out = 1;
//             int received_tmp;
//             int non_detected_count = 0;
//             hspi->endTransaction();
//             while (out)
//             {
//             hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
//             digitalWrite(hspi->pinSS(), LOW);
//             received_tmp = hspi->transfer16(14);
//             previous_special_code = 14;
//             std::string distance_tmp_in_binary = std::bitset<16>(received_tmp).to_string();
//             digitalWrite(hspi->pinSS(), HIGH); // pull ss high to signify end of data transfer
//             hspi->endTransaction();
//             delay(100);

//             Serial.print("<------------WHILE CHECK----------->");
//             Serial.print("<------------1------------>");
//             Serial.print("<------------2------------>");
//             Serial.print("Rotating message: ");
//             Serial.println(distance_tmp_in_binary.c_str());

//             if (distance_tmp_in_binary.at(0) == '0')
//             {
//                 out = 0;
//                 Serial.println("<><><><><><><><><><><><><><>BRAKE<><><><><><><><><><><><><><>");
//                 rover.brake();
//                 Serial.print("<-------------OUT------------>: ");
//                 Serial.println(distance_tmp_in_binary.c_str());
//                 Serial.println("<><><><><><><><><><><><><><>BRAKE<><><><><><><><><><><><><><>");
//             }
//             // TODO: check if this is still needed? if you r with in this "if" meaning lock is on? so 1111 wonldnt be the case
//             //else if (distance_tmp_in_binary == "1111111111111111")
//             // {
//             //   //target lost in detection
//             //   non_detected_count++;
//             //   if (non_detected_count > 10)
//             //   {
//             //     Serial.println("<-----------Target Lost---------->");
//             //     rover.brake();
//             //     break;
//             //   }
//             // }
//             }

//             if (non_detected_count > 10)
//             {
//                 Serial.println("Fail return back");
//             // TODO: rotate back;
//             }
//             else
//             {
//                 Serial.println("Rotation done");
//             }
//             delay(100);
//         }
//         }
//     }
//     else
//     {
//         // Message not started
//         if (received == 0)
//         {
//         Serial.println("NOT started");
//         }
//         else if(received == 0b1111111111111111){     
//             if(special_code == 10){
//                 int received_not_detected;
//                 int received_not_detected_count = 0;
//                 Serial.println("enter nothing is detected state");
//                 for(int i = 0; i < 15; i++)
//                 {
//                 hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
//                 digitalWrite(hspi->pinSS(), LOW);

//                 received_not_detected = hspi->transfer16(14);
//                 previous_special_code = 14;
//                 //std::string distance_tmp_in_binary = std::bitset<16>(received_not_detected).to_string();
                
//                 digitalWrite(hspi->pinSS(), HIGH); 
//                 hspi->endTransaction();
//                 Serial.print(i);
//                 delay(100);
//                 if(received_not_detected ==  0b1111111111111111){
//                     Serial.println(" :: NONE");
//                     received_not_detected_count++;
//                 }
//                 }
//                 if(received_not_detected_count > 10){
//                     //Indeed theres nothing there
//                     hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
//                     digitalWrite(hspi->pinSS(), LOW);
//                     //Transmit moving forward signal
//                     received_not_detected = hspi->transfer16(50);
//                     previous_special_code = 50;     
//                     digitalWrite(hspi->pinSS(), HIGH); 
//                     hspi->endTransaction();
//                     Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
//                     Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
//                     Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
//                     Serial.println("~~~~~****~~~~~~~MOVING FORWARD~~~~~~*****~~~~~~");
//                     all_objects_are_detected = true;
//                 }
//             }
//         }
//     }
//     return all_objects_are_detected;
// }

// // the start of special code

// // TODO:: CHECK later
// bool integration::fpga_loop(std::map<std::string, std::vector<double>>& colour_map)
// {   
//     bool all_object_is_detected = false;
//     while(true){
//         int colour, distance;
        
//         hspi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));
//         digitalWrite(hspi->pinSS(), LOW);
//         received = hspi->transfer16(special_code);
//         std::string received_in_binary = std::bitset<16>(received).to_string();
//         digitalWrite(hspi->pinSS(), HIGH);
//         hspi->endTransaction();

//         std::string type;
//         Serial.print("special_code: ");
//         switch (previous_special_code)
//         {
//         case 10:
//             type = "CONDITION||";
//             break;
//         case 11:
//             type = "Valid    ||";
//             break;
//         case 12:
//             type = "Select   ||";
//             break;
//         case 13:
//             type = "MOVING   ||";
//             break;
//         case 14:
//             type = "Distance ||";
//         break;
//         default:
//             type = "False";
//         }

//         Serial.println(type.c_str());
//         Serial.print("MAIN: ");
//         Serial.println(received_in_binary.c_str());
//         delay(100);
//         // Distance code has to be sent twice
//         if (special_code != loop_end)
//         {
//             previous_special_code = special_code;
//             special_code++;
//             distance_bool = false;
//         }
//         else
//         { // sent(13) count =0;
//             if (distance_messaage_count == 1)
//             {
//             previous_special_code = special_code;
//             special_code = loop_start;
//             distance_messaage_count = 0;
//             distance_bool = true;
//             }
//             else
//             {
//             previous_special_code = special_code;
//             special_code = loop_end;
//             distance_messaage_count = 1;
//             distance_bool = true;
//             }
//         }
//         all_object_is_detected = main_loop(received, special_code, colour_map); //------> all objects are detected
//         if(all_object_is_detected){
//             if(colour_map.size() == 0) return false;
//             else 
//             return 
//             true;
//         }
//     }
// }


// // Exploration part

// std::vector<double> integration::locate_alien(std::vector<int> rover_position, std::vector<double> polar_coordinate, int current_car_altitude)
// {
//     double distance = polar_coordinate[0];
//     double tilt_angle = polar_coordinate[1];
//     double delta_x = 0;
//     double delta_y = 0;
//     delta_x = distance * sin(PI * tilt_angle / 180);
//     delta_y = distance * coshf(PI * tilt_angle / 180);
//     std::vector<double> result;
//     if(current_car_altitude == 10){
//         Serial.println("car altitude up");
//         result.push_back(rover_position[0] + delta_x);
//         result.push_back(rover_position[1] + delta_y);
//     }
//     else if(current_car_altitude ==11 ){
//         Serial.println("car altitude down");
//         result.push_back(rover_position[0] + delta_x);
//         result.push_back(rover_position[1] - delta_y);
//     }
//     else if(current_car_altitude == 12){
//         Serial.println("car altitude right");
//         result.push_back(rover_position[0] + delta_y);
//         result.push_back(rover_position[1] - delta_x);
//     }
//     else if(current_car_altitude == 13){
//         Serial.println("car altitude left");
//         result.push_back(rover_position[0] - delta_y);
//         result.push_back(rover_position[1] - delta_x);
//     }
    
//     return result;
// }

// int integration::normal_round(double input)
// {
//     if (input - floor(input) < 0.5)
//     {
//         return floor(input);
//     }
//     else
//     {
//         return ceil(input);
//     }
// }

// void integration::listen_map_alien(std::vector<int> rover_position, int map[10][16], std::map<std::string, std::vector<double>> &alien_storage, std::vector<std::string> wrong_detect_alien, int current_car_altitude)
// {
//     // alien_storage key:color value: [0] x_coordinate [1] y_coordinate [2] correct_probability
//     //  2*2 block
//     Serial.println("inside listen_map_alien");
//     Serial.println("inside listen_map_alien");
//     Serial.println("inside listen_map_alien");
//     std::map<std::string, std::vector<double>> node_tmp_colour_map;
//     double alienx,alieny;
//     int xLow,xHigh,yLow, yHigh;

//     //pair already exited in the loop
//     std::map<std::string, std::vector<double>>::iterator it_1;
//     if(fpga_loop(node_tmp_colour_map)){
//         Serial.println("------------------- OBJECT DETECTED ---------------");
//         std::map<std::string, std::vector<double>>::iterator it_2;
        
//         for (it_2 = node_tmp_colour_map.begin(); it_2 != node_tmp_colour_map.end(); it_2++)
//         {
//             double alienx = locate_alien(rover_position, it_2->second, current_car_altitude)[0];
//             double alieny = locate_alien(rover_position, it_2->second, current_car_altitude)[1];
//             // alien_position double tile
//             int xLow = normal_round(alienx - 0.5); 
//             int xHigh = normal_round(alienx + 0.5);
//             int yLow = normal_round(alieny - 0.5);
//             int yHigh = normal_round(alieny + 0.5);

//             it_1 = alien_storage.find(it_2->first);
//             if (it_1 != alien_storage.end())
//             {
//                 // alien already detected.
//                 // update map
//                 if (((xLow - 1) * 5 < it_1->second[0] < (xHigh + 1) * 5) || ((yLow - 1) * 5 < it_1->second[1] < (yLow + 1) * 5))
//                 {
//                 Serial.println("Same alien detected " );
//                 Serial.print("color: ");
//                 Serial.print(it_1->first.c_str());
//                 if (0 <= xLow < 10 && 0 <= yLow < 16)
//                     {
//                         map[xLow][yLow] = 900;
//                     }
//                     if (0 <= xLow < 10 && 0 <= yHigh < 16)
//                     {
//                         map[xLow][yHigh] = 900;
//                     }
//                     if (0 <= xHigh < 10 && 0 <= yLow < 16)
//                     {
//                         map[xHigh][yLow] = 900;
//                     }
//                     if (0 <= xHigh < 10 && 0 <= yHigh < 16)
//                     {
//                         map[xHigh][yHigh] = 900;
//                     }
//                     return;
//                 }
//                 else
//                 {
//                     Serial.println("Wrong alien detected, position change" );
//                     Serial.print("color: ");
//                     Serial.println(it_1->first.c_str());
//                     wrong_detect_alien.push_back(it_1->first);
//                     Serial.print("erasing it from the stable list");
//                     alien_storage.erase(it_1);
//                 }
//             }
//             else
//             {
//                 Serial.println(" New alien detected ");
//                 alien_storage.insert(std::make_pair(it_2->first, it_2->second));
//                 if (0 <= xLow < 10 && 0 <= yLow < 16)
//                 {
//                     map[xLow][yLow] = 900;
//                 }
//                 if (0 <= xLow < 10 && 0 <= yHigh < 16)
//                 {
//                     map[xLow][yHigh] = 900;
//                 }
//                 if (0 <= xHigh < 10 && 0 <= yLow < 16)
//                 {
//                     map[xHigh][yLow] = 900;
//                 }
//                 if (0 <= xHigh < 10 && 0 <= yHigh < 16)
//                 {
//                     map[xHigh][yHigh] = 900;
//                 }
//                 Serial.println("Detected Alien Map");

//                 Serial.print("(Low Low) ");
//                 Serial.print(xLow);
//                 Serial.print(", ");
//                 Serial.println(yLow);

//                 Serial.print("(Low High) ");
//                 Serial.print(xLow);
//                 Serial.print(", ");
//                 Serial.println(yHigh);

//                 Serial.print("(High Low) ");
//                 Serial.print(xHigh);
//                 Serial.print(", ");
//                 Serial.println(yLow);

//                 Serial.print("(High High) ");
//                 Serial.print(xHigh);
//                 Serial.print(", ");
//                 Serial.println(yHigh);
//             }



            
//         }
//     }
//     // TODO: CHECK Bound

// }

// std::vector<int> integration::next_step(int map[10][16], std::vector<int> xHistory, std::vector<int> yHistory, int& movement)
// {
//     int original_x = xHistory.back();
//     int original_y = yHistory.back();
//     int next_x, next_y;
//     if (original_x - 1 >= 0 && map[original_x - 1][original_y] == 0)
//     {
//         // left
//         next_x = original_x - 1;
//         next_y = original_y;
//         movement = 13;
//     }
    
//     else if (original_y - 1 >= 0 && map[original_x][original_y - 1] == 0)
//     {
//         // down
//         next_x = original_x;
//         next_y = original_y - 1;
//         movement = 11;
//     }
//     else if (original_y + 1 < yBound && map[original_x][original_y + 1] == 0) 
//     {
//         // up
//         next_x = original_x;
//         next_y = original_y + 1;
//         movement = 10;
//     }
//     else if (original_x + 1 < xBound && map[original_x + 1][original_y] == 0)
//     {
//         // right
//         next_x = original_x + 1;
//         next_y = original_y;
//         movement = 12;
//     }
//     else
//     {
//         int current_priority = 1;
//         while (true)
//         {
//             if (original_y + 1 < yBound && map[original_x][original_y + 1] == current_priority)
//             {
//                 // up
//                 next_x = original_x;
//                 next_y = original_y + 1;
//                 movement = 10 ;
//                 break;
//             }
//             else if (original_x - 1 >= 0 && map[original_x - 1][original_y] == current_priority)
//             {
//                 // left
//                 next_x = original_x - 1;
//                 next_y = original_y;
//                 movement = 13;
//                 break;
//             }
//             else if (original_y - 1 >= 0 and map[original_x][original_y - 1] == current_priority)
//             {
//                 // down
//                 next_x = original_x;
//                 next_y = original_y - 1;
//                 movement = 11;
//                 break;
//             }
//             else if (original_x + 1 < xBound and map[original_x + 1][original_y] == current_priority)
//             {
//                 // right
//                 next_x = original_x + 1;
//                 next_y = original_y;
//                 movement = 12;
//                 break;
//             }
//             else
//             {
//                 current_priority += 1;
//             }
//         }
//     }
//     std::vector<int> result;
//     result.push_back(next_x);
//     result.push_back(next_y);
//     Serial.print("Next_X_position:  ");
//     Serial.println(next_x);
//     Serial.print("Next_Y_position   ");
//     Serial.println(next_y);
//     return result;
// }

// // bool integration::FPGA_detection()
// // {
// //     std::map<std::string, std::vector<double>> node_tmp_colour_map;
// //     return fpga_loop(node_tmp_colour_map);
    
// // }


// void integration::drive_command(int relative_movement)
// {
//     if(relative_movement == 10){
//       // 90 up
//       Serial.println("Remain Still");
//     }
//     else if(relative_movement == 11){
//       // -90 down
//       rover.rotateToTarget(M_PI, 0.2); 
//       Serial.println("Go to opposite direction");
//     }
//     else if(relative_movement == 12){
//       // 0 right
//       rover.rotateToTarget(M_PI/2, 0.2);
//       Serial.println("Rotate right by 90 degree done");
//     }
//     else if(relative_movement == 13){
//       // 180 left
//       rover.rotateToTarget(-M_PI/2, 0.2);
//       //rover.translateToTargt(100);
//       Serial.println("Rotate left by 90 degree done");
//     }
// }
// int integration::relative_rotation(int original_car_angle, int target_angle ){
//     if(original_car_angle == 10){
//       //0
//       return target_angle;
//     } 
//     else if (original_car_angle == 11){
//       // originally at -90
//       if(target_angle == 10){
//         return 11;
//       }
//       else if(target_angle == 11){
//         return 10;
//       }
//       else if (target_angle == 12){
//         return 13;
//       }
//       else if (target_angle == 13){
//         return 12;
//       }
//       else {
//         return 0;
//       }
//     }

//     else if (original_car_angle == 12){
//       // originally toward right
//       if(target_angle == 10){
//         return 13;
//       }
//       else if(target_angle == 11){
//         return 12;
//       }
//       else if (target_angle == 12){
//         return 10;
//       }
//       else if (target_angle == 13){
//         return 11;
//       }
//       else {
//         return 0;
//       }
//     }

//   else if (original_car_angle == 13){
//       // originally at -90
//       if(target_angle == 10){
//         return 12;
//       }
//       else if(target_angle == 11){
//         return 13;
//       }
//       else if (target_angle == 12){
//         return 11;
//       }
//       else if (target_angle == 13){
//         return 10;
//       }
//       else {
//         return 0;
//       }
//     }
// }

// void integration::exploration_loop()
// {
//     std::vector<double> alien_posi;
//     std::string colour;
//     std::map<std::string, std::vector<double>> alien_set;
//     int map[xBound][yBound] = {0};
//     std::pair<std::string, std::vector<double>> FPGA_ESP32_input; // colour, distance, angle
    
//     std::vector<int> current_rover_position;
//     //std::vector<int> next_rover_position;
//     int movement; // movement of rover in next step
//     // initialize position
//     bool exploration_complete;
//     std::vector<std::string> wrong_detected_alien;
//     bool step_taken = false;
//     std::vector<int> xHistory, yHistory;
//     xHistory.push_back(0);
//     yHistory.push_back(0);
//     current_rover_position.push_back(0);
//     current_rover_position.push_back(0);
//     map[0][0] = 1;

//     int current_car_altitude = 10;
//     std::vector<int> pre_next_rover_position, next_rover_position;
//     while (true)
//     {
//         // step 1: detect alien and refresh map
//         // TODO: method to reduce possible rotation

//         pre_next_rover_position = next_step(map, xHistory, yHistory, movement);
//         Serial.println("<----------------Pre Next Rover Position------------------>");
//         Serial.print(pre_next_rover_position[0]);
//         Serial.print(" : ");
//         Serial.println(pre_next_rover_position[1]);
//         drive_command(relative_rotation(current_car_altitude, movement));
//         current_car_altitude = movement;
//         while(!step_taken){
            
//             current_rover_position[0] = xHistory.back();
//             current_rover_position[1] = yHistory.back();
//             listen_map_alien(current_rover_position, map, alien_set, wrong_detected_alien, current_car_altitude);
//             Serial.println("<--------------------MAP------------------->");
//             for(int i = 0; i < 10;i++){
//                 for(int j = 0; j < 16; j++){
//                     Serial.print(map[i][j]);
//                     Serial.print(" ");
//                 }
//                 Serial.println("");
//                 Serial.println("<--------------------next row------------------->");
          
//             }
//             Serial.println("<--------------------MAP------------------->");
          
//           // step 2: calculate next step position
//             Serial.println("<-------------------xhistory content after 1------------------>");
//             for(int m = 0; m < xHistory.size(); m++){
//             Serial.print(xHistory[m]);
//             Serial.print(", ");
//             }
//             Serial.println("<-------------------yhistory content after 1------------------>");
//             for(int n = 0; n < yHistory.size(); n++){
//             Serial.print(yHistory[n]);
//             Serial.print(", ");
//             }
//           next_rover_position = next_step(map, xHistory, yHistory, movement);
//           Serial.println("<----------------Next Rover Position------------------>");
//           Serial.print("next_rover_position: ");
//           Serial.print(next_rover_position[0]);
//           Serial.print(" : ");
//           Serial.println(next_rover_position[1]);
          
//           if(next_rover_position[0] == pre_next_rover_position[0] && next_rover_position[1]  == pre_next_rover_position[1]){
//             //change 1
//             step_taken = true;
//             Serial.println("<--------------STEP TAKEN------------->");
//             xHistory.push_back(next_rover_position[0]);
//             yHistory.push_back(next_rover_position[1]);
//             map[next_rover_position[0]][next_rover_position[1]] += 1;
//           }else{
//             //TODO: rotate
//             Serial.println("<----------------ROTATE-------------->");
//             Serial.print("current_car_altitude:  ");
//             Serial.println(current_car_altitude);
//             Serial.print("movement:  ");
//             Serial.println(movement);
//             Serial.println(relative_rotation(current_car_altitude, movement));
//             drive_command(relative_rotation(current_car_altitude, movement));
//             pre_next_rover_position = next_rover_position;         
//             current_car_altitude = movement; 
//           }
//         }
//         step_taken = false;
//         // step 3: move to the position
//         Serial.println("316");
//         std::string direction;
//         switch(movement){
//           case 10: direction = "UP"; break;
//           case 11: direction = "DOWN"; break;
//           case 12: direction = "LEFT"; break;
//           case 13: direction = "RIGHT"; break;
//         }
//         Serial.println(direction.c_str());
//         rover.translateToTarget(50);
//         // step 4: check if the map is completely detected
//         exploration_complete = false;
//         for(int i = 0; i < xBound; i++){
//             Serial.print("Row ");
//             Serial.println(i);
//             for(int g = 0 ; g < yBound; g++){
//                 Serial.print(map[i][g]);
//                 Serial.print(", ");
//                 if(map[i][g] == 0){
//                     exploration_complete = false;
//                 }
//             }
//             Serial.println(" ");
//         }
//         if(exploration_complete){
//           Serial.println("Exploration Completed!");
//           break;
//         }
//     }

// }


//  #endif