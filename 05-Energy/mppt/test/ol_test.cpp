#include <mppt.h>

void setup(){

    setup_code();
    
}

void loop(){

    if (loopTrigger){

        digitalWrite(13, HIGH);
        sampling();
        //Serial.println("lighting : " + String(lighting));
        
        current_limit = 2; 
        oc = iL0-current_limit;
        if ( oc > 0) {
          open_loop=open_loop+1; 
        } else {
          open_loop=open_loop-1; 
        }
        // UNCOMMENT when testing w load
        //open_loop=saturation(open_loop,170,0);
        pwm_modulate(open_loop);
        Serial.println(open_loop);

        digitalWrite(13,LOW);
        loopTrigger = 0;

      }

      if (int_count == 100){

        SD_fn();
        int_count = 0;

      }

}