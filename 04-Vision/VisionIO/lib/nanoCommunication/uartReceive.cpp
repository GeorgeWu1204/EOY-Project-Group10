#include <Arduino.h>
#include <WiFi.h>

// --------------------------------------------------------------- ARDUINO ----------------------------------------------------------------//

const byte num_chars = 32;
char received_chars[num_chars];


void rec_with_markers() {
  static boolean rec_in_progress = false;
  static byte bx = 0;
  char start_marker = '<';
  char end_marker = '>';
  char rc;
  bool hasReceived = false;
  
  while (hasReceived == false){
    while (Serial2.available()){
         // Serial.print("available");
        rc = Serial2.read();
        if(rec_in_progress == true){
            if(rc != end_marker){
                received_chars[bx] = rc;
                bx++;
                if(bx >= num_chars){
                bx = num_chars -1;
                }
            }
            else{
                received_chars[bx] = '\0';
                rec_in_progress = false;
                hasReceived = true;
                bx = 0;
            }
        }
        else if(rc == start_marker){
            rec_in_progress = true;
            Serial.println("start receiving");
        }
    }
  }
}
// ESP 16 17 Arduino TX RX
// void receive_uart(float &frontDistance, float &backDistance, float &leftDistance, float &rightDistance, float &rightToF, float &centerToF, float &leftToF){
//     Serial2.write('r');
//     rec_with_markers();
   
//     Serial.println(received_chars);
//     //conv_chararry_to_values(frontDistance,backDistance, leftDistahttps://prod.liveshare.vsengsaas.visualstudio.com/join?5F0090721EF8B06E6C4AD7F8AF9236D8F035nce, rightDistance);
//     int index = 0;
//     int count = 0;
//     char* value = NULL;
//     for (size_t i = 0; i < sizeof(received_chars); i++){
//         if (received_chars[i] == ','){
//             if (count == 0){
//                 frontDistance = String(received_chars).substring(index,i).toFloat();
//                 count += 1;
//             }
//             else if (count == 1){
//                 backDistance = String(received_chars).substring(index,i).toFloat();
//                 count += 1;
//             }
//             else if (count == 2){
//                 leftDistance = String(received_chars).substring(index,i).toFloat();
//                 count += 1;
//             }
//             else if (count == 3){
//                 rightToF = String(received_chars).substring(index,i).toFloat();
//                 count += 1;
//             }
//             else if (count == 4){
//                 centerToF = String(received_chars).substring(index,i).toFloat();
//                 count += 1;
//             }
//             else if (count == 5){
//                 leftToF = String(received_chars).substring(index,i).toFloat();
//                 count += 1;
//             }
//             index = i+1;
//         }
//     }
//     rightDistance = String(received_chars).substring(index, sizeof(received_chars)).toFloat();
// }

//void receive_uart(float &frontDistance, float &backDistance, float &leftDistance, float &rightDistance, float &rightToF, float &centerToF, float &leftToF){
void receive_uart(float &leftToF, float &centerToF, float &rightToF, float &topToF){

    Serial2.write('r');
    rec_with_markers();
   
    Serial.println(received_chars);
    //conv_chararry_to_values(frontDistance,backDistance, leftDistahttps://prod.liveshare.vsengsaas.visualstudio.com/join?5F0090721EF8B06E6C4AD7F8AF9236D8F035nce, rightDistance);
    int index = 0;
    int count = 0;
    char* value = NULL;
    for (size_t i = 0; i < sizeof(received_chars); i++){
        if (received_chars[i] == ','){
            if (count == 0){
                leftToF = String(received_chars).substring(index,i).toFloat();
                count += 1;
            }
            else if (count == 1){
                centerToF = String(received_chars).substring(index,i).toFloat();
                count += 1;
            }
            else if (count == 2){
                rightToF = String(received_chars).substring(index,i).toFloat();
                count += 1;
            }
            // else if (count == 3){
            //     topToF = String(received_chars).substring(index,i).toFloat();
            //     count += 1;
            // }
            index = i+1;
        }
    }
    //Serial.println("test------");
    //Serial.println(index);
    topToF = String(received_chars).substring(index, sizeof(received_chars)).toFloat();
}

void return_ToF(float &leftToF, float &centerToF, float &rightToF, float &topToF){
    receive_uart(leftToF, centerToF, rightToF, topToF);
}

