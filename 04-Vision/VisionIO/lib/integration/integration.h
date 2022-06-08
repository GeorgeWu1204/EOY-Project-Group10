// #include <Arduino.h>
// #include <SPI.h>
// #include <bitset>
// #include <map>
// #include <bits/stdc++.h>
// #include <string>
// #include <iostream>
// #include <vector>
// #include <math.h>

// class integration {

//     public:

//         //fpga();
//         //exploration();
//         integration();

//         void start();

//         //global variable
//         bool fpga_loop(std::map<std::string, std::vector<double>>& colour_map);


//         std::vector<double> locate_alien(std::vector<int> rover_position, std::vector<double> polar_coordinate, int current_car_altitude);
//         int normal_round(double input);
//         void listen_map_alien(std::vector<int> rover_position, int map[10][16], std::map<std::string, std::vector<double>> &alien_storage, std::vector<std::string> wrong_detect_alien, int current_car_altitude);

//         //bool integration::FPGA_detection()
//         void exploration_loop();
    
//     private:
//         bool main_loop(int received, int special_code, std::map<std::string, std::vector<double>>& detected_alien_set);

        
//         void distance_decode(std::string received_message, int &colour, int &distance);

//         // decode logic for pixel ::  "1"
//         void pixel_decode(std::string received_message, int &colour, int &pixel);

//         // rotation function
//         void pixel_rotation(int pixel, bool stop);

//         void drive_command(int relative_movement);
//         std::vector<int> next_step(int map[10][16], std::vector<int> xHistory, std::vector<int> yHistory, int& movement);
//         int relative_rotation(int original_car_angle, int target_angle );
        
// };
