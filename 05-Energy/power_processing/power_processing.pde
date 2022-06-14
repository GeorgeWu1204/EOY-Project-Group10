import processing.serial.*;

Serial COMPort;  // Create object from Serial class

String[] lines = new String[0];
FloatList power;
int limit;
float x, y;

void setup() 
{
  frameRate(5);
  String portName = Serial.list()[0];
  COMPort = new Serial(this, portName, 115200);
  size(640, 480);
  textSize(24);
}

void draw() 
{
  if (COMPort.available() > 0) {  // If data is available,
    String read = COMPort.readString();  // read and store it to string read
    println(read);
    lines = append(lines, read);// append new read to string lines
  } else {
    saveStrings("radar_data.txt", lines);//save string to file
  }
  background(255);
  
  stroke(128);
  strokeWeight(1);
  line(0, height/2, width, height/2);
  line(width/2, 0, width/2, height);
 
  limit++;                        //Increments each frame
  if (limit > width) limit = 0;  
  
  strokeWeight(3);
  stroke(255, 0, 0);
  for(int i = 0; i< limit; i++)
    {
    x = i;  
    y = float("lines");
    point(i, y);   
    }
  
  fill(0);
  textAlign(LEFT, CENTER);
  text(y, limit+10, y + height/2);  
}
