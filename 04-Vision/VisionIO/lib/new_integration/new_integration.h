#include <Arduino.h>
#include <SPI.h>
#include <bitset>
#include <map>
#include <bits/stdc++.h>
#include <string>
#include <iostream>
#include <vector>
#include <math.h>

#define xBound 11
#define yBound 17

class integration
{

public:
    // fpga();
    // exploration();
    integration();
    void start();
    typedef std::pair<int, int> Pair;
    typedef std::pair<double, std::pair<int, int>> pPair;
    struct cell
    {
        int parent_i, parent_j;
        // f = g + h
        double f, g, h;
    };

    // global variable
    bool fpga_loop(std::map<std::string, std::vector<double>> &colour_map, bool start_detection);
    void exploration_loop();
    void listen_map_alien(std::vector<int> rover_position, int map[11][17], std::map<std::string, std::vector<double>> &alien_storage, std::vector<std::string> wrong_detect_alien, int current_car_altitude, bool start_detection);
    void move_to_dest(int initial_car_altitude, Pair initial_position, Pair destination);

    //void move_to_dest(int map[xBound][yBound], int initial_car_altitude, Pair initial_position, Pair destination);
    void export_alien_location_map(int map[xBound][yBound]);
private:
    bool Vision_main_loop(int received, int special_code, std::map<std::string, std::vector<double>> &detected_alien_set, double& continue_rotate_angle, bool start_detection);
    void pixel_rotation(int pixel, bool stop);
    void drive_command(int relative_movement);
    int relative_rotation(int original_car_angle, int target_angle);
    void rotate_translate_drive_command(int relative_movement);
};
