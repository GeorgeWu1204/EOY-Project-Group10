#include <mppt.h>

void setup(){

    setup_code();
    
}

void loop(){

    if (loopTrigger){ // fast loop
        
        digitalWrite(13, HIGH);
        sampling();
        
        if (calculation(iL0, iL1, vb0, vb1, vpd0, vpd1)){ // discard random 0s from ina219
          
          // moving average implemented to reduce effect of the larger voltage ripple in boost

          SUM = SUM - READINGS[INDEX];       // Remove the oldest entry from the sum
          VALUE = p0;                        // Read the next sensor value
          READINGS[INDEX] = VALUE;           // Add the newest reading to the window
          SUM = SUM + VALUE;                 // Add the newest reading to the sum
          INDEX = (INDEX+1) % 10;            // Increment the index, and wrap to 0 if it exceeds the window size

          pavg0 = SUM / 10;

          pavg1 = pavg0;

          if (((vpd0 < 4.6) || (vpd0 > 5.1)) && (di < 200)){ // adjust to safe range only in constant lighting conditions

            sgn = -sgn;
            dutyref += sgn*1;
            //dutyref = saturation(dutyref,170,0);
            pwm_modulate(dutyref);

            vpd1 = vpd0;
            curr_v = vpd0;

          }
        }

        digitalWrite(13,LOW);
        loopTrigger = 0;
        int_count++;

      }

      if (int_count == 100){ // slow loop (try different count for MPPT speed)

        sampling();
        mvavg_powerdiff(pavg0, pavg1);
        
        if (calculation(iL0, iL1, vb0, vb1, vpd0, vpd1)){ // discard random 0s from ina219
     
          if (dpavg < 0){ // MPPT algorithm

            sgn = -sgn;

          }

          set_mppt_stepsize(dpavg);

          dutyref += sgn*stepsize; 
          //dutyref = saturation(dutyref,170,0);
          pwm_modulate(dutyref);

          vb1 = vb0;
          iL1 = iL0;

          Serial.println("`````````````````````MPPT (P&O)````````````````````");

          Serial.print(dutyref);
          Serial.print("   ");
          Serial.print(p0);
          Serial.println("   ");
          
          set_dutyref(lighting); // set duty cycle based on the assumption of linear relationship between irradiance and optimum duty cycle for MPP 
          
          if (curr_v > 4.5){

            digitalWrite(RELAY_PIN, HIGH);
            sw0 = 1;

          }
          else if (curr_v < 4.5){

            digitalWrite(RELAY_PIN, LOW);
            sw0 = 0;
            pwm_modulate(off_dutyref);

          }
          else if ((curr_v > 5.2) && (sw1 == 1)){

            digitalWrite(RELAY_PIN, LOW);
            sw0 = 0;
            pwm_modulate(off_dutyref);

          }
          else if ((curr_v < 5.1) && (sw1 == 0)){

            digitalWrite(RELAY_PIN, HIGH);
            sw0 = 1;

          }
        }

        SD_fn();
        int_count = 0;

      }

}