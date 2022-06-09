#include <Arduino.h>
#include <SPI.h>
#include <bitset>
#include <map>
#include <../lib/rover_drive/rover_drive.h> 
#include <../lib/fpga/fpga.h> 
#include <../lib/exploration/exploration.h>
#include <../lib/new_integration/new_integration.h>
#include <../lib/A_star/A_star.h>
#include <bits/stdc++.h>
#include <string>
#include <iostream>
#include <vector>
#include <math.h>


//fpga vision;
//exploration exploration_map;
//integration path;
integration integrate;


// 	/* Description of the Grid-
// 	1--> The cell is not blocked
// 	0--> The cell is blocked */
	int grid[11][17]
		= { 
      { 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
      { 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1},
      { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1},
      { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
      { 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
      { 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
      { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
      { 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1},
      { 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1},
      { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
      { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
      };

// 	// Source is the left-most bottom-most corner
std::pair<int,int> src = std::make_pair(0, 0);

// 	// Destination is the left-most top-most corner
std::pair<int, int> dest = std::make_pair(3, 5);

// 	aStarSearch(grid, src, dest);

// 	return (0);
// }

void setup() {
  //Serial.begin(115200);
  //vision.start();
  
  integrate.start();

}

void loop() {
    //vision.fpga_loop();
    integrate.exploration_loop();
    //integrate.move_to_dest(grid, 10, src, dest);
}