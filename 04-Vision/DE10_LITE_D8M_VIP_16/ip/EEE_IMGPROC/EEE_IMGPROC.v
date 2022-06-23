module EEE_IMGPROC(
	// global clock & reset
	clk,
	reset_n,
	
	// mm slave
	s_chipselect,
	s_read,
	s_write,
	s_readdata,
	s_writedata,
	s_address,

	// stream sink
	sink_data,
	sink_valid,
	sink_ready,
	sink_sop,
	sink_eop,
	
	// streaming source
	source_data,
	source_valid,
	source_ready,
	source_sop,
	source_eop,
	
	// conduit
	mode,
	message_to_ESP32,
	message_from_ESP32
	// outbuffer,
	// receive_msg
);


// global clock & reset
input	clk;
input	reset_n;

// mm slave
input							s_chipselect;
input							s_read;
input							s_write;
output	reg	[31:0]				s_readdata;
input	[31:0]					s_writedata;  
input	[2:0]					s_address;

// streaming sink
input	[23:0]            		sink_data;
input							sink_valid;
output							sink_ready;
input							sink_sop;
input							sink_eop;

// streaming source
output	[23:0]			  	    source_data;
output							source_valid;
input							source_ready;
output							source_sop;
output							source_eop;

// conduit export
input                         mode;
output		reg		[15:0]    message_to_ESP32;
input				[15:0]    message_from_ESP32;


////////////////////////////////////////////////////////////////////////

parameter IMAGE_W = 11'd640;
parameter IMAGE_H = 11'd480;
parameter MESSAGE_BUF_MAX = 256;
parameter MSG_INTERVAL = 6;
parameter BB_COL_DEFAULT = 24'h00ff00;
parameter horizontal_edge_region_threshold = 6'd30;
parameter vertical_region_confirm_threshold = 6'd50;
parameter difference_threshold = 8'd150;
parameter count_threshold = 6'd10;
parameter valid_region_threshold = 8'd10;
wire [7:0] red, green, blue, grey;
wire [7:0] red_out, green_out, blue_out;
wire sop, eop, in_valid, out_ready;
wire red_detected, green_detected, pink_detected, white_detected, black_detected, cyan_detected, yellow_detected, blue_detected;
wire [23:0] color_high;
wire[9:0] hue;
wire[7:0] saturation, value, min;
reg [7:0] Red_stage_1, Red_stage_2, Red_stage_3, Red_stage_4, Red_stage_5;
reg [7:0] Green_stage_1, Green_stage_2, Green_stage_3, Green_stage_4, Green_stage_5;
reg [7:0] Blue_stage_1, Blue_stage_2, Blue_stage_3, Blue_stage_4, Blue_stage_5;

always @(posedge clk) begin
	Red_stage_1 <= red;
	Red_stage_2 <= Red_stage_1;
	Red_stage_3 <= Red_stage_2;
	Red_stage_4 <= Red_stage_3;
	Red_stage_5 <= Red_stage_4;
	Green_stage_1 <= green;
	Green_stage_2 <= Green_stage_1;
	Green_stage_3 <= Green_stage_2;
	Green_stage_4 <= Green_stage_3;
	Green_stage_5 <= Green_stage_4;
	Blue_stage_1 <= blue;
	Blue_stage_2 <= Blue_stage_1;
	Blue_stage_3 <= Blue_stage_2;
	Blue_stage_4 <= Blue_stage_3;
	Blue_stage_5 <= Blue_stage_4;
end
reg [14:0] tmp_r_1, tmp_r_2, tmp_r_3, tmp_r_4, tmp_r_5;
reg [14:0] tmp_g_1, tmp_g_2, tmp_g_3, tmp_g_4, tmp_g_5;
reg [14:0] tmp_b_1, tmp_b_2, tmp_b_3, tmp_b_4, tmp_b_5;
reg [14:0] tmp_sum_1, tmp_sum_2, tmp_sum_3, tmp_sum_4, tmp_sum_5;
reg [7:0] can_input11, can_input12, can_input13;
reg [7:0] can_input21, can_input22, can_input23;
reg [7:0] can_input31, can_input32, can_input33;

//////////////////////////////////////////////////////////
//Guassian Filter
//////////////////////////////////////////////////////////
reg [7:0] smooth_red, smooth_green, smooth_blue;
always @(*) begin

	if (x < 2) begin
		smooth_red = red;
		smooth_green = green;
		smooth_blue = blue;
	end 
	//11'h2
	if (x % IMAGE_W > IMAGE_W - 2 ) begin
		smooth_red = Red_stage_5;
		smooth_green = Green_stage_5;
		smooth_blue = Blue_stage_5;
	end 
	else begin

		tmp_r_1 = Red_stage_1 * 8; 
		tmp_r_2 = Red_stage_2 * 31;
		tmp_r_3 = Red_stage_3 * 49;
		tmp_r_4 = Red_stage_4 * 31;
		tmp_r_5 = Red_stage_5 * 8;
		tmp_sum_1 = tmp_r_1 + tmp_r_2 + tmp_r_3 + tmp_r_4 + tmp_r_5;
		smooth_red = tmp_sum_1 [14:7];
		//smooth_red = red;

		tmp_g_1 = Green_stage_1 * 8; 
		tmp_g_2 = Green_stage_2 * 31;
		tmp_g_3 = Green_stage_3 * 49;
		tmp_g_4 = Green_stage_4 * 31;
		tmp_g_5 = Green_stage_5 * 8;
		tmp_sum_2 = tmp_g_1 + tmp_g_2 + tmp_g_3 + tmp_g_4 + tmp_g_5;
		smooth_green = tmp_sum_2 [14:7];
		//smooth_green = green;

		tmp_b_1 = Blue_stage_1 * 8; 
		tmp_b_2 = Blue_stage_2 * 31;
		tmp_b_3 = Blue_stage_3 * 49;
		tmp_b_4 = Blue_stage_4 * 31;
		tmp_b_5 = Blue_stage_5 * 8;
		tmp_sum_3 = tmp_b_1 + tmp_b_2 + tmp_b_3 + tmp_b_4 + tmp_b_5;
		smooth_blue = tmp_sum_3 [14:7];
		//smooth_blue = blue;

	end 
end

//--------------------------------------------------------------------
//Median Filter
//--------------------------------------------------------------------
wire [7:0] median_red, median_green, median_blue;
reg [7:0] Red_median_stage_1, Red_median_stage_2, Red_median_stage_3, Red_median_stage_4, Red_median_stage_5;
reg [7:0] Green_median_stage_1, Green_median_stage_2, Green_median_stage_3, Green_median_stage_4, Green_median_stage_5;
reg [7:0] Blue_median_stage_1, Blue_median_stage_2, Blue_median_stage_3, Blue_median_stage_4, Blue_median_stage_5;
always @(posedge clk) begin
	Red_median_stage_1 <= smooth_red;
	Red_median_stage_2 <= Red_median_stage_1;
	Red_median_stage_3 <= Red_median_stage_1;
	Red_median_stage_4 <= Red_median_stage_3;
	Red_median_stage_5 <= Red_median_stage_4;
	Green_median_stage_1 <= smooth_green;
	Green_median_stage_2 <= Green_median_stage_1;
	Green_median_stage_3 <= Green_median_stage_2;
	Green_median_stage_4 <= Green_median_stage_3;
	Green_median_stage_5 <= Green_median_stage_5;
	Blue_median_stage_1 <= smooth_blue;
	Blue_median_stage_2 <= Blue_median_stage_1;
	Blue_median_stage_3 <= Blue_median_stage_2;
	Blue_median_stage_4 <= Blue_median_stage_3;
	Blue_median_stage_5 <= Blue_median_stage_5;
end

Median M_red( 
	.x_value(x),
	.smooth_value(smooth_red),
	.reg_5(Red_median_stage_5),
	.a(Red_median_stage_1),
	.b(Red_median_stage_2),
	.c(Red_median_stage_3),
	.d(Red_median_stage_4),
	.e(Red_median_stage_5),
	.median(median_red)
);

Median M_green( 
	.x_value(x),
	.smooth_value(smooth_green),
	.reg_5(Green_median_stage_5),
	.a(Green_stage_1),
	.b(Green_stage_2),
	.c(Green_stage_3),
	.d(Green_stage_4),
	.e(Green_stage_5),
	.median(median_green)
);

Median M_blue( 
	.x_value(x),
	.smooth_value(smooth_blue),
	.reg_5(Blue_median_stage_5),
	.a(Blue_stage_1),
	.b(Blue_stage_2),
	.c(Blue_stage_3),
	.d(Blue_stage_4),
	.e(Blue_stage_5),
	.median(median_blue)
);

//--------------------------------------------------------------------
//HSV Convertion
//--------------------------------------------------------------------
assign value = (red > green) ? ((red > blue) ? red[7:0] : blue[7:0]) : (green > blue) ? green[7:0] : blue[7:0];						
assign min = (red < green)? ((red<blue) ? red[7:0] : blue[7:0]) : (green < blue) ? green [7:0] : blue[7:0];
assign saturation = (value - min)* 255 / value;
assign hue = (red == green && red == blue) ? 0 :((value != red)? (value != green) ? (((240*((value - min))+ (60* (red - green)))/(value-min))>>1):
                ((120*(value-min)+60*(blue - red))/(value - min)>>1): 
                (blue < green) ? ((60*(green - blue)/(value - min))>>1): (((360*(value-min) +(60*(green - blue)))/(value - min))>>1));


reg red_detected_1,red_detected_2,red_detected_3 ,red_detected_4, red_detected_5, red_detected_6;
reg pink_detected_1,pink_detected_2,pink_detected_3 ,pink_detected_4, pink_detected_5, pink_detected_6;
reg green_detected_1,green_detected_2,green_detected_3, green_detected_4, green_detected_5, green_detected_6;
reg white_detected_1, white_detected_2, white_detected_3, white_detected_4, white_detected_5, white_detected_6;
reg black_detected_1, black_detected_2, black_detected_3, black_detected_4, black_detected_5, black_detected_6;
reg cyan_detected_1, cyan_detected_2, cyan_detected_3, cyan_detected_4, cyan_detected_5, cyan_detected_6;
reg yellow_detected_1, yellow_detected_2, yellow_detected_3, yellow_detected_4, yellow_detected_5, yellow_detected_6;
reg blue_detected_1, blue_detected_2, blue_detected_3, blue_detected_4, blue_detected_5, blue_detected_6;



initial begin
	red_detected_1 = 0;
	red_detected_2 = 0;
	red_detected_3 = 0;
	red_detected_4 = 0;
	red_detected_5 = 0;
	red_detected_6 = 0;
	
	pink_detected_1 = 0;
	pink_detected_2 = 0;
	pink_detected_3 = 0;
	pink_detected_4 = 0;
	pink_detected_5 = 0;
	pink_detected_6 = 0;

	green_detected_1 = 0;
	green_detected_2 = 0;
	green_detected_3 = 0;
	green_detected_4 = 0;
	green_detected_5 = 0;
	green_detected_6 = 0;

	white_detected_1 = 0;
	white_detected_2 = 0;
	white_detected_3 = 0;
	white_detected_4 = 0;
	white_detected_5 = 0;
	white_detected_6 = 0;
	
	black_detected_1 = 0;
	black_detected_2 = 0;
	black_detected_3 = 0;
	black_detected_4 = 0;
	black_detected_5 = 0;
	black_detected_6 = 0;

	cyan_detected_1 = 0;
	cyan_detected_2 = 0;
	cyan_detected_3 = 0;
	cyan_detected_4 = 0;
	cyan_detected_5 = 0;
	cyan_detected_6 = 0;

	yellow_detected_1 = 0;
	yellow_detected_2 = 0;
	yellow_detected_3 = 0;
	yellow_detected_4 = 0;
	yellow_detected_5 = 0;
	yellow_detected_6 = 0;

	blue_detected_1 = 0;
	blue_detected_2 = 0;
	blue_detected_3 = 0;
	blue_detected_4 = 0;
	blue_detected_5 = 0;
	blue_detected_6 = 0;
end


always @(posedge clk)begin
	red_detected_1 <= red_detected;
	red_detected_2 <= red_detected_1;
	red_detected_3 <= red_detected_2;
	red_detected_4 <= red_detected_3;
	red_detected_5 <= red_detected_4;
	red_detected_6 <= red_detected_5;
	
	pink_detected_1 <= pink_detected;
	pink_detected_2 <= pink_detected_1;
	pink_detected_3 <= pink_detected_2;
	pink_detected_4 <= pink_detected_3;
	pink_detected_5 <= pink_detected_4;
	pink_detected_6 <= pink_detected_5;
	
	green_detected_1 <= green_detected;
	green_detected_2 <= green_detected_1;
	green_detected_3 <= green_detected_2;
	green_detected_4 <= green_detected_3;
	green_detected_5 <= green_detected_4;
	green_detected_6 <= green_detected_5;
	
	white_detected_1 <= white_detected;
	white_detected_2 <= white_detected_1;
	white_detected_3 <= white_detected_2;
	white_detected_4 <= white_detected_3;
	white_detected_5 <= white_detected_4;
	white_detected_6 <= white_detected_5;

	black_detected_1 <= black_detected;
	black_detected_2 <= black_detected_1;
	black_detected_3 <= black_detected_2;
	black_detected_4 <= black_detected_3;
	black_detected_5 <= black_detected_4;
	black_detected_6 <= black_detected_5;

    cyan_detected_1 <= cyan_detected;
	cyan_detected_2 <= cyan_detected_1;
	cyan_detected_3 <= cyan_detected_2;
	cyan_detected_4 <= cyan_detected_3;
	cyan_detected_5 <= cyan_detected_4;
	cyan_detected_6 <= cyan_detected_5;

	yellow_detected_1 <= yellow_detected;
	yellow_detected_2 <= yellow_detected_1;
	yellow_detected_3 <= yellow_detected_2;
	yellow_detected_4 <= yellow_detected_3;
	yellow_detected_5 <= yellow_detected_4;
	yellow_detected_6 <= yellow_detected_5;

	blue_detected_1 <= blue_detected;
	blue_detected_2 <= blue_detected_1;
	blue_detected_3 <= blue_detected_2;
	blue_detected_4 <= blue_detected_3;
	blue_detected_5 <= blue_detected_4;
	blue_detected_6 <= blue_detected_5;
    
end

//-------------------------------------------------------------------- HSV --------------------------------------------------------------------
assign pink_detected = 
//(2 <= hue && hue <= 12) && (150 < saturation  && saturation < 200) && (108 < value && value < 255);
//hue 0.037 - 0.09 sat 0.537 - 0.818  value 0.761 - 1
//hue 0.049 - 0.101 sat 0.535 - 0.776  value 0.969 - 1
//hue 0.037 - 0.096 sat 0.561 - 0.776  value 0.945 - 1
//hue 0.047 - 0.098 sat 0.541 - 0.874  value 0.975 - 1
//hue 0.047 - 0.070 sat 0.733 - 0.871  value 0.973 - 1
//hue 0.038 - 0.103 sat 0.478 - 0.857  value 0.965 - 1
//hue 0.038 - 0.093 sat 0.533 - 0.782  value 0.973 - 1
//hue 0.033 - 0.081 sat 0.559 - 0.806  value 0.690 - 1
//hue 0.025 - 0.057 sat 0.580 - 0.788  value 0.824 - 1
//hue 0.013 - 0.065 sat 0.578 - 0.817  value 0.627 - 0.863
//hue 0.013 - 0.051 sat 0.682 - 0.847  value 0.659 - 0.871
//hue 0.032 - 0.128 sat 0.384 - 0.776  value 0.976 - 1.000
//hue 0.019 - 0.055 sat 0.672 - 0.860  value 0.643 - 0.941
//hue 0.011 - 0.065 sat 0..580 - 0.783 value 0.424 - 0.706
//Jhome
//hue 0.956 - 0.06  sat 0.239 - 0.559  value 0.486 - 0.741
(((0 <= hue && hue <= 11)|| (177 <= hue  && hue <=180) )  && (95 <= saturation  && saturation <= 155) && (154 <= value && value <= 229))
//((0 <= hue && hue <= 11)|| (178 <= hue  && hue <=180))  && (87 <= saturation  && saturation <= 155) && (154 <= value && value <= 229);
|| ((6 <= hue && hue <= 17)  && (132 <= saturation  && saturation <= 211) && (248 <= value && value <= 255))
//hue 0.034 - 0.092  sat 0.518 - 0.827 value 0.973 - 1
|| ((7 <= hue && hue <= 27)  && (92 <= saturation  && saturation <= 177) && (247 <= value && value <= 255));


assign white_detected = 
//home
//(hue < 78 && hue >= 33) && (22< saturation && saturation< 98) && (value > 112 && value < 187);
//lab
(hue < 45 && hue >= 24) && (61< saturation && saturation< 148) && (value > 100 && value < 183);
//common room
//hue 0 - 0.093 sat 0. - 0.782  value 0.973 - 1
//hue < 172 && hue >= 0) && (0< saturation && saturation < 56 ) && (value > 195);
//common room 9pm later hue 0.181 - 0.278 sat 0.279 - 0.471 value 0.631- 0.941
//(hue < 50 && hue >= 33) && (71< saturation && saturation < 120 ) && (value > 161 && value < 240);
//jhomehue 0.216 - 0.380  sat 0.169 - 0.365  value 0.569 - 0.788
//(hue < 69 && hue >= 39) && (43< saturation && saturation < 93 ) && (value > 145 && value < 200);


assign green_detected =
(44 < hue && hue < 65) && (97 < saturation && saturation < 200) && (value > 111); 
//hue 0.184 - 0.322 sat 0.448 - 0.793  value 0.431 - 1
//hue 0.256 - 0.354 sat 0.531 - 0.812  value 0.4 - 0.988
//hue 0.293 - 0.353 sat 0.562 - 0.764  value 0.553 - 0.984
//BAD hue 0.314 - 0.460 sat 0.365 - 0.685  value 0.227 - 0.518
//hue 0.265 - 0.351 sat 0.417 - 0.759  value 0.553 - 1
//hue 0.248 - 0.359 sat 0.383 - 0.786  value 0.435 - 1
//hhome
//(57 <= hue && hue <= 73) && (138 <= saturation && saturation <= 205) && (value >= 98 && value <= 211); 

assign red_detected = 
((hue >= 6 && hue <= 13) && (saturation >= 170 && saturation <= 248) && (value > 130 && value <= 255));
//hue 0.038 - 0.074 sat 0.788 - 0.994  value 0.435 - 0.773
//hue 0.034 - 0.1 sat 0.627 - 0.918  value 0.706 - 1
//hue 0.034 - 0.075 sat 0.757 - 0.938  value 0.627 - 0.957
//hue 0.042 - 0.085 sat 0.729 - 0.932  value 0.820 - 0.957
//hue 0.036 - 0.086 sat 0.678 - 0.976  value 0.482 - 1
//hue 0.039 - 0.072 sat 0.764 - 0.959  value 0.510 - 1 
//hue 0.034 - 0.063 sat 0.756 - 0.948  value 0.643 - 0.851
//hue 0.036 - 0.073 sat 0.785 - 0.948  value 0.722 - 1
//hue 0.036 - 0.072 sat 0.809 - 0.976  value 0.522 - 0.753
//hue 0.034 - 0.071 sat 0.801 - 0.973  value 0.510 - 0.698
//((hue >= 6 && hue <= 13) && (saturation >= 204 && saturation <= 248) && (value > 130 && value < 192));
//jhome
//(8 <= hue && hue <= 22) && (132 <= saturation && saturation <= 209) && (value >= 94 && value <= 174); 

assign black_detected =
//Lab Home
(hue < 177 && hue >= 0) && (0< saturation && saturation < 255) && (value > 15  && value < 57);
//hue 0 - 0.958 sat 0 - 0.456 val 0.216 - 0.353
//commom room
//(hue < 173 && hue >= 0) && (0< saturation && saturation < 116) && (value > 55  && value < 90);
//(hue < 177 && hue >= 0) && (0< saturation && saturation < 187) && (value > 29  && value < 81);
//jhome
//(hue < 177 && hue >= 0) && (0< saturation && saturation < 187) && (value > 29  && value < 81);

assign blue_detected = 
( hue >= 80 && hue <= 125) && (  saturation >= 50 && saturation <= 188) && (27 <= value && value < 124);
//hue 0.133 - 0.581 sat 0.032 - 0.465  value 0.310 - 0.510
//hue 0.236 - 0.690 sat 0.122 - 0.534  value 0.208 - 0.443
//hue 0.000 - 0.958 sat 0.000 - 0.404  value 0.176 - 0.655
//hue 0.233 - 0.767 sat 0.030 - 0.465  value 0.239 - 0.510
//hue 0.442 - 0.867 sat 0.062 - 0.569  value 0.118 - 0.349
//new hue 0.457 - 0.7 sat 0.039 - 0.542  value 0.129 - 0.333
//hue 0.441 - 0.683 sat 0.214 - 0.701  value 0.149 - 0.349
//hue 0.444 - 0.696 sat 0.198 - 0.739  value 0.153 - 0.486
//jhome
//(90 <= hue && hue <= 111) && (76 <= saturation && saturation <= 208) && (value >= 63 && value <= 114); 

assign cyan_detected = 
(51 < hue && hue <= 76) && ( 61 < saturation && saturation <= 136) && ( 79 <= value && value < 161);
//hue 0.19 - 0.4 sat 0.226 - 0.719  value 0.165 - 0.522
//hue 0.257 - 0.423 sat 0.261 - 0.6  value 0.239 - 0.576
//BAD hue 0.280 - 0.477 sat 0.238 - 0.635  value 0.165 - 0.400
//hue 0.288 - 0.419 sat 0.242 - 0.535 value 0.31 - 0.631
//jhome
//(71 <= hue && hue <= 97) && (101 <= saturation && saturation <= 204) && (value >= 59 && value <= 101); 

assign yellow_detected =
(27 <= hue && hue < 34) && (130 < saturation && saturation < 225 ) && (value > 146);
//hue 0.124 - 0.169 sat 0.510 - 0.920  value 0.898 - 1
//hue 0.149 - 0.169 sat 0.498 - 0.818  value 0.839 - 1
//hue 0.148 - 0.170 sat 0.447 - 0.874  value 0.757 - 1
//hue 0.151 - 0.187 sat 0.573 - 0.882  value 0.576 - 1
//jhome
//(32 <= hue && hue <= 43) && (133 <= saturation && saturation <= 200) && (value >= 162 && value <= 255); 


//-------------------------------------------------------------------- HSV --------------------------------------------------------------------

wire red_final_detected, pink_final_detected, green_final_detected, white_final_detected, black_final_detected, cyan_final_detected, yellow_final_detected, blue_final_detected;

assign red_final_detected = (y>130)? (red_detected_1 && red_detected_2 && red_detected_3 && red_detected_4 && red_detected_5 && red_detected_6) : 0;
assign pink_final_detected = (y>130)? (pink_detected_1 && pink_detected_2 && pink_detected_3 && pink_detected_4 && pink_detected_5 && pink_detected_6) : 0 ;
assign green_final_detected = (y>130)? (green_detected_1 && green_detected_2 && green_detected_3 && green_detected_4 && green_detected_5 && green_detected_6) : 0;
assign white_final_detected = (y>130)? (white_detected_1 && white_detected_2 && white_detected_3 && white_detected_4 && white_detected_5 && white_detected_6) : 0;
assign black_final_detected = (y>130)? (black_detected_1 && black_detected_2 && black_detected_3 && black_detected_4 && black_detected_5 && black_detected_6) : 0;
assign cyan_final_detected = (y>130)? (cyan_detected_1 && cyan_detected_2 && cyan_detected_3 && cyan_detected_4 && cyan_detected_5 && cyan_detected_6) : 0;
assign yellow_final_detected = (y>130)? (yellow_detected_1 && yellow_detected_2 && yellow_detected_3 && yellow_detected_4 && yellow_detected_5 && yellow_detected_6) : 0;
assign blue_final_detected = (y>130)? (blue_detected_1 && blue_detected_2 && blue_detected_3 && blue_detected_4 && blue_detected_5 && blue_detected_6) : 0;

assign grey = green[7:1] + red[7:2] + blue[7:2]; //Grey = green/2 + red/4 + blue/4

assign color_high  =  
						//(whiteToBlack) ? (24'hff005d): //red 
						//(blackToWhite) ? (24'h51e5f4): // light blue 
						(white_final_detected) ? {24'hf0f0f0} :  //white
						(black_final_detected) ? (24'h0a0006) :
						(red_final_detected) ? {24'hff0000} :
						//(red_final_detected) ? {24'hff0000} : 
						(green_final_detected) ? {24'h59e02c} :
						(pink_final_detected) ? {24'hff005d} :
						(cyan_final_detected) ? (24'h2fbd9f):
						(yellow_final_detected) ? (24'hede26f):
						(blue_final_detected) ? (24'h6151f4):						
			
						{grey, grey, grey};

// Show bounding box
wire [23:0] new_image;
wire bb_active_r, bb_active_g, bb_active_p, bb_active_w, bb_active_b, bb_active_c, bb_active_y, bb_active_blue;
wire bb_bound;
reg [10:0] left_r, left_p, left_g, left_w, left_b, left_c, left_y, left_blue;
reg [10:0] right_r, right_p, right_g, right_w, right_b, right_c, right_y, right_blue;
reg [10:0] top_r, top_p, top_g, top_w, top_b, top_c, top_y, top_blue;
reg [10:0] bottom_r, bottom_p, bottom_g, bottom_w, bottom_b, bottom_c, bottom_y, bottom_blue;

// assign bb_active_r = (x == left_r && left_r != IMAGE_W-11'h1) || (x == right_r && right_r != 0) || (y == top_r && top_r != IMAGE_H-11'h1) || (y == bottom_r && bottom_r != 0);
// assign bb_active_p = (x == left_p && left_p != IMAGE_W-11'h1) || (x == right_p && right_p != 0) || (y == top_p && top_p != IMAGE_H-11'h1) || (y == bottom_p && bottom_p != 0);
// assign bb_active_g = (x == left_g && left_g != IMAGE_W-11'h1) || (x == right_g && right_g != 0) || (y == top_g && top_g != IMAGE_H-11'h1) || (y == bottom_g && bottom_g != 0);
// assign bb_active_y = (x == left_y && left_y != IMAGE_W-11'h1) || (x == right_y && right_y != 0) || (y == top_y && top_y != IMAGE_H-11'h1) || (y == bottom_y && bottom_y != 0);
// assign bb_active_c = (x == left_c && left_c != IMAGE_W-11'h1) || (x == right_c && right_c != 0) || (y == top_c && top_c != IMAGE_H-11'h1) || (y == bottom_c && bottom_c != 0);
// assign bb_active_blue = (x == left_blue && left_blue != IMAGE_W-11'h1) || (x == right_blue && right_blue != 0) || (y == top_blue && top_blue != IMAGE_H-11'h1) || (y == bottom_blue && bottom_blue != 0);


assign bb_active_r = (x == left_r && left_r != IMAGE_W-11'h1) || (x == right_r && right_r != 0);
assign bb_active_p = (x == left_p && left_p != IMAGE_W-11'h1) || (x == right_p && right_p != 0);
assign bb_active_g = (x == left_g && left_g != IMAGE_W-11'h1) || (x == right_g && right_g != 0);
assign bb_active_y = (x == left_y && left_y != IMAGE_W-11'h1) || (x == right_y && right_y != 0);
assign bb_active_c = (x == left_c && left_c != IMAGE_W-11'h1) || (x == right_c && right_c != 0);
assign bb_active_blue = (x == left_blue && left_blue != IMAGE_W-11'h1) || (x == right_blue && right_blue != 0);


assign bb_bound = 	(x==40) || (x==80) || (x==120) || (x==160) || (x==200) || (x==240) || (x==280) || (x==320) || (x==360) ||
					(x==400) || (x==440) || (x==480) || (x==520) || (x==560) || (x==600) || (x==640); 

assign bb_active_b =    
(x ==  f_slot_1_blackToWhite && f_slot_1_blackToWhite != 0) || 
(x ==  f_slot_2_blackToWhite && f_slot_2_blackToWhite != 0) || 
(x ==  f_slot_3_blackToWhite && f_slot_3_blackToWhite != 0) || 
(x ==  f_slot_4_blackToWhite && f_slot_4_blackToWhite != 0) || 
(x ==  f_slot_5_blackToWhite && f_slot_5_blackToWhite != 0) || 
(x ==  f_slot_6_blackToWhite && f_slot_6_blackToWhite != 0) || 
(x ==  f_slot_7_blackToWhite && f_slot_7_blackToWhite != 0) || 
(x ==  f_slot_8_blackToWhite && f_slot_8_blackToWhite != 0) || 
(x ==  f_slot_9_blackToWhite && f_slot_9_blackToWhite != 0) || 
(x ==  f_slot_10_blackToWhite && f_slot_10_blackToWhite != 0) || 
(x ==  f_slot_11_blackToWhite && f_slot_11_blackToWhite != 0) || 
(x ==  f_slot_12_blackToWhite && f_slot_12_blackToWhite != 0) || 
(x ==  f_slot_13_blackToWhite && f_slot_13_blackToWhite != 0) || 
(x ==  f_slot_14_blackToWhite && f_slot_14_blackToWhite != 0) || 
(x ==  f_slot_15_blackToWhite && f_slot_15_blackToWhite != 0) || 
(x ==  f_slot_16_blackToWhite && f_slot_16_blackToWhite != 0);
                 


assign bb_active_w =    
(x ==  f_slot_1_whiteToBlack && f_slot_1_whiteToBlack != 0) || 
(x ==  f_slot_2_whiteToBlack && f_slot_2_whiteToBlack != 0) || 
(x ==  f_slot_3_whiteToBlack && f_slot_3_whiteToBlack != 0) || 
(x ==  f_slot_4_whiteToBlack && f_slot_4_whiteToBlack != 0) || 
(x ==  f_slot_5_whiteToBlack && f_slot_5_whiteToBlack != 0) || 
(x ==  f_slot_6_whiteToBlack && f_slot_6_whiteToBlack != 0) || 
(x ==  f_slot_7_whiteToBlack && f_slot_7_whiteToBlack != 0) || 
(x ==  f_slot_8_whiteToBlack && f_slot_8_whiteToBlack != 0) || 
(x ==  f_slot_9_whiteToBlack && f_slot_9_whiteToBlack != 0) || 
(x ==  f_slot_10_whiteToBlack && f_slot_10_whiteToBlack != 0) || 
(x ==  f_slot_11_whiteToBlack && f_slot_11_whiteToBlack != 0) || 
(x ==  f_slot_12_whiteToBlack && f_slot_12_whiteToBlack != 0) || 
(x ==  f_slot_13_whiteToBlack && f_slot_13_whiteToBlack != 0) || 
(x ==  f_slot_14_whiteToBlack && f_slot_14_whiteToBlack != 0) || 
(x ==  f_slot_15_whiteToBlack && f_slot_15_whiteToBlack != 0) || 
(x ==  f_slot_16_whiteToBlack && f_slot_16_whiteToBlack != 0) ;


assign new_image = 
 bb_active_w ? {24'hf0f0f0} : 
 bb_active_b ? {24'h0a0006} :
 bb_active_r ? {24'hff0000} : 
 bb_active_p ? {24'hff005d} : 
 bb_active_g ? {24'h59e02c} : 
 bb_active_c ? {24'h2fbd9f} :
 bb_active_y ? {24'hede26f} :
 bb_active_blue ? {24'h6151f4} :
//bb_bound ? {24'h00FF66} :
 color_high; 
assign {red_out, green_out, blue_out} = (mode & ~sop & packet_video) ? new_image : {red,green,blue};

//--------------------------------------------------------------------
// Detecting Edge Building 
//--------------------------------------------------------------------

wire white_1, white_2, white_3, white_4, white_5, white_6, black_1, black_2, black_3, black_4, black_5, black_6; // white = 01, black = 10; nothing = 11;
wire Rwhite_1, Rwhite_2, Rwhite_3, Rwhite_4, Rwhite_5, Rwhite_6, Rblack_1, Rblack_2, Rblack_3, Rblack_4, Rblack_5, Rblack_6; // white = 01, black = 10; nothing = 11;
reg [1:0] bw_1, bw_2, bw_3, bw_4, bw_5, bw_6, bw_7, bw_8,bw_9, bw_10, bw_11, bw_12, bw_13;
reg blackToWhite, whiteToBlack; // Flag
reg whiteToBlack_1, blackToWhite_1; //Delayed Flag

reg [10:0] immediate_blackToWhite_x, immediate_whiteToBlack_x; // coordinate
reg [10:0] current_min_white_x, current_max_white_x;
reg [10:0] current_min_black_x, current_max_black_x;
reg [10:0] max_white_region, max_black_region;
reg [10:0] current_black_region, current_white_region;
reg [10:0] black_count, white_count;

reg [1:0] bw_decide;
//bw_decide
always @(*)begin
	if(black_detected )begin
		bw_decide = 0;
	end
	else if (white_detected) begin
		bw_decide = 2;
	end
	else begin
		bw_decide = 1;
	end
end
//black and white shift reg
always @(posedge clk) begin
	if (x == IMAGE_W-1) begin
		bw_1 <= 1; bw_2 <= 1; bw_3 <= 1; bw_4 <= 1; bw_5 <= 1; bw_6 <= 1;
		bw_7 <= 1;
		bw_8 <= 1; bw_9 <= 1; bw_10 <= 1;  bw_11 <= 1; bw_12 <= 1; bw_13 <= 1;
	end else begin
		bw_1 <=  bw_decide; bw_2 <= bw_1; bw_3 <= bw_2; bw_4 <= bw_3; bw_5 <= bw_4; bw_6 <= bw_5;
		bw_7 <= bw_6;
		bw_8 <= bw_7; bw_9 <= bw_8; bw_10 <= bw_9; bw_11 <= bw_10; bw_12 <= bw_11; bw_13 <= bw_12;
	end
end
reg black_white_edge_detected;
reg signed [5:0] count_white_black;
reg [4:0] count_white;
reg [4:0] count_black;
reg [10:0] max_gap, current_gap;
reg [4:0] left_white_count, right_white_count;
reg [4:0] left_black_count, right_black_count; 
// edge detection + black and white
always @(*)begin
	if (bw_1 == 2 )begin
		count_white = 1;
		count_black = 0;
		left_white_count = 1;
		left_black_count = 0;
	end
	else if (bw_1 == 0)begin
		count_white = 0;
		count_black = 1;
		left_white_count = 0;
		left_black_count = 1;
	end
	else begin
		count_white = 0;
		count_black = 0;
		left_white_count = 0;
		left_black_count = 0;
	end
	if (bw_2 == 2 )begin
		count_white = count_white + 1;
		left_white_count = left_white_count + 1;
	end
	if (bw_2 == 0)begin
		count_black = count_black + 1;
		left_black_count = left_black_count + 1;

	end
	if (bw_3 == 2 )begin
		count_white = count_white + 1;
		left_white_count = left_white_count + 1;
	end
	if (bw_3 == 0)begin
		count_black = count_black + 1;
		left_black_count = left_black_count + 1;
	end
	if (bw_4 == 2 )begin
		count_white = count_white + 1;
		left_white_count = left_white_count + 1;
	end
	if (bw_4 == 0)begin
		count_black = count_black + 1;
		left_black_count = left_black_count + 1;
	end
	if (bw_5 == 2 )begin
		count_white = count_white + 1;
		left_white_count = left_white_count + 1;
	end
	if (bw_5 == 0)begin
		count_black = count_black + 1;
		left_black_count = left_black_count + 1;
	end
	if (bw_6 == 2 )begin
		count_white = count_white + 1;
		left_white_count = left_white_count + 1;
	end
	if (bw_6 == 0)begin
		count_black = count_black + 1;
		left_black_count = left_black_count + 1;
	end
	if (bw_8 == 2 ) begin
		count_white = count_white + 1;
		right_white_count = 1;
		right_black_count = 0;
	end
	else if (bw_8 == 0) begin
		count_black = count_black + 1;
		right_white_count = 0;
		right_black_count = 1;
	end
	else begin
		right_white_count = 0;
		right_black_count = 0;
	end
	if (bw_9 == 2 ) begin
		count_white = count_white + 1;
		right_white_count = right_white_count + 1;
	end
	if (bw_9 == 0) begin
		count_black = count_black + 1;
		right_black_count = right_black_count + 1;
	end
	if (bw_10 == 2 ) begin
		count_white = count_white + 1;
		right_white_count = right_white_count + 1;
	end
	if (bw_10 == 0) begin
		count_black = count_black + 1;
		right_black_count = right_black_count + 1;
	end
	if (bw_11 == 2 ) begin
		count_white = count_white + 1;
		right_white_count = right_white_count + 1;
	end
	if (bw_11 == 0) begin
		count_black = count_black + 1;
		right_black_count = right_black_count + 1;
	end
	if (bw_12 == 2 ) begin
		count_white = count_white + 1;
		right_white_count = right_white_count + 1;
	end
	if (bw_12 == 0) begin
		count_black = count_black + 1;
		right_black_count = right_black_count + 1;
	end
	if (bw_13 == 2 ) begin
		count_white = count_white + 1;
		right_white_count = right_white_count + 1;
	end
	if (bw_13 == 0) begin
		count_black = count_black + 1;
		right_black_count = right_black_count + 1;
	end

	count_white_black = bw_1 + bw_2 + bw_3 + bw_4 + bw_5 + bw_6 - bw_8 - bw_9 - bw_10 - bw_11 - bw_12 - bw_13;

	if ((count_white_black <= 12 && count_white_black >= 6) || (count_white_black <= -6 && count_white_black >= -12)) begin
		black_white_edge_detected = 1;
	end else begin
		black_white_edge_detected = 0;
	end

end
															
// black to white
assign white_1 = bw_1 == 0; 	assign black_1 = bw_8 == 2; 	
assign white_2 = bw_2 == 0; 	assign black_2 = bw_9 == 2; 	
assign white_3 = bw_3 == 0; 	assign black_3 = bw_10 == 2; 	
assign white_4 = bw_4 == 0; 	assign black_4 = bw_11 == 2; 	
assign white_5 = bw_5 == 0; 	assign black_5 = bw_12 == 2; 	
assign white_6 = bw_6 == 0; 	assign black_6 = bw_13 == 2; 	

// white to black															
assign Rwhite_1 = bw_1 == 2; 	assign Rblack_1 = bw_8 == 0;  	
assign Rwhite_2 = bw_2 == 2; 	assign Rblack_2 = bw_9 == 0; 	
assign Rwhite_3 = bw_3 == 2; 	assign Rblack_3 = bw_10 == 0; 	
assign Rwhite_4 = bw_4 == 2; 	assign Rblack_4 = bw_11 == 0; 	
assign Rwhite_5 = bw_5 == 2; 	assign Rblack_5 = bw_12 == 0; 	
assign Rwhite_6 = bw_6 == 2; 	assign Rblack_6 = bw_13 == 0; 	
//decide black to white and white to black														
always @(*) begin
	if(black_white_edge_detected) begin
		whiteToBlack = (left_white_count >= 2) && (right_black_count >= 2);	
		blackToWhite = (left_black_count >= 2) && (right_white_count >= 2);
	end
	else begin
		whiteToBlack = 0;
		blackToWhite = 0;
	end
end


reg [10:0]  slot_1_bw_tmp, slot_2_bw_tmp, slot_3_bw_tmp, slot_4_bw_tmp, slot_5_bw_tmp, slot_6_bw_tmp,  // black to white row variable 
            slot_7_bw_tmp, slot_8_bw_tmp, slot_9_bw_tmp, slot_10_bw_tmp, slot_11_bw_tmp, slot_12_bw_tmp, slot_13_bw_tmp, slot_14_bw_tmp, slot_15_bw_tmp, slot_16_bw_tmp;
reg [10:0]  slot_1_blackToWhite, slot_2_blackToWhite, slot_3_blackToWhite, slot_4_blackToWhite, slot_5_blackToWhite, slot_6_blackToWhite, // black to white final bounding variable 
            slot_7_blackToWhite, slot_8_blackToWhite, slot_9_blackToWhite, slot_10_blackToWhite, slot_11_blackToWhite, slot_12_blackToWhite, slot_13_blackToWhite, slot_14_blackToWhite, slot_15_blackToWhite, slot_16_blackToWhite;

reg [10:0]  slot_1_count_bw, slot_2_count_bw, slot_3_count_bw, slot_4_count_bw, slot_5_count_bw, slot_6_count_bw, slot_7_count_bw, slot_8_count_bw, 
    		slot_9_count_bw, slot_10_count_bw, slot_11_count_bw, slot_12_count_bw, slot_13_count_bw, slot_14_count_bw, slot_15_count_bw, slot_16_count_bw;

reg [10:0]  slot_1_wb_tmp, slot_2_wb_tmp, slot_3_wb_tmp, slot_4_wb_tmp, slot_5_wb_tmp, slot_6_wb_tmp,  // white to black row variable 
            slot_7_wb_tmp, slot_8_wb_tmp, slot_9_wb_tmp, slot_10_wb_tmp, slot_11_wb_tmp, slot_12_wb_tmp, slot_13_wb_tmp, slot_14_wb_tmp, slot_15_wb_tmp, slot_16_wb_tmp; // white to black final bounding variable 
reg [10:0]  slot_1_whiteToBlack, slot_2_whiteToBlack, slot_3_whiteToBlack, slot_4_whiteToBlack, slot_5_whiteToBlack, slot_6_whiteToBlack, slot_7_whiteToBlack, slot_8_whiteToBlack,
            slot_9_whiteToBlack, slot_10_whiteToBlack, slot_11_whiteToBlack, slot_12_whiteToBlack, slot_13_whiteToBlack, slot_14_whiteToBlack, slot_15_whiteToBlack, slot_16_whiteToBlack;

reg [10:0]  slot_1_count_wb, slot_2_count_wb, slot_3_count_wb, slot_4_count_wb, slot_5_count_wb, slot_6_count_wb, slot_7_count_wb, slot_8_count_wb, 
            slot_9_count_wb, slot_10_count_wb, slot_11_count_wb, slot_12_count_wb, slot_13_count_wb, slot_14_count_wb, slot_15_count_wb, slot_16_count_wb;

reg [4:0] center_slot, left_slot, right_slot;

parameter bwb_threshold = 50; //counting threshold 24

reg [10:0]	f_slot_1_blackToWhite, f_slot_9_blackToWhite,
			f_slot_2_blackToWhite, f_slot_10_blackToWhite,
			f_slot_3_blackToWhite, f_slot_11_blackToWhite,
			f_slot_4_blackToWhite, f_slot_12_blackToWhite,
			f_slot_5_blackToWhite, f_slot_13_blackToWhite,
			f_slot_6_blackToWhite, f_slot_14_blackToWhite,
			f_slot_7_blackToWhite, f_slot_15_blackToWhite,
			f_slot_8_blackToWhite, f_slot_16_blackToWhite;

reg [10:0]	f_slot_1_whiteToBlack, f_slot_9_whiteToBlack,
			f_slot_2_whiteToBlack, f_slot_10_whiteToBlack,
			f_slot_3_whiteToBlack, f_slot_11_whiteToBlack,
			f_slot_4_whiteToBlack, f_slot_12_whiteToBlack,
			f_slot_5_whiteToBlack, f_slot_13_whiteToBlack,
			f_slot_6_whiteToBlack, f_slot_14_whiteToBlack,
			f_slot_7_whiteToBlack, f_slot_15_whiteToBlack,
			f_slot_8_whiteToBlack, f_slot_16_whiteToBlack;

reg [4:0] count_w_b, count_b_w;
reg [10:0] left_most_bound, right_most_bound;
//TODO : 


always @(posedge clk) begin
		
	if (eop & in_valid & packet_video) begin

		slot_1_count_bw <= 0; slot_2_count_bw <= 0; slot_3_count_bw <= 0; slot_4_count_bw <= 0; slot_5_count_bw <= 0; slot_6_count_bw <= 0; slot_7_count_bw <= 0; slot_8_count_bw <= 0;
		slot_9_count_bw <= 0; slot_10_count_bw <=0; slot_11_count_bw <= 0; slot_12_count_bw <= 0; slot_13_count_bw <= 0; slot_14_count_bw <= 0; slot_15_count_bw <= 0; slot_16_count_bw <= 0;

		slot_1_count_wb <= 0; slot_2_count_wb <= 0; slot_3_count_wb <= 0; slot_4_count_wb <= 0; slot_5_count_wb <= 0; slot_6_count_wb <= 0; slot_7_count_wb <= 0; slot_8_count_wb <= 0;
		slot_9_count_wb <= 0; slot_10_count_wb <=0; slot_11_count_wb <= 0; slot_12_count_wb <= 0; slot_13_count_wb <= 0; slot_14_count_wb <= 0; slot_15_count_wb <= 0; slot_16_count_wb <= 0;
		
		slot_1_bw_tmp <= 0;	slot_9_bw_tmp <= 0;
		slot_2_bw_tmp <= 0; slot_10_bw_tmp <= 0;
		slot_3_bw_tmp <= 0; slot_11_bw_tmp <= 0;
		slot_4_bw_tmp <= 0; slot_12_bw_tmp <= 0; 
		slot_5_bw_tmp <= 0; slot_13_bw_tmp <= 0;
		slot_6_bw_tmp <= 0; slot_14_bw_tmp <= 0;
		slot_7_bw_tmp <= 0; slot_15_bw_tmp <= 0;
		slot_8_bw_tmp <= 0; slot_16_bw_tmp <= 0;

		slot_1_wb_tmp <= 0;	slot_9_wb_tmp <= 0;
		slot_2_wb_tmp <= 0; slot_10_wb_tmp <= 0;
		slot_3_wb_tmp <= 0; slot_11_wb_tmp <= 0;
		slot_4_wb_tmp <= 0; slot_12_wb_tmp <= 0; 
		slot_5_wb_tmp <= 0; slot_13_wb_tmp <= 0;
		slot_6_wb_tmp <= 0; slot_14_wb_tmp <= 0;
		slot_7_wb_tmp <= 0; slot_15_wb_tmp <= 0;
		slot_8_wb_tmp <= 0; slot_16_wb_tmp <= 0;

		slot_1_blackToWhite <= 0;
		slot_2_blackToWhite <= 0;
		slot_3_blackToWhite <= 0;
		slot_4_blackToWhite <= 0;
		slot_5_blackToWhite <= 0;

		slot_6_blackToWhite <= 0;
		slot_7_blackToWhite <= 0;
		slot_8_blackToWhite <= 0;
		slot_9_blackToWhite <= 0;
		slot_10_blackToWhite <= 0;

		slot_11_blackToWhite <= 0;
		slot_12_blackToWhite <= 0;
		slot_13_blackToWhite <= 0;
		slot_14_blackToWhite <= 0;
		slot_15_blackToWhite <= 0;
		slot_16_blackToWhite <= 0;


		slot_1_whiteToBlack <= 0;
		slot_2_whiteToBlack <= 0;
		slot_3_whiteToBlack <= 0;
		slot_4_whiteToBlack <= 0;
		slot_5_whiteToBlack <= 0;

		slot_6_whiteToBlack <= 0;
		slot_7_whiteToBlack <= 0;
		slot_8_whiteToBlack <= 0;
		slot_9_whiteToBlack <= 0;
		slot_10_whiteToBlack <= 0;

		slot_11_whiteToBlack <= 0;
		slot_12_whiteToBlack <= 0;
		slot_13_whiteToBlack <= 0;
		slot_14_whiteToBlack <= 0;
		slot_15_whiteToBlack <= 0;
		slot_16_whiteToBlack <= 0;


		f_slot_1_blackToWhite <= slot_1_blackToWhite; f_slot_9_blackToWhite  <= slot_9_blackToWhite;
		f_slot_2_blackToWhite <= slot_2_blackToWhite; f_slot_10_blackToWhite <= slot_10_blackToWhite;
		f_slot_3_blackToWhite <= slot_3_blackToWhite; f_slot_11_blackToWhite <= slot_11_blackToWhite;
		f_slot_4_blackToWhite <= slot_4_blackToWhite; f_slot_12_blackToWhite <= slot_12_blackToWhite; 
		f_slot_5_blackToWhite <= slot_5_blackToWhite; f_slot_13_blackToWhite <= slot_13_blackToWhite;
		f_slot_6_blackToWhite <= slot_6_blackToWhite; f_slot_14_blackToWhite <= slot_14_blackToWhite;
		f_slot_7_blackToWhite <= slot_7_blackToWhite; f_slot_15_blackToWhite <= slot_15_blackToWhite;
		f_slot_8_blackToWhite <= slot_8_blackToWhite; f_slot_16_blackToWhite <= slot_16_blackToWhite;

		f_slot_1_whiteToBlack <= slot_1_whiteToBlack; f_slot_9_whiteToBlack  <= slot_9_whiteToBlack;
		f_slot_2_whiteToBlack <= slot_2_whiteToBlack; f_slot_10_whiteToBlack <= slot_10_whiteToBlack;
		f_slot_3_whiteToBlack <= slot_3_whiteToBlack; f_slot_11_whiteToBlack <= slot_11_whiteToBlack;
		f_slot_4_whiteToBlack <= slot_4_whiteToBlack; f_slot_12_whiteToBlack <= slot_12_whiteToBlack; 
		f_slot_5_whiteToBlack <= slot_5_whiteToBlack; f_slot_13_whiteToBlack <= slot_13_whiteToBlack;
		f_slot_6_whiteToBlack <= slot_6_whiteToBlack; f_slot_14_whiteToBlack <= slot_14_whiteToBlack;
		f_slot_7_whiteToBlack <= slot_7_whiteToBlack; f_slot_15_whiteToBlack <= slot_15_whiteToBlack;
		f_slot_8_whiteToBlack <= slot_8_whiteToBlack; f_slot_16_whiteToBlack <= slot_16_whiteToBlack;
	end
	else begin 
			if(0<x && x<=40) begin // pure or
				if(blackToWhite && blackToWhite_1) begin
					if(slot_1_count_bw == 0) begin 
						slot_1_bw_tmp <= x; 
						slot_1_count_bw <= 1;
						slot_1_blackToWhite <= 0;
					end
				else if(slot_1_count_bw <= bwb_threshold) begin
						if(((x >= slot_1_bw_tmp) && (x-slot_1_bw_tmp <= 5) )||((x < slot_1_bw_tmp) && (slot_1_bw_tmp - x <= 5)))begin 
							slot_1_count_bw <= slot_1_count_bw + 3;
						end
						else slot_1_count_bw <= slot_1_count_bw - 1;
					end
					else if((slot_1_count_bw > bwb_threshold) && (slot_1_blackToWhite != slot_1_bw_tmp)) begin
						slot_1_blackToWhite <= slot_1_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_1_count_wb == 0) begin 
						slot_1_wb_tmp <= x; 
						slot_1_count_wb <= 1;
						slot_1_whiteToBlack <= 0;
					end
					else if(slot_1_count_wb <= bwb_threshold) begin
						if(((x >= slot_1_wb_tmp) && (x-slot_1_wb_tmp <= 5) )||((x < slot_1_wb_tmp) && (slot_1_wb_tmp - x <= 5)))begin 
							slot_1_count_wb <= slot_1_count_wb + 3;
						end
						else slot_1_count_wb <= slot_1_count_wb - 1;
					end
					else if((slot_1_count_wb > bwb_threshold) && (slot_1_whiteToBlack != slot_1_wb_tmp)) begin
						slot_1_whiteToBlack <= slot_1_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end 
			else if(40<x && x<=80) begin  
				if(blackToWhite && blackToWhite_1) begin
					if(slot_2_count_bw == 0) begin 
						slot_2_bw_tmp <= x; 
						slot_2_count_bw <= 1;
						slot_2_blackToWhite <= 0;
					end
					else if(slot_2_count_bw <= bwb_threshold) begin
						if(((x >= slot_2_bw_tmp) && (x-slot_2_bw_tmp <= 5) )||((x < slot_2_bw_tmp) && (slot_2_bw_tmp - x <= 5)))begin 
							slot_2_count_bw <= slot_2_count_bw + 3;
						end	 
						else slot_2_count_bw <= slot_2_count_bw - 1;
					end
					else if ((slot_2_count_bw > bwb_threshold) && (slot_2_blackToWhite != slot_2_bw_tmp)) begin
						slot_2_blackToWhite <= slot_2_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_2_count_wb == 0) begin 
						slot_2_wb_tmp <= x; 
						slot_2_count_wb <= 1;
						slot_2_whiteToBlack <= 0;
					end
					else if(slot_2_count_wb <= bwb_threshold) begin
						if(((x >= slot_2_wb_tmp) && (x-slot_2_wb_tmp <= 5) )||((x < slot_2_wb_tmp) && (slot_2_wb_tmp - x <= 5)))begin 
							slot_2_count_wb <= slot_2_count_wb + 3;
						end
						else slot_2_count_wb <= slot_2_count_wb - 1;
					end
					else if((slot_2_count_wb > bwb_threshold) && (slot_2_whiteToBlack != slot_2_wb_tmp)) begin
						slot_2_whiteToBlack <= slot_2_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(80<x && x<=120) begin  
				if(blackToWhite && blackToWhite_1) begin
					if(slot_3_count_bw == 0) begin 
						slot_3_bw_tmp <= x; 
						slot_3_count_bw <= 1;
						slot_3_blackToWhite <= 0;
					end
					else if(slot_3_count_bw <= bwb_threshold) begin
						if(((x >= slot_3_bw_tmp) && (x-slot_3_bw_tmp <= 5) )||((x < slot_3_bw_tmp) && (slot_3_bw_tmp - x <= 5)))begin 
							slot_3_count_bw <= slot_3_count_bw + 3;
						end
						else slot_3_count_bw <= slot_3_count_bw - 1;
					end
					else if((slot_3_count_bw > bwb_threshold) && (slot_3_blackToWhite != slot_3_bw_tmp)) begin
						slot_3_blackToWhite <= slot_3_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_3_count_wb == 0) begin 
						slot_3_wb_tmp <= x; 
						slot_3_count_wb <= 1;
						slot_3_whiteToBlack <= 0;
					end
					else if(slot_3_count_wb <= bwb_threshold) begin
						if(((x >= slot_3_wb_tmp) && (x-slot_3_wb_tmp <= 5) )||((x < slot_3_wb_tmp) && (slot_3_wb_tmp - x <= 5))) begin 
							slot_3_count_wb <= slot_3_count_wb + 3;
						end
						else slot_3_count_wb <= slot_3_count_wb - 1;
					end
					else if((slot_3_count_wb > bwb_threshold) && (slot_3_whiteToBlack != slot_3_wb_tmp)) begin
						slot_3_whiteToBlack <= slot_3_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(120<x && x<=160) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_4_count_bw == 0) begin 
						slot_4_bw_tmp <= x; 
						slot_4_count_bw <= 1;
						slot_4_blackToWhite <= 0;
					end
					else if(slot_4_count_bw <= bwb_threshold) begin
						if(((x >= slot_4_bw_tmp) && (x-slot_4_bw_tmp <= 5) )||((x < slot_4_bw_tmp) && (slot_4_bw_tmp - x <= 5)))begin 
							slot_4_count_bw <= slot_4_count_bw + 3;
						end
						else slot_4_count_bw <= slot_4_count_bw - 1;
					end
					else if((slot_4_count_bw > bwb_threshold) && (slot_4_blackToWhite != slot_4_bw_tmp)) begin
						slot_4_blackToWhite <= slot_4_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_4_count_wb == 0) begin 
						slot_4_wb_tmp <= x; 
						slot_4_count_wb <= 1;
						slot_4_whiteToBlack <= 0;
					end
					else if(slot_4_count_wb <= bwb_threshold) begin
						if(((x >= slot_4_wb_tmp) && (x-slot_4_wb_tmp <= 5) )||((x < slot_4_wb_tmp) && (slot_4_wb_tmp - x <= 5)))begin
							slot_4_count_wb <= slot_4_count_wb + 3;
						end
						else slot_4_count_wb <= slot_4_count_wb - 1;
					end
					else if((slot_4_count_wb > bwb_threshold) && (slot_4_whiteToBlack != slot_4_wb_tmp)) begin
						slot_4_whiteToBlack <= slot_4_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(160<x && x<=200) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_5_count_bw == 0) begin 
						slot_5_blackToWhite <= 0;
						slot_5_bw_tmp <= x; 
						slot_5_count_bw <= 1;
					end
					else if(slot_5_count_bw <= bwb_threshold) begin
						if(((x >= slot_5_bw_tmp) && (x-slot_5_bw_tmp <= 5) )||((x < slot_5_bw_tmp) && (slot_5_bw_tmp - x <= 5)))begin
							slot_5_count_bw <= slot_5_count_bw + 3;
						end 
						else slot_5_count_bw <= slot_5_count_bw - 1;
					end
					
					else if((slot_5_count_bw > bwb_threshold) && (slot_5_blackToWhite != slot_5_bw_tmp)) begin
						slot_5_blackToWhite <= slot_5_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_5_count_wb == 0) begin 
						slot_5_whiteToBlack <= 0;
						slot_5_wb_tmp <= x; 
						slot_5_count_wb <= 1;
					end
					else if(slot_5_count_wb <= bwb_threshold) begin
						if(((x >= slot_5_wb_tmp) && (x-slot_5_wb_tmp <= 5) )||((x < slot_5_wb_tmp) && (slot_5_wb_tmp - x <= 5)))begin
							slot_5_count_wb <= slot_5_count_wb + 3;
						end
						else slot_5_count_wb <= slot_5_count_wb - 1;
					end
					else if((slot_5_count_wb > bwb_threshold) && (slot_5_whiteToBlack != slot_5_wb_tmp)) begin
						slot_5_whiteToBlack <= slot_5_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(200<x && x<=240) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_6_count_bw == 0) begin 
						slot_6_bw_tmp <= x; 
						slot_6_count_bw <= 1;
						slot_6_blackToWhite <= 0;
					end
					else if(slot_6_count_bw <= bwb_threshold) begin
						if(((x >= slot_6_bw_tmp) && (x-slot_6_bw_tmp <= 5) )||((x < slot_6_bw_tmp) && (slot_6_bw_tmp - x <= 5)))begin
							slot_6_count_bw <= slot_6_count_bw + 3;
						end
						else slot_6_count_bw <= slot_6_count_bw - 1;
					end
					else if((slot_6_count_bw > bwb_threshold) && (slot_6_blackToWhite != slot_6_bw_tmp)) begin
						slot_6_blackToWhite <= slot_6_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_6_count_wb == 0) begin 
						slot_6_wb_tmp <= x; 
						slot_6_count_wb <= 1;
						slot_6_whiteToBlack <= 0;
					end
					else if(slot_6_count_wb <= bwb_threshold) begin
						if(((x >= slot_6_wb_tmp) && (x-slot_6_wb_tmp <= 5 ))||((x < slot_6_wb_tmp) && (slot_6_wb_tmp - x <= 5)) )begin
							slot_6_count_wb <= slot_6_count_wb + 3;
						end
						else slot_6_count_wb <= slot_6_count_wb - 1;
					end
					else if((slot_6_count_wb > bwb_threshold) && (slot_6_whiteToBlack != slot_6_wb_tmp)) begin
						slot_6_whiteToBlack <= slot_6_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(240<x && x<=280) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_7_count_bw == 0) begin 
						slot_7_bw_tmp <= x; 
						slot_7_count_bw <= 1;
						slot_7_blackToWhite <= 0;
					end
					else if(slot_7_count_bw <= bwb_threshold) begin
						if(((x >= slot_7_bw_tmp) && (x-slot_7_bw_tmp <= 5) )||((x < slot_7_bw_tmp) && (slot_7_bw_tmp - x <= 5)))begin
						//if(x-slot_7_bw_tmp <= 5 && x-slot_7_bw_tmp >= -5) begin
							slot_7_count_bw <= slot_7_count_bw + 3;
						end
						else slot_7_count_bw <= slot_7_count_bw - 1;
					end
					else if((slot_7_count_bw > bwb_threshold) && (slot_7_blackToWhite != slot_7_bw_tmp)) begin
						slot_7_blackToWhite <= slot_7_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack) begin
					if(slot_7_count_wb == 0) begin 
						slot_7_wb_tmp <= x; 
						slot_7_count_wb <= 1;
						slot_7_whiteToBlack <= 0;
					end
					else if(slot_7_count_wb <= bwb_threshold) begin
						if(((x >= slot_7_wb_tmp) && (x-slot_7_wb_tmp <= 5 ))||((x < slot_7_wb_tmp) && (slot_7_wb_tmp - x <= 5)) )begin
							slot_7_count_wb <= slot_7_count_wb + 3;
						end
						else slot_7_count_wb <= slot_7_count_wb - 1;
					end
					else if((slot_7_count_wb > bwb_threshold) && (slot_7_whiteToBlack != slot_7_wb_tmp)) begin
						slot_7_whiteToBlack <= slot_7_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(280<x && x<=320) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_8_count_bw == 0) begin 
						slot_8_bw_tmp <= x; 
						slot_8_count_bw <= 1;
						slot_8_blackToWhite <= 0;
					end
					else if(slot_8_count_bw <= bwb_threshold) begin
						if(((x >= slot_8_bw_tmp) && (x-slot_8_bw_tmp <= 5) )||((x < slot_8_bw_tmp) && (slot_8_bw_tmp - x <= 5)))begin
							slot_8_count_bw <= slot_8_count_bw + 3;
						end
						else slot_8_count_bw <= slot_8_count_bw - 1;
					end
					else if((slot_8_count_bw > bwb_threshold) && (slot_8_blackToWhite != slot_8_bw_tmp)) begin
						slot_8_blackToWhite <= slot_8_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_8_count_wb == 0) begin 
						slot_8_wb_tmp <= x; 
						slot_8_count_wb <= 1;
						slot_8_whiteToBlack <= 0;
					end
					else if(slot_8_count_wb <= bwb_threshold) begin
						if(((x >= slot_8_wb_tmp) && (x-slot_8_wb_tmp <= 5 ))||((x < slot_8_wb_tmp) && (slot_8_wb_tmp - x <= 5)) )begin
						//if(x-slot_8_wb_tmp <= 5 && x-slot_8_wb_tmp >= -5) begin 
							slot_8_count_wb <= slot_8_count_wb + 3;
							//slot_8_whiteToBlack <= slot_8_wb_tmp;
						end 
						else slot_8_count_wb <= slot_8_count_wb - 1;
					end
					else if((slot_8_count_wb > bwb_threshold) && (slot_8_whiteToBlack != slot_8_wb_tmp)) begin
						slot_8_whiteToBlack <= slot_8_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(320<x && x<=360) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_9_count_bw == 0) begin 
						slot_9_bw_tmp <= x; 
						slot_9_count_bw <= 1;
						slot_9_blackToWhite <= 0;
					end
					else if(slot_9_count_bw <= bwb_threshold) begin
						if(((x >= slot_9_bw_tmp) && (x-slot_9_bw_tmp <= 5) )||((x < slot_9_bw_tmp) && (slot_9_bw_tmp - x <= 5)))begin
							slot_9_count_bw <= slot_9_count_bw + 3;
						end
						else slot_9_count_bw <= slot_9_count_bw - 1;
					end
					else if((slot_9_count_bw > bwb_threshold) && (slot_9_blackToWhite != slot_9_bw_tmp)) begin
						slot_9_blackToWhite <= slot_9_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_9_count_wb == 0) begin 
						slot_9_wb_tmp <= x; 
						slot_9_count_wb <= 1;
						slot_9_whiteToBlack <= 0;
					end
					else if(slot_9_count_wb <= bwb_threshold) begin
						if(((x >= slot_9_wb_tmp) && (x-slot_9_wb_tmp <= 5 ))||((x < slot_9_wb_tmp) && (slot_9_wb_tmp - x <= 5)) )begin
						//if(x-slot_8_wb_tmp <= 5 && x-slot_8_wb_tmp >= -5) begin 
							slot_9_count_wb <= slot_9_count_wb + 3;
							//slot_8_whiteToBlack <= slot_8_wb_tmp;
						end 
						else slot_9_count_wb <= slot_9_count_wb - 1;
					end
					else if((slot_9_count_wb > bwb_threshold) && (slot_9_whiteToBlack != slot_9_wb_tmp)) begin
						slot_9_whiteToBlack <= slot_9_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end

			end
			else if(360<x && x<=400) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_10_count_bw == 0) begin 
						slot_10_bw_tmp <= x; 
						slot_10_count_bw <= 1;
						slot_10_blackToWhite <= 0;
					end
					else if(slot_10_count_bw <= bwb_threshold) begin
						if(((x >= slot_10_bw_tmp) && (x-slot_10_bw_tmp <= 5) )||((x < slot_10_bw_tmp) && (slot_10_bw_tmp - x <= 5))) begin
							slot_10_count_bw <= slot_10_count_bw + 3;
							//slot_10_blackToWhite <= slot_10_bw_tmp;
						end
						else slot_10_count_bw <= slot_10_count_bw - 1;
					end
					else if((slot_10_count_bw > bwb_threshold) && (slot_10_blackToWhite != slot_10_bw_tmp)) begin
						slot_10_blackToWhite <= slot_10_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_10_count_wb == 0) begin 
						slot_10_wb_tmp <= x; 
						slot_10_count_wb <= 1;
						slot_10_whiteToBlack <= 0;
					end
					else if(slot_10_count_wb <= bwb_threshold) begin
						if(((x >= slot_10_wb_tmp) && (x-slot_10_wb_tmp <= 5) )||((x < slot_10_wb_tmp) && (slot_10_wb_tmp - x <= 5))) begin 
							slot_10_count_wb <= slot_10_count_wb + 3;
								//slot_10_whiteToBlack <= slot_10_wb_tmp;
						end
						else slot_10_count_wb <= slot_10_count_wb - 1;
					end
					else if((slot_10_count_wb > bwb_threshold) && (slot_10_whiteToBlack != slot_10_wb_tmp)) begin
						slot_10_whiteToBlack <= slot_10_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(400<x && x<=440) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_11_count_bw == 0) begin 
						slot_11_bw_tmp <= x; 
						slot_11_count_bw <= 1;
						slot_11_blackToWhite <= 0;
					end
					else if(slot_11_count_bw <= bwb_threshold) begin
						if(((x >= slot_11_bw_tmp) && (x-slot_11_bw_tmp <= 5) )||((x < slot_11_bw_tmp) && (slot_11_bw_tmp - x <= 5)))begin
							slot_11_count_bw <= slot_11_count_bw + 3;
							//slot_11_blackToWhite <= slot_11_bw_tmp;
						end
						else slot_11_count_bw <= slot_11_count_bw - 1;
					end
					else if((slot_11_count_bw > bwb_threshold) && (slot_11_blackToWhite != slot_11_bw_tmp)) begin
						slot_11_blackToWhite <= slot_11_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_11_count_wb == 0) begin 
						slot_11_wb_tmp <= x; 
						slot_11_count_wb <= 1;
						slot_11_whiteToBlack <= 0;
					end
					else if(slot_11_count_wb <= bwb_threshold) begin
						if(((x >= slot_11_wb_tmp) && (x-slot_11_wb_tmp <= 5) )||((x < slot_11_wb_tmp) && (slot_11_wb_tmp - x <= 5))) begin 
							slot_11_count_wb <= slot_11_count_wb + 3;
							//slot_11_whiteToBlack <= slot_11_wb_tmp;
						end
						else slot_11_count_wb <= slot_11_count_wb - 1;
					end
					else if((slot_11_count_wb > bwb_threshold) && (slot_11_whiteToBlack != slot_11_wb_tmp)) begin
						slot_11_whiteToBlack <= slot_11_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(440<x && x<=480) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_12_count_bw == 0) begin 
						slot_12_bw_tmp <= x; 
						slot_12_count_bw <= 1;
						slot_12_blackToWhite <= 0;
					end
					else if(slot_12_count_bw <= bwb_threshold) begin
						if(((x >= slot_12_bw_tmp) && (x-slot_12_bw_tmp <= 5) )||((x < slot_12_bw_tmp) && (slot_12_bw_tmp - x <= 5))) begin 
							slot_12_count_bw <= slot_12_count_bw + 3;
							//slot_12_blackToWhite <= slot_12_bw_tmp;
						end
						else slot_12_count_bw <= slot_12_count_bw - 1;
					end
					else if((slot_12_count_bw > bwb_threshold) && (slot_12_blackToWhite != slot_12_bw_tmp)) begin
						slot_12_blackToWhite <= slot_12_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_12_count_wb == 0) begin 
						slot_12_wb_tmp <= x; 
						slot_12_count_wb <= 1;
						slot_12_whiteToBlack <= 0;
					end
					else if(slot_12_count_wb <= bwb_threshold) begin
						if(((x >= slot_12_wb_tmp) && (x-slot_12_wb_tmp <= 5) )||((x < slot_12_wb_tmp) && (slot_12_wb_tmp - x <= 5))) begin 
							slot_12_count_wb <= slot_12_count_wb + 3;
							//slot_12_whiteToBlack <= slot_12_wb_tmp;
						end
						else slot_12_count_wb <= slot_12_count_wb - 1;
					end
					else if((slot_12_count_wb > bwb_threshold) && (slot_12_whiteToBlack != slot_12_wb_tmp)) begin
						slot_12_whiteToBlack <= slot_12_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(480<x && x<=520) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_13_count_bw == 0) begin 
						slot_13_bw_tmp <= x; 
						slot_13_count_bw <= 1;
						slot_13_blackToWhite <= 0;
					end
					else if(slot_13_count_bw <= bwb_threshold) begin
						if(((x >= slot_13_bw_tmp) && (x-slot_13_bw_tmp <= 5) )||((x < slot_13_bw_tmp) && (slot_13_bw_tmp - x <= 5))) begin
							slot_13_count_bw <= slot_13_count_bw + 3;
							//slot_13_blackToWhite <= slot_13_bw_tmp;
						end
						else slot_13_count_bw <= slot_13_count_bw - 1;
					end
					else if((slot_13_count_bw > bwb_threshold) && (slot_13_blackToWhite != slot_13_bw_tmp)) begin
						slot_13_blackToWhite <= slot_13_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_13_count_wb == 0) begin 
						slot_13_wb_tmp <= x; 
						slot_13_count_wb <= 1;
						slot_13_whiteToBlack <= 0;
					end
					else if(slot_13_count_wb <= bwb_threshold) begin
						if(((x >= slot_13_wb_tmp) && (x-slot_13_wb_tmp <= 5) )||((x < slot_13_wb_tmp) && (slot_13_wb_tmp - x <= 5)))begin
							slot_13_count_wb <= slot_13_count_wb + 3;
							//slot_13_whiteToBlack <= slot_13_wb_tmp;
						end
						else slot_13_count_wb <= slot_13_count_wb - 1;
					end
					else if((slot_13_count_wb > bwb_threshold) && (slot_13_whiteToBlack != slot_13_wb_tmp)) begin
						slot_13_whiteToBlack <= slot_13_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(520<x && x<=560) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_14_count_bw == 0) begin
						slot_14_bw_tmp <= x; 
						slot_14_blackToWhite <= 0; 
						slot_14_count_bw <= 1;
					end
					else if(slot_14_count_bw <= bwb_threshold) begin
						if(((x >= slot_14_bw_tmp) && (x-slot_14_bw_tmp <= 5) )||((x < slot_14_bw_tmp) && (slot_14_bw_tmp - x <= 5))) begin
							slot_14_count_bw <= slot_14_count_bw + 3;
							//slot_14_blackToWhite <= slot_4_bw_tmp;
						end
						else slot_14_count_bw <= slot_14_count_bw - 1;
					end
					else if((slot_14_count_bw > bwb_threshold) && (slot_14_blackToWhite != slot_14_bw_tmp)) begin
						slot_14_blackToWhite <= slot_14_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_14_count_wb == 0) begin 
						slot_14_wb_tmp <= x; 
						slot_14_whiteToBlack <= 0; 
						slot_14_count_wb <= 1;
					end
					else if(slot_14_count_wb <= bwb_threshold) begin
						if(((x >= slot_14_wb_tmp) && (x-slot_14_wb_tmp <= 5) )||((x < slot_14_wb_tmp) && (slot_14_wb_tmp - x <= 5)))begin
							slot_14_count_wb <= slot_14_count_wb + 3;
							//slot_14_whiteToBlack <= slot_4_wb_tmp;
						end
						else slot_14_count_wb <= slot_14_count_wb - 1;
					end
					else if((slot_14_count_wb > bwb_threshold) && (slot_14_whiteToBlack != slot_14_wb_tmp)) begin
						slot_14_whiteToBlack <= slot_14_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end
			else if(560<x && x<=600) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_15_count_bw == 0) begin 
						slot_15_bw_tmp <= x; 
						slot_15_blackToWhite <= 0;
						slot_15_count_bw <= 1;
					end
					else if(slot_15_count_bw <= bwb_threshold) begin
						if(((x >= slot_15_bw_tmp) && (x-slot_15_bw_tmp <= 5) )||((x < slot_15_bw_tmp) && (slot_15_bw_tmp - x <= 5))) begin
							slot_15_count_bw <= slot_15_count_bw + 3;
							//slot_15_blackToWhite <= slot_15_bw_tmp;
						end
						else slot_15_count_bw <= slot_15_count_bw - 1;
					end
					else if((slot_15_count_bw > bwb_threshold) && (slot_15_blackToWhite != slot_15_bw_tmp)) begin
						slot_15_blackToWhite <= slot_15_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_15_count_wb == 0) begin 
						slot_15_wb_tmp <= x; 
						slot_15_whiteToBlack <= 0;
						slot_15_count_wb <= 1;
					end
					else if(slot_15_count_wb <= bwb_threshold) begin
						if(((x >= slot_15_wb_tmp) && (x-slot_15_wb_tmp <= 5) )||((x < slot_15_wb_tmp) && (slot_15_wb_tmp - x <= 5))) begin
							slot_15_count_wb <= slot_15_count_wb + 3;
							//slot_15_whiteToBlack <= slot_15_wb_tmp;
						end
						else slot_15_count_wb <= slot_15_count_wb - 1;
					end
					else if((slot_15_count_wb > bwb_threshold) && (slot_15_whiteToBlack != slot_15_wb_tmp)) begin
						slot_15_whiteToBlack <= slot_15_wb_tmp;
						count_w_b <= count_w_b + 1;
					end
				end
			end	
			else if(600<x && x<=640) begin 
				if(blackToWhite && blackToWhite_1) begin
					if(slot_16_count_bw == 0) begin 
						slot_16_bw_tmp <= x;
						slot_16_blackToWhite <= 0; 
						slot_16_count_bw <= 1;
					end
					else if(slot_16_count_bw <= bwb_threshold) begin
						if(((x >= slot_16_bw_tmp) && (x-slot_1_bw_tmp <= 5) )||((x < slot_16_bw_tmp) && (slot_16_bw_tmp - x <= 5))) begin 
							slot_16_count_bw <= slot_16_count_bw + 3;
						end 
						else slot_16_count_bw <= slot_16_count_bw - 1;
					end
					else if((slot_16_count_bw > bwb_threshold) && (slot_16_blackToWhite != slot_16_bw_tmp)) begin
						slot_16_blackToWhite <= slot_16_bw_tmp;
						count_b_w <= count_b_w + 1;
					end
				end 
				
				else if(whiteToBlack && whiteToBlack_1) begin
					if(slot_16_count_wb == 0) begin 
						slot_16_count_wb <= x;
						slot_16_whiteToBlack <= 0; 
						slot_16_count_wb <= 1;
					end
					else if(slot_16_count_wb <= bwb_threshold) begin
						if(((x >= slot_16_wb_tmp) && (x-slot_16_wb_tmp <= 5) )||((x < slot_16_wb_tmp) && (slot_16_wb_tmp - x <= 5))) begin
							slot_16_count_wb <= slot_16_count_wb + 3;
						end 
						else slot_16_count_wb <= slot_16_count_wb - 1;
					end
					else if((slot_16_count_wb > bwb_threshold) && (slot_16_whiteToBlack != slot_16_wb_tmp)) begin
						slot_16_whiteToBlack <= slot_16_wb_tmp;	
						count_w_b <= count_w_b + 1;				
					end
					
				end
			end

		
		left_slot = (f_slot_2_blackToWhite != 0 || f_slot_2_whiteToBlack != 0) ? 2 : (f_slot_3_blackToWhite != 0 || f_slot_3_whiteToBlack != 0) ? 3 : (f_slot_4_blackToWhite != 0 || f_slot_4_whiteToBlack != 0) ? 4 :
					(f_slot_5_blackToWhite != 0 || f_slot_5_whiteToBlack != 0) ? 5 : (f_slot_6_blackToWhite != 0 || f_slot_6_whiteToBlack != 0) ? 6 : (f_slot_7_blackToWhite != 0 || f_slot_7_whiteToBlack != 0) ? 7 : 
					(f_slot_8_blackToWhite != 0 || f_slot_8_whiteToBlack != 0) ? 8 : (f_slot_9_blackToWhite != 0 || f_slot_9_whiteToBlack != 0) ? 9 : (f_slot_10_blackToWhite != 0 || f_slot_10_whiteToBlack != 0) ? 10 :
					(f_slot_11_blackToWhite != 0 || f_slot_11_whiteToBlack != 0) ? 11 : (f_slot_12_blackToWhite != 0 || f_slot_12_whiteToBlack != 0) ? 12 : (f_slot_13_blackToWhite != 0 || f_slot_13_whiteToBlack != 0) ? 13 :
					(f_slot_14_blackToWhite != 0 || f_slot_14_whiteToBlack != 0) ? 14 : (f_slot_15_blackToWhite != 0 || f_slot_15_whiteToBlack != 0) ? 15 : 0;
		
		right_slot = (f_slot_15_blackToWhite != 0 || f_slot_15_whiteToBlack != 0) ? 15 : (f_slot_14_blackToWhite != 0 || f_slot_14_whiteToBlack != 0) ? 14 : (f_slot_13_blackToWhite != 0 || f_slot_13_whiteToBlack != 0) ? 13 :
					(f_slot_12_blackToWhite != 0 || f_slot_12_whiteToBlack != 0) ? 12 : (f_slot_11_blackToWhite != 0 || f_slot_11_whiteToBlack != 0) ? 11 : (f_slot_10_blackToWhite != 0 || f_slot_10_whiteToBlack != 0) ? 10 : 
					(f_slot_9_blackToWhite != 0 || f_slot_9_whiteToBlack != 0) ? 9 : (f_slot_8_blackToWhite != 0 || f_slot_8_whiteToBlack != 0) ? 8 : (f_slot_7_blackToWhite != 0 || f_slot_7_whiteToBlack != 0) ? 7 :
					(f_slot_6_blackToWhite != 0 || f_slot_6_whiteToBlack != 0) ? 6 : (f_slot_5_blackToWhite != 0 || f_slot_5_whiteToBlack != 0) ? 5 : (f_slot_4_blackToWhite != 0 || f_slot_4_whiteToBlack != 0) ? 4 :
					(f_slot_3_blackToWhite != 0 || f_slot_3_whiteToBlack != 0) ? 3 : (f_slot_2_blackToWhite != 0 || f_slot_2_whiteToBlack != 0) ? 2 : 0;
		center_slot = (left_slot + right_slot) >> 1;



		case(left_slot) 

			2:	left_most_bound = (f_slot_2_blackToWhite < f_slot_2_whiteToBlack) ? f_slot_2_blackToWhite : f_slot_2_whiteToBlack;
			3:	left_most_bound = (f_slot_3_blackToWhite <  f_slot_3_whiteToBlack) ? f_slot_3_blackToWhite : f_slot_3_whiteToBlack;
			4:	left_most_bound = (f_slot_4_blackToWhite <  f_slot_4_whiteToBlack) ? f_slot_4_blackToWhite : f_slot_4_whiteToBlack;
			5:	left_most_bound = (f_slot_5_blackToWhite <  f_slot_5_whiteToBlack) ? f_slot_5_blackToWhite : f_slot_5_whiteToBlack;
			6:	left_most_bound = (f_slot_6_blackToWhite <  f_slot_6_whiteToBlack) ? f_slot_6_blackToWhite : f_slot_6_whiteToBlack;
			7:	left_most_bound = (f_slot_7_blackToWhite <  f_slot_7_whiteToBlack) ? f_slot_7_blackToWhite : f_slot_7_whiteToBlack;
			8:	left_most_bound = (f_slot_8_blackToWhite <  f_slot_8_whiteToBlack) ? f_slot_8_blackToWhite : f_slot_8_whiteToBlack;
			9:	left_most_bound = (f_slot_9_blackToWhite <  f_slot_9_whiteToBlack) ? f_slot_9_blackToWhite : f_slot_9_whiteToBlack;
			10:	left_most_bound = (f_slot_10_blackToWhite <  f_slot_10_whiteToBlack) ? f_slot_10_blackToWhite : f_slot_10_whiteToBlack;
			11:	left_most_bound = (f_slot_11_blackToWhite <  f_slot_11_whiteToBlack) ? f_slot_11_blackToWhite : f_slot_11_whiteToBlack;
			12:	left_most_bound = (f_slot_12_blackToWhite <  f_slot_12_whiteToBlack) ? f_slot_12_blackToWhite : f_slot_12_whiteToBlack;
			13:	left_most_bound = (f_slot_13_blackToWhite <  f_slot_13_whiteToBlack) ? f_slot_13_blackToWhite : f_slot_13_whiteToBlack;
			14:	left_most_bound = (f_slot_14_blackToWhite <  f_slot_14_whiteToBlack) ? f_slot_14_blackToWhite : f_slot_14_whiteToBlack;
			15:	left_most_bound = (f_slot_15_blackToWhite <  f_slot_15_whiteToBlack) ? f_slot_15_blackToWhite : f_slot_15_whiteToBlack;

		endcase

		case(right_slot) 

		
			2:	right_most_bound = (f_slot_2_blackToWhite > f_slot_2_whiteToBlack) ? f_slot_2_blackToWhite : f_slot_2_whiteToBlack;
			3:	right_most_bound = (f_slot_3_blackToWhite >  f_slot_3_whiteToBlack) ? f_slot_3_blackToWhite : f_slot_3_whiteToBlack;
			4:	right_most_bound = (f_slot_4_blackToWhite >  f_slot_4_whiteToBlack) ? f_slot_4_blackToWhite : f_slot_4_whiteToBlack;
			5:	right_most_bound = (f_slot_5_blackToWhite >  f_slot_5_whiteToBlack) ? f_slot_5_blackToWhite : f_slot_5_whiteToBlack;
			6:	right_most_bound = (f_slot_6_blackToWhite >  f_slot_6_whiteToBlack) ? f_slot_6_blackToWhite : f_slot_6_whiteToBlack;
			7:	right_most_bound = (f_slot_7_blackToWhite >  f_slot_7_whiteToBlack) ? f_slot_7_blackToWhite : f_slot_7_whiteToBlack;
			8:	right_most_bound = (f_slot_8_blackToWhite >  f_slot_8_whiteToBlack) ? f_slot_8_blackToWhite : f_slot_8_whiteToBlack;
			9:	right_most_bound = (f_slot_9_blackToWhite >  f_slot_9_whiteToBlack) ? f_slot_9_blackToWhite : f_slot_9_whiteToBlack;
			10:	right_most_bound = (f_slot_10_blackToWhite >  f_slot_10_whiteToBlack) ? f_slot_10_blackToWhite : f_slot_10_whiteToBlack;
			11:	right_most_bound = (f_slot_11_blackToWhite >  f_slot_11_whiteToBlack) ? f_slot_11_blackToWhite : f_slot_11_whiteToBlack;
			12:	right_most_bound = (f_slot_12_blackToWhite >  f_slot_12_whiteToBlack) ? f_slot_12_blackToWhite : f_slot_12_whiteToBlack;
			13:	right_most_bound = (f_slot_13_blackToWhite >  f_slot_13_whiteToBlack) ? f_slot_13_blackToWhite : f_slot_13_whiteToBlack;
			14:	right_most_bound = (f_slot_14_blackToWhite >  f_slot_14_whiteToBlack) ? f_slot_14_blackToWhite : f_slot_14_whiteToBlack;
			15:	right_most_bound = (f_slot_15_blackToWhite >  f_slot_15_whiteToBlack) ? f_slot_15_blackToWhite : f_slot_15_whiteToBlack;

		endcase
		
		
 	end

end 

 



//--------------------------------------------------------------------
// Detecting Alien 
//--------------------------------------------------------------------
//Count valid pixels to tget the image coordinates. Reset and detect packet type on Start of Packet.
reg [10:0] x, y;
reg packet_video;
reg [10:0] count_r, count_p, count_g, count_c, count_y, count_blue;
reg[10:0] count_w, count_b;
//count how many pixels in this color between the edge gap

reg [10:0] max_start_edge_x_position_r, max_start_edge_x_position_p, max_start_edge_x_position_g, max_start_edge_x_position_c, max_start_edge_x_position_y, max_start_edge_x_position_blue;
reg [10:0] max_start_edge_x_position_w, max_start_edge_x_position_b;
reg [10:0] max_end_edge_x_position_r, max_end_edge_x_position_p, max_end_edge_x_position_g, max_end_edge_x_position_c, max_end_edge_x_position_y, max_end_edge_x_position_blue;
reg [10:0] max_end_edge_x_position_w, max_end_edge_x_position_b;
// TODO: Refined with better math model
// The trusted region base on the previous X row
reg [10:0] estimatated_region_start_r, estimatated_region_end_r;
reg [10:0] estimatated_region_start_p, estimatated_region_end_p;
reg [10:0] estimatated_region_start_g, estimatated_region_end_g;
reg [10:0] estimatated_region_start_c, estimatated_region_end_c;
reg [10:0] estimatated_region_start_y, estimatated_region_end_y;
reg [10:0] estimatated_region_start_blue, estimatated_region_end_blue;

reg [10:0] estimatated_region_start_b, estimatated_region_end_b;
reg [10:0] estimatated_region_start_w, estimatated_region_end_w;

// The trusted meatrix
reg  [7:0] estimated_val_r, estimated_val_p, estimated_val_w, estimated_val_b, estimated_val_g, estimated_val_c, estimated_val_y, estimated_val_blue;
wire [10:0] mid_deviation_r, mid_deviation_p, mid_deviation_w, mid_deviation_b, mid_deviation_g, mid_deviation_c, mid_deviation_y, mid_deviation_blue;
wire [10:0] difference_r, difference_p, difference_w, difference_b, difference_g, difference_c, difference_y, difference_blue;



assign mid_deviation_r =  ((estimatated_region_end_r + estimatated_region_start_r) > (max_start_edge_x_position_r + max_end_edge_x_position_r)) ? 
							((estimatated_region_end_r + estimatated_region_start_r) - (max_start_edge_x_position_r + max_end_edge_x_position_r))
							: ((max_start_edge_x_position_r + max_end_edge_x_position_r) - ( estimatated_region_end_r + estimatated_region_start_r ));

assign mid_deviation_p =  ((estimatated_region_end_p + estimatated_region_start_p) > (max_start_edge_x_position_p + max_end_edge_x_position_p)) ? 
							((estimatated_region_end_p + estimatated_region_start_p) - (max_start_edge_x_position_p + max_end_edge_x_position_p))
							: ((max_start_edge_x_position_p + max_end_edge_x_position_p) - ( estimatated_region_end_p + estimatated_region_start_p ));

assign mid_deviation_g =  ((estimatated_region_end_g + estimatated_region_start_g) > (max_start_edge_x_position_g + max_end_edge_x_position_g)) ? 
							((estimatated_region_end_g + estimatated_region_start_g) - (max_start_edge_x_position_g + max_end_edge_x_position_g))
							: ((max_start_edge_x_position_g + max_end_edge_x_position_g) - ( estimatated_region_end_g + estimatated_region_start_g ));

assign mid_deviation_c =  ((estimatated_region_end_c + estimatated_region_start_c) > (max_start_edge_x_position_c + max_end_edge_x_position_c)) ? 
							((estimatated_region_end_c + estimatated_region_start_c) - (max_start_edge_x_position_c + max_end_edge_x_position_c))
							: ((max_start_edge_x_position_c + max_end_edge_x_position_c) - ( estimatated_region_end_c + estimatated_region_start_c ));

assign mid_deviation_y =  ((estimatated_region_end_y + estimatated_region_start_y) > (max_start_edge_x_position_y + max_end_edge_x_position_y)) ? 
							((estimatated_region_end_y + estimatated_region_start_y) - (max_start_edge_x_position_y + max_end_edge_x_position_y))
							: ((max_start_edge_x_position_y + max_end_edge_x_position_y) - ( estimatated_region_end_y + estimatated_region_start_y ));

assign mid_deviation_blue =  ((estimatated_region_end_blue + estimatated_region_start_blue) > (max_start_edge_x_position_blue + max_end_edge_x_position_blue)) ? 
							((estimatated_region_end_blue + estimatated_region_start_blue) - (max_start_edge_x_position_blue + max_end_edge_x_position_blue))
							: ((max_start_edge_x_position_blue + max_end_edge_x_position_blue) - ( estimatated_region_end_blue + estimatated_region_start_blue ));

assign mid_deviation_b =  ((estimatated_region_end_b + estimatated_region_start_b) > (max_start_edge_x_position_b + max_end_edge_x_position_b)) ? 
							((estimatated_region_end_b + estimatated_region_start_b) - (max_start_edge_x_position_b + max_end_edge_x_position_b))
							: ((max_start_edge_x_position_b + max_end_edge_x_position_b) - ( estimatated_region_end_b + estimatated_region_start_b ));

assign mid_deviation_w =  ((estimatated_region_end_w + estimatated_region_start_w) > (max_start_edge_x_position_w + max_end_edge_x_position_w)) ? 
							((estimatated_region_end_w + estimatated_region_start_w) - (max_start_edge_x_position_w + max_end_edge_x_position_w))
							: ((max_start_edge_x_position_w + max_end_edge_x_position_w) - ( estimatated_region_end_w + estimatated_region_start_w ));


assign difference_r = max_end_edge_x_position_r - max_start_edge_x_position_r;
assign difference_p = max_end_edge_x_position_p - max_start_edge_x_position_p;
assign difference_g = max_end_edge_x_position_g - max_start_edge_x_position_g;
assign difference_c = max_end_edge_x_position_c - max_start_edge_x_position_c;
assign difference_y = max_end_edge_x_position_y - max_start_edge_x_position_y;
assign difference_blue = max_end_edge_x_position_blue  - max_start_edge_x_position_blue;

assign difference_w = max_end_edge_x_position_w - max_start_edge_x_position_w;
assign difference_b = max_end_edge_x_position_b - max_start_edge_x_position_b;



//-----------------------------------------------------------
// ROW 
//-----------------------------------------------------------
always@(posedge clk) begin
	whiteToBlack_1 <= whiteToBlack;
	blackToWhite_1 <= blackToWhite;
    if (in_valid) begin
		//Cycle through message writer states once started
		if (msg_state != 2'b00) msg_state <= msg_state + 2'b01;
		
		if (eop & in_valid & packet_video) begin  //Ignore non-video packets
		//Latch edges for display overlay on next frame
			
			left_r <= (estimated_val_r > valid_region_threshold) ? x_min_r : IMAGE_W-11'h1;
			right_r <= (estimated_val_r > valid_region_threshold)? x_max_r : 0;

			left_g <=(estimated_val_g > valid_region_threshold) ? x_min_g : IMAGE_W-11'h1;
			right_g <= (estimated_val_g > valid_region_threshold) ? x_max_g : 0;

			left_p <= (estimated_val_p > valid_region_threshold) ? x_min_p : IMAGE_W-11'h1 ;
			right_p <= (estimated_val_p > valid_region_threshold) ? x_max_p : 0;

			left_c <= (estimated_val_c > valid_region_threshold) ? x_min_c : 0;
			right_c <= (estimated_val_c > valid_region_threshold) ? x_max_c : 0;

			left_y <= (estimated_val_y > valid_region_threshold) ? x_min_y : 0;
			right_y <= (estimated_val_y > valid_region_threshold) ? x_max_y : 0;

			left_blue <= (estimated_val_blue > valid_region_threshold) ? x_min_blue : 0;
			right_blue <= (estimated_val_blue > valid_region_threshold) ? x_max_blue : 0;
			
			left_w <= x_min_w;
			right_w <= x_max_w;
            left_b <= x_min_b;
			right_b <= x_max_b;
			//end
			//keep last 4 values

			//red
			left_r_1 <= left_r;
			left_r_2 <= left_r_1;
			left_r_3 <= left_r_2;
			left_r_4 <= left_r_3;

			right_r_1 <= right_r;
			right_r_2 <= right_r_1;
			right_r_3 <= right_r_2;
			right_r_4 <= right_r_3;
			

			// pink
			left_p_1 <= left_p;
			left_p_2 <= left_p_1;
			left_p_3 <= left_p_2;
			left_p_4 <= left_p_3;

			right_p_1 <= right_p;
			right_p_2 <= right_p_1;
			right_p_3 <= right_p_2;
			right_p_4 <= right_p_3;
			
			//white
			left_w_1 <= left_w;
			left_w_2 <= left_w_1;
			left_w_3 <= left_w_2;
			left_w_4 <= left_w_3;

			right_w_1 <= right_w;
			right_w_2 <= right_w_1;
			right_w_3 <= right_w_2;
			right_w_4 <= right_w_3;

			// green
			left_g_1 <= left_g;
			left_g_2 <= left_g_1;
			left_g_3 <= left_g_2;
			left_g_4 <= left_g_3;

			right_g_1 <= right_g;
			right_g_2 <= right_g_1;
			right_g_3 <= right_g_2;
			right_g_4 <= right_g_3;

			// black
			left_b_1 <= left_b;
			left_b_2 <= left_b_1;
			left_b_3 <= left_b_2;
			left_b_4 <= left_b_3;

			right_b_1 <= right_b;
			right_b_2 <= right_b_1;
			right_b_3 <= right_b_2;
			right_b_4 <= right_b_3;

            //cyan
            left_c_1 <= left_c;
			left_c_2 <= left_c_1;
			left_c_3 <= left_c_2;
			left_c_4 <= left_c_3;

			right_c_1 <= right_c;
			right_c_2 <= right_c_1;
			right_c_3 <= right_c_2;
			right_c_4 <= right_c_3;

            //yellow
            left_y_1 <= left_y;
			left_y_2 <= left_y_1;
			left_y_3 <= left_y_2;
			left_y_4 <= left_y_3;

			right_y_1 <= right_y;
			right_y_2 <= right_y_1;
			right_y_3 <= right_y_2;
			right_y_4 <= right_y_3;

            //blue
            left_blue_1 <= left_blue;
			left_blue_2 <= left_blue_1;
			left_blue_3 <= left_blue_2;
			left_blue_4 <= left_blue_3;

			right_blue_1 <= right_blue;
			right_blue_2 <= right_blue_1;
			right_blue_3 <= right_blue_2;
			right_blue_4 <= right_blue_3;
			
			//window for last frame, frame is refreshed every eop
			
			//Start message writer FSM once every MSG_INTERVAL frames, if there is room in the FIFO
			frame_count <= frame_count - 1;
			
			if (frame_count == 0 && msg_buf_size < MESSAGE_BUF_MAX - 3) begin
				msg_state <= 2'b01;
				frame_count <= MSG_INTERVAL-1;
			end
		end

		//parameter MESSAGE_BUF_MAX = 256 parameter MSG_INTERVAL = 6;
		else if (sop & in_valid) begin	//Reset bounds on start of packet
				//red
                x_min_r <= IMAGE_W-11'h1;
				x_max_r <= 0;

                //green
				x_min_g <= IMAGE_W-11'h1;
				x_max_g <= 0;

                //white
				x_min_w <= IMAGE_W-11'h1;
				x_max_w <= 0;

                //pink
				x_min_p <= IMAGE_W-11'h1;
				x_max_p <= 0;

                //black
                x_min_b <= IMAGE_W-11'h1;
				x_max_b <= 0;

                //cyan
                x_min_c <= IMAGE_W-11'h1;
				x_max_c <= 0;

                //yellow
                x_min_y <= IMAGE_W-11'h1;
				x_max_y <= 0;

                //blue
                x_min_blue <= IMAGE_W-11'h1;
				x_max_blue <= 0;

				estimated_val_r <= 0;
				estimated_val_p <= 0;
				estimated_val_w <= 0;
				estimated_val_g <= 0;
				estimated_val_b <= 0;
                estimated_val_c <= 0;
				estimated_val_y <= 0;
				estimated_val_blue <= 0;
                
				count_r <= 0;
				count_p <= 0;
				count_g <= 0;
				count_w <= 0;
				count_b <= 0;
                count_c <= 0;
                count_y <= 0;
                count_blue <= 0;
                max_gap <= 0;
			end
	
	
		else begin					
				if(red_final_detected) 			count_r <= count_r + 1;
				else if (pink_final_detected) 	count_p <= count_p + 1;
				else if (green_final_detected) 	count_g <= count_g + 1;
                else if (cyan_final_detected) 	count_c <= count_c + 1;
				else if (yellow_final_detected) count_y <= count_y + 1;
				else if (blue_final_detected) 	count_blue <= count_blue + 1;
				else if (white_final_detected) count_w <= count_w + 1;
				else if (black_final_detected) 	count_b <= count_b + 1;

				/////////////////////////////////////////////////
				// Row :: locating max_valid_region in a row or counting red..
				/////////////////////////////////////////////////

				//if (red_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2)) begin	//Update bounds when the pixel is red
				if (red_final_detected & in_valid) begin	//Update bounds when the pixel is red
					if (x < max_start_edge_x_position_r) max_start_edge_x_position_r <= x;
					if (x > max_end_edge_x_position_r) max_end_edge_x_position_r <= x;
				end
				//else if (green_detected & green_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2)) begin	//Update bounds when the pixel is red
				else if (green_final_detected & in_valid) begin
					if (x < max_start_edge_x_position_g) max_start_edge_x_position_g <= x;
					if (x > max_end_edge_x_position_g) max_end_edge_x_position_g <= x;
				end
				// else if (pink_detected & pink_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2) & in_valid) begin	//Update bounds when the pixel is red		else if (pink_detected & pink_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2) & in_valid) begin	//Update bounds when the pixel is red
				else if (pink_final_detected & in_valid) begin
					if (x < max_start_edge_x_position_p) max_start_edge_x_position_p <= x;
					if (x > max_end_edge_x_position_p) max_end_edge_x_position_p <= x;
				end	
				// else if (white_detected & white_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2) & in_valid) begin	//Update bounds when the pixel is red
				// else if (white_final_detected & in_valid ) begin	//Update bounds when the pixel is red
				// 	if (x < max_start_edge_x_position_w) max_start_edge_x_position_w <= x;
				// 	if (x > max_end_edge_x_position_w) max_end_edge_x_position_w <= x;	
				// end
                else if (cyan_final_detected & in_valid ) begin
					if (x < max_start_edge_x_position_c) max_start_edge_x_position_c <= x;
					if (x > max_end_edge_x_position_c) max_end_edge_x_position_c <= x;
				end
                else if (yellow_final_detected & in_valid ) begin
					if (x < max_start_edge_x_position_y) max_start_edge_x_position_y <= x;
					if (x > max_end_edge_x_position_y) max_end_edge_x_position_y <= x;
				end
				else if (blue_final_detected & in_valid ) begin
					if (x < max_start_edge_x_position_blue) max_start_edge_x_position_blue <= x;
					if (x > max_end_edge_x_position_blue) max_end_edge_x_position_blue <= x;
				end

			
		end
	end
//-----------------------------------------------------------
// Column 
//-----------------------------------------------------------
	if (x == IMAGE_W-1) begin
		//if(y > 300) begin
			count_r <= 0;
			count_p <= 0;
			count_g <= 0;
			//count_w <= 0;
			//count_b <= 0;	
			count_c <= 0;
			count_y <= 0;
			count_blue <= 0;

			max_start_edge_x_position_r <=  IMAGE_W-11'h1;
			max_end_edge_x_position_r <= 0;
			max_start_edge_x_position_p <=  IMAGE_W-11'h1;
			max_end_edge_x_position_p <= 0;
			// max_start_edge_x_position_w <=  IMAGE_W-11'h1;
			// max_end_edge_x_position_w <= 0;
			max_start_edge_x_position_g <=  IMAGE_W-11'h1;
			max_end_edge_x_position_g <= 0;
			max_start_edge_x_position_c <=  IMAGE_W-11'h1;
			max_end_edge_x_position_c <= 0;
			max_start_edge_x_position_y <=  IMAGE_W-11'h1;
			max_end_edge_x_position_y <= 0;
			// max_start_edge_x_position_b <=  IMAGE_W-11'h1;
			// max_end_edge_x_position_b <= 0;
			max_start_edge_x_position_blue <=  IMAGE_W-11'h1;
			max_end_edge_x_position_blue <= 0;
			

			// when the estimation is not valid
			//Red
			if(count_r > count_threshold )begin
				if(estimated_val_r == 0) begin
					estimatated_region_start_r <= max_start_edge_x_position_r;
					estimatated_region_end_r <= max_end_edge_x_position_r;
					// error choice, reset.
					x_min_r <= IMAGE_W-11'h1;
					x_max_r <= 0;
					estimated_val_r <= 1;
				end

				else begin
					if(mid_deviation_r > horizontal_edge_region_threshold)begin
						estimated_val_r <= estimated_val_r - 1;
					end
					else begin
						//discuss difference
						if(difference_r < difference_threshold )begin
							//valid row
							estimated_val_r <= estimated_val_r + 1;
							// choose the x region
							if(x_min_r > max_start_edge_x_position_r) begin
								x_min_r <= max_start_edge_x_position_r;
							end
							if(x_max_r < max_end_edge_x_position_r) begin
								x_max_r <= max_end_edge_x_position_r;
							end
						end
					end
						//else do nothing
				end
			end

			//Pink
			if(count_p > count_threshold) begin
				if(estimated_val_p == 0)begin
					estimatated_region_start_p <= max_start_edge_x_position_p;
					estimatated_region_end_p <= max_end_edge_x_position_p;
					//reset
					x_min_p <= IMAGE_W-11'h1;
					x_max_p <= 0;
					estimated_val_p <= 1;
				end
				else begin
					if(mid_deviation_p > horizontal_edge_region_threshold)begin
						estimated_val_p <= estimated_val_p - 1;
					end
					else begin
						if(difference_p < difference_threshold )begin
							estimated_val_p <= estimated_val_p + 1;
							if(x_min_p > max_start_edge_x_position_p) begin
								x_min_p <= max_start_edge_x_position_p;
							end
							if(x_max_p < max_end_edge_x_position_p) begin
								x_max_p <= max_end_edge_x_position_p;
							end
						end
					end
				end
			end
		
			//Green
			if(count_g > count_threshold) begin
				if(estimated_val_g == 0)begin
					estimatated_region_start_g <= max_start_edge_x_position_g;
					estimatated_region_end_g <= max_end_edge_x_position_g;
					//reset
					x_min_g <= IMAGE_W-11'h1;
					x_max_g <= 0;
					estimated_val_g <= 1;

				end
				else begin
						if(mid_deviation_g > horizontal_edge_region_threshold)begin
							estimated_val_g <= estimated_val_g - 1;
						end
						else begin
							if(difference_g < difference_threshold )begin
								estimated_val_g <= estimated_val_g + 1;
								if(x_min_g > max_start_edge_x_position_g) begin
									x_min_g <= max_start_edge_x_position_g;
								end
								if(x_max_g < max_end_edge_x_position_g) begin
									x_max_g <= max_end_edge_x_position_g;
								end
							end
						end
				end
			end

			//cyan
			if(count_c > count_threshold) begin
				if(estimated_val_c == 0)begin
					estimatated_region_start_c <= max_start_edge_x_position_c;
					estimatated_region_end_c <= max_end_edge_x_position_c;
					//reset
					x_min_c <= IMAGE_W-11'h1;
					x_max_c <= 0;
					estimated_val_c <= 1;
				end
				else begin
					if(mid_deviation_c > horizontal_edge_region_threshold)begin
						estimated_val_c <= estimated_val_c - 1;
					end
					else begin
						if(difference_c < difference_threshold )begin
							estimated_val_c <= estimated_val_c + 1;
							if(x_min_c > max_start_edge_x_position_c) begin
								x_min_c <= max_start_edge_x_position_c;
							end
							if(x_max_c < max_end_edge_x_position_c) begin
								x_max_c <= max_end_edge_x_position_c;
							end
						end
					end
				end
			end

			// yellow
			if(count_y > count_threshold )begin
				if(estimated_val_y == 0) begin
					estimatated_region_start_y <= max_start_edge_x_position_y;
					estimatated_region_end_y <= max_end_edge_x_position_y;
					// error choice, reset.
					x_min_y <= IMAGE_W-11'h1;
					x_max_y <= 0;
					estimated_val_y <= 1;
				end

				else begin
					if(mid_deviation_y > horizontal_edge_region_threshold)begin
						estimated_val_y <= estimated_val_y - 1;
					end
					else begin
						//discuss difference
						if(difference_y < difference_threshold )begin
							//valid row
							estimated_val_y <= estimated_val_y + 1;
							// choose the x region
							if(x_min_y > max_start_edge_x_position_y) begin
								x_min_y <= max_start_edge_x_position_y;
							end
							if(x_max_y < max_end_edge_x_position_y) begin
								x_max_y <= max_end_edge_x_position_y;
							end
						end
					end
					//else do nothing
				end
			end
			//blue
			if(count_blue > count_threshold )begin
				if(estimated_val_blue == 0) begin
					estimatated_region_start_blue <= max_start_edge_x_position_blue;
					estimatated_region_end_blue <= max_end_edge_x_position_blue;
					// error choice, reset.
					x_min_blue <= IMAGE_W-11'h1;
					x_max_blue <= 0;
					estimated_val_blue <= 1;
				end

				else begin
					if(mid_deviation_blue > horizontal_edge_region_threshold)begin
						estimated_val_blue <= estimated_val_blue - 1;
					end
					else begin
						//discuss difference
						if(difference_blue < difference_threshold )begin
							//valid row
							estimated_val_blue <= estimated_val_blue + 1;
							// choose the x region
							if(x_min_blue > max_start_edge_x_position_blue) begin
								x_min_blue <= max_start_edge_x_position_blue;
							end
							if(x_max_blue < max_end_edge_x_position_blue) begin
								x_max_blue <= max_end_edge_x_position_blue;
							end
						end
					end
					//else do nothing
				end
			end
	end
end
		

// end of frame refresh
always@(posedge clk) begin
	if (sop) begin
		x <= 11'h0;
		y <= 11'h0;
		packet_video <= (blue[3:0] == 3'h0);
	end
	else if (in_valid) begin
		if (x == IMAGE_W-1) begin
			x <= 11'h0;
			y <= y + 11'h1;
		end
		else begin
			x <= x + 11'h1;
		end
	end
end

// x,y represent position of a single pixel. Every clk 1 new pixel coming in.

//Find first and last red pixels
reg [10:0] x_min, x_max;
reg [10:0] x_min_r, x_min_p, x_min_g, x_min_w, x_min_b, x_min_c, x_min_y, x_min_blue;
reg [10:0] x_max_r, x_max_p, x_max_g, x_max_w, x_max_b, x_max_c, x_max_y, x_max_blue;

//Process bounding box at the end of the frame.
reg [1:0] msg_state;
reg [7:0] frame_count;
//red
reg [10:0] left_r_1, left_r_2, left_r_3, left_r_4;
reg [10:0] right_r_1, right_r_2, right_r_3, right_r_4;
//pink
reg [10:0] left_p_1, left_p_2, left_p_3, left_p_4;
reg [10:0] right_p_1, right_p_2, right_p_3, right_p_4;
//white
reg [10:0] left_w_1, left_w_2, left_w_3, left_w_4;
reg [10:0] right_w_1, right_w_2, right_w_3, right_w_4;
//green
reg [10:0] left_g_1, left_g_2, left_g_3, left_g_4;
reg [10:0] right_g_1, right_g_2, right_g_3, right_g_4;
//black
reg [10:0] left_b_1, left_b_2, left_b_3, left_b_4;
reg [10:0] right_b_1, right_b_2, right_b_3, right_b_4;
// Yellow
reg [10:0] left_y_1, left_y_2, left_y_3, left_y_4;
reg [10:0] right_y_1, right_y_2, right_y_3, right_y_4;
// cy
reg [10:0] left_c_1, left_c_2, left_c_3, left_c_4;
reg [10:0] right_c_1, right_c_2, right_c_3, right_c_4;
// blue
reg [10:0] left_blue_1, left_blue_2, left_blue_3, left_blue_4;
reg [10:0] right_blue_1, right_blue_2, right_blue_3, right_blue_4;

wire [10:0] avg_left_r, avg_right_r;
wire [10:0] avg_left_p, avg_right_p;
wire [10:0] avg_left_w, avg_right_w;
wire [10:0] avg_left_g, avg_right_g;
wire [10:0] avg_left_b, avg_right_b;
wire [10:0] avg_left_c, avg_right_c;
wire [10:0] avg_left_y, avg_right_y;
wire [10:0] avg_left_blue, avg_right_blue;


assign avg_left_r = (left_r + left_r_1 + left_r_2 + left_r_3 + left_r_4) / 5;
assign avg_right_r = (right_r + right_r_1 + right_r_2 + right_r_3 + left_r_4) / 5;

assign avg_left_p = (left_p + left_p_1 + left_p_2 + left_p_3 + left_p_4) / 5;
assign avg_right_p = (right_p + right_p_1 + right_p_2 + right_p_3 + left_p_4) / 5;

assign avg_left_w = (left_w + left_w_1 + left_w_2 + left_w_3 + left_w_4) / 5;
assign avg_right_w = (right_w + right_w_1 + right_w_2 + right_w_3 + left_w_4) / 5;

assign avg_left_g = (left_g + left_g_1 + left_g_2 + left_g_3 + left_g_4) / 5;
assign avg_right_g = (right_g + right_g_1 + right_g_2 + right_g_3 + left_g_4) / 5;

assign avg_left_b = (left_b + left_b_1 + left_b_2 + left_b_3 + left_b_4) / 5;
assign avg_right_b = (right_b + right_b_1 + right_b_2 + right_b_3 + left_b_4) / 5;
//yellow
assign avg_left_y = (left_y + left_y_1 + left_y_2 + left_y_3 + left_y_4) / 5;
assign avg_right_y = (right_y + right_y_1 + right_y_2 + right_y_3 + left_y_4) / 5;
//cy
assign avg_left_c = (left_c + left_c_1 + left_c_2 + left_c_3 + left_c_4) / 5;
assign avg_right_c = (right_c + right_c_1 + right_c_2 + right_c_3 + left_c_4) / 5;
//blue
assign avg_left_blue = (left_blue + left_blue_1 + left_blue_2 + left_blue_3 + left_blue_4) / 5;
assign avg_right_blue = (right_blue + right_blue_1 + right_blue_2 + right_blue_3 + left_blue_4) / 5;
	
	
reg [31:0] msg_buf_in;  
wire [31:0] msg_buf_out;
reg msg_buf_wr;
wire msg_buf_rd, msg_buf_flush;
wire [7:0] msg_buf_size;
wire msg_buf_empty;
//for testing only
reg [1:0] slot_7_WB, slot_8_WB, slot_9_WB, slot_10_WB;
reg [10:0] slot_7, slot_8, slot_9, slot_10;

`define RED_BOX_MSG_ID "RBB"

always@(*) begin	//Write words to FIFO as state machine advances
	case(msg_state)
		2'b00: begin
			msg_buf_in = 32'b0;
			msg_buf_wr = 1'b0;
		end
		2'b01: begin
			//msg_buf_in = 
			msg_buf_in = {24'b0, hue};
			//`RED_BOX_MSG_ID;	//Message ID
			msg_buf_wr = 1'b1;
		end
		2'b10: begin
			//msg_buf_in = {5'b0, x_min, 5'b0, y_min};	//Top left coordinate
			msg_buf_in = {22'h0,hue}; 
			msg_buf_wr = 1'b1;
		end
		2'b11: begin
			msg_buf_in = {32'h0}; //Bottom right coordinate
			msg_buf_wr = 1'b1;
		end
	endcase
end

//Output message FIFO
MSG_FIFO	MSG_FIFO_inst (
	.clock (clk),
	.data (msg_buf_in),
	.rdreq (msg_buf_rd),
	.sclr (~reset_n | msg_buf_flush),
	.wrreq (msg_buf_wr),
	.q (msg_buf_out),
	.usedw (msg_buf_size),
	.empty (msg_buf_empty)
	);


//Streaming registers to buffer video signal
STREAM_REG #(.DATA_WIDTH(26)) in_reg (
	.clk(clk),
	.rst_n(reset_n),
	.ready_out(sink_ready),
	.valid_out(in_valid),
	.data_out({red,green,blue,sop,eop}),
	.ready_in(out_ready),
	.valid_in(sink_valid),
	.data_in({sink_data,sink_sop,sink_eop})
);

STREAM_REG #(.DATA_WIDTH(26)) out_reg (
	.clk(clk),
	.rst_n(reset_n),
	.ready_out(out_ready),
	.valid_out(source_valid),
	.data_out({source_data,source_sop,source_eop}),
	.ready_in(source_ready),
	.valid_in(in_valid),
	.data_in({red_out, green_out, blue_out, sop, eop})
);

/////////////////////////////////
/// Memory-mapped port		 /////
/////////////////////////////////

// Addresses
`define REG_STATUS    			    0
`define READ_MSG    				1
`define READ_ID    				    2
`define REG_BBCOL					3


reg [7:0]   reg_status;
reg	[23:0]	bb_col;

always @ (posedge clk) begin
	if (~reset_n)
	begin
		reg_status <= 8'b0;
		bb_col <= BB_COL_DEFAULT;
	end
	else begin
		if(s_chipselect & s_write) begin
		   if      (s_address == `REG_STATUS)	reg_status <= s_writedata[7:0];
		   if      (s_address == `REG_BBCOL)	bb_col <= s_writedata[23:0];
		end
	end
end

//Flush the message buffer if 1 is written to status register bit 4
assign msg_buf_flush = (s_chipselect & s_write & (s_address == `REG_STATUS) & s_writedata[4]);

//Process reads
reg read_d; //Store the read signal for correct updating of the message buffer

//Copy the requested word to the output port when there is a read.
always @ (posedge clk) begin
   if (~reset_n) begin
	   s_readdata <= {32'b0};
		read_d <= 1'b0;
	end
	
	else if (s_chipselect & s_read) begin
		if   (s_address == `REG_STATUS) s_readdata <= {16'b0,msg_buf_size,reg_status};
		if   (s_address == `READ_MSG) s_readdata <= {msg_buf_out};
		if   (s_address == `READ_ID) s_readdata <= 32'h1234EEE2;
		if   (s_address == `REG_BBCOL) s_readdata <= {8'h0, bb_col};
	end
	
	read_d <= s_read;
end

//Fetch next word from message buffer after read from READ_MSG
assign msg_buf_rd = s_chipselect & s_read & ~read_d & ~msg_buf_empty & (s_address == `READ_MSG);
////////////////////////////////////////////////////////////////////
// SPI Transimitioin
////////////////////////////////////////////////////////////////////
// data formate 
// colour + coordinate  = {0'b0, colour(3 bits), 12 bits for x_coordinate}
// colour + distance    = {0'b1, colour(3 bits), 12 bits for distance    }
wire formate_r, formate_p, formate_g, formate_w, formate_b, formate_c, formate_y, formate_blue ;
reg [11:0] distance_r_t, distance_p_t, distance_g_t, distance_w_t, distance_c_t, distance_y_t, distance_blue_t, distance_b_t;
reg [11:0] tower_diameter_t;
reg [10:0] distance_r, distance_p, distance_g, distance_w, distance_b, distance_c, distance_y, distance_blue;
reg [10:0] tower_diameter;
reg valid_r, valid_p, valid_g, valid_w, valid_b, valid_c, valid_y, valid_blue;
reg valid_r_1, valid_p_1, valid_g_1, valid_w_1, valid_b_1, valid_y_1, valid_c_1, valid_blue_1;
reg valid_r_2, valid_p_2, valid_g_2, valid_w_2, valid_b_2, valid_y_2, valid_c_2, valid_blue_2;
reg valid_r_3, valid_p_3, valid_g_3, valid_w_3, valid_b_3, valid_y_3, valid_c_3, valid_blue_3;
wire [10:0] red_center_x_pixel, pink_center_x_pixel, green_center_x_pixel, white_center_x_pixel, black_center_x_pixel, blue_center_x_pixel, yellow_center_x_pixel, cyan_center_x_pixel;

// take last 11 of distance 12
always@(*)begin
	distance_r = distance_r_t[10:0];
	distance_p = distance_p_t[10:0];
	distance_g = distance_g_t[10:0];
	distance_w = distance_w_t[10:0];
	distance_c = distance_c_t[10:0];
	distance_y = distance_y_t[10:0];
	distance_b = distance_b_t[10:0];
	distance_blue = distance_blue_t[10:0];
	tower_diameter = tower_diameter_t[10:0];

end
reg [10:0] stripe_width;

buildiing_distance_cal black_building(
	.clk(clk),
	.center_slot(center_slot),
    .f_slot_7_blackToWhite(f_slot_7_blackToWhite),
    .f_slot_8_blackToWhite(f_slot_8_blackToWhite),
    .f_slot_9_blackToWhite(f_slot_9_blackToWhite),
    .f_slot_10_blackToWhite(f_slot_10_blackToWhite),

	.f_slot_7_whiteToBlack(f_slot_7_whiteToBlack),
    .f_slot_8_whiteToBlack(f_slot_8_whiteToBlack),
    .f_slot_9_whiteToBlack(f_slot_9_whiteToBlack),
    .f_slot_10_whiteToBlack(f_slot_10_whiteToBlack),

	.left_most_bound(left_most_bound),
	.right_most_bound(right_most_bound),
	
    .eop(eop),
    .valid(valid_b),
    .formate(formate_b),
    .target_center_x_pixel(black_center_x_pixel),
    .distance(distance_b_t),

	.slot_7(slot_7),
    .slot_8(slot_8),
   	.slot_9(slot_9),
   	.slot_10(slot_10),
	.left_slot(left_slot),
	.right_slot(right_slot),

    .slot_7_WB(slot_7_WB),
    .slot_8_WB(slot_8_WB),
    .slot_9_WB(slot_9_WB),
    .slot_10_WB(slot_10_WB),

	.stripe_width(stripe_width),
	.diameter(tower_diameter_t)
);


distance_cal red_ball( 
	.left_bound(avg_left_r), 
	.right_bound(avg_right_r),
	.eop(eop),
	.valid(valid_r),
    .formate(formate_r), 
	.target_center_x_pixel(red_center_x_pixel),
	.distance(distance_r_t) 
);
distance_cal pink_ball( 
	.left_bound(avg_left_p),
	.right_bound(avg_right_p),
	.eop(eop),
	.valid(valid_p),
	.formate(formate_p), 
	.target_center_x_pixel(pink_center_x_pixel),
	.distance(distance_p_t) 
);
distance_cal green_ball(
    .left_bound(avg_left_g),
    .right_bound(avg_right_g),
	.eop(eop),
	.valid(valid_g),
    .formate(formate_g),
    .target_center_x_pixel(green_center_x_pixel),
	.distance(distance_g_t) 
);
distance_cal white_ball(
    .left_bound(avg_left_w),
    .right_bound(avg_right_w),
	.eop(eop),
	.valid(valid_w),
    .formate(formate_w),
    .target_center_x_pixel(white_center_x_pixel),
	.distance(distance_w_t) 
);
distance_cal cyan_ball(
    .left_bound(avg_left_c),
    .right_bound(avg_right_c),
	.eop(eop),
	.valid(valid_c),
    .formate(formate_c),
    .target_center_x_pixel(cyan_center_x_pixel),
	.distance(distance_c_t) 
);
distance_cal yellow_ball(
    .left_bound(avg_left_y),
    .right_bound(avg_right_y),
	.eop(eop),
	.valid(valid_y),
    .formate(formate_y),
    .target_center_x_pixel(yellow_center_x_pixel),
	.distance(distance_y_t) 
);
distance_cal blue_ball(
    .left_bound(avg_left_blue),
    .right_bound(avg_right_blue),
	.eop(eop),
	.valid(valid_blue),
    .formate(formate_blue),
    .target_center_x_pixel(blue_center_x_pixel),
	.distance(distance_blue_t) 
);

wire [10:0] c_1, c_2, c_3, c_4, c_5, c_6, c_7, c_8;
reg selected_r, selected_p, selected_w, selected_b, selected_g, selected_c, selected_y, selected_blue;
reg [3:0] data_colour; 
reg moving_forward_r, moving_forward_p, moving_forward_g, moving_forward_w, moving_forward_b, moving_forward_c, moving_forward_y, moving_forward_blue;
reg detection_request;
// reg [15:0] message_to_ESP32;ss

// minmum distance;
assign c_1 = (valid_r && ~selected_r)? distance_r : 11'b111111111111;
assign c_2 = (0 && distance_p < c_1 && ~selected_p) ? distance_p : c_1;
assign c_3 = (valid_g && distance_g < c_2 && ~selected_g) ? distance_g : c_2;
assign c_4 = (valid_w && distance_w < c_3 && ~selected_w) ? distance_w : c_3;
assign c_5 = (valid_b && distance_b < c_4 && ~selected_b) ? distance_b : c_4;
assign c_6 = (valid_y && distance_y < c_5 && ~selected_y) ? distance_y : c_5;
assign c_7 = (valid_c && distance_c < c_6 && ~selected_c) ? distance_c : c_6;
assign c_8 = (valid_blue && distance_blue < c_7 && ~selected_blue) ? distance_blue : c_7;

// delay valid
always @(posedge clk) begin
	if(eop) begin
		valid_r_1 <= valid_r;
		valid_r_2 <= valid_r_1;
		valid_r_3 <= valid_r_2;

		valid_p_1 <= valid_p;
		valid_p_2 <= valid_p_1;
		valid_p_3 <= valid_p_2;

		valid_w_1 <= valid_w;
		valid_w_2 <= valid_w_1;
		valid_w_3 <= valid_w_2;
		
		valid_g_1 <= valid_g;
		valid_g_2 <= valid_g_1;
		valid_g_3 <= valid_g_2;
		
		valid_b_1 <= valid_b;
		valid_b_2 <= valid_b_1;
		valid_b_3 <= valid_b_2;
        
        valid_c_1 <= valid_c;
		valid_c_2 <= valid_c_1;
		valid_c_3 <= valid_c_2;
        
        valid_y_1 <= valid_y;
		valid_y_2 <= valid_y_1;
		valid_y_3 <= valid_y_2;

        valid_blue_1 <= valid_blue;
		valid_blue_2 <= valid_blue_1;
		valid_blue_3 <= valid_blue_2;
	end
end
//select and moving forward
always @(posedge clk) begin
	//esp32 has successfully received red distance. red is now in the selected set

	// unlock the target and block the target.
	if(message_from_ESP32 == 50) begin
		moving_forward_r <= 1;
		moving_forward_p <= 1;
		moving_forward_g <= 1;
		moving_forward_w <= 1;
		moving_forward_b <= 1;
        moving_forward_y <= 1;
        moving_forward_c <= 1;
        moving_forward_blue <= 1;
		detection_request <= 0;
	end
	// 1 moving forward

	//if(message_from_ESP32 == 21) moving_forward_wr_rotate <= 0;
	// 0 rotate 
	
	else if(message_from_ESP32 == 30) begin
		selected_r <= 1;
	end 
	else if(message_from_ESP32 == 31) begin
		selected_p <= 1;
	end 
	else if(message_from_ESP32 == 32) begin
		selected_g <= 1;
	end 
	else if(message_from_ESP32 == 33) begin
		selected_w <= 1;
	end 
	else if(message_from_ESP32 == 34) begin
		selected_b <= 1;
	end 
    else if(message_from_ESP32 == 35) begin
		selected_y <= 1;
	end 
    else if(message_from_ESP32 == 36) begin
		selected_c <= 1;
	end 
    else if(message_from_ESP32 == 37) begin
		selected_blue <= 1;
	end 
	else if(message_from_ESP32 == 70)begin
			selected_r <= 0;
			selected_p <= 0;
			selected_w <= 0;
			selected_g <= 0;
			selected_b <= 0;
            selected_y <= 0;
            selected_c <= 0;
            selected_blue <= 0;
			moving_forward_r <= 0;
			moving_forward_p <= 0;
			moving_forward_w <= 0;
			moving_forward_g <= 0;
			moving_forward_b <= 0;
            moving_forward_c <= 0;
            moving_forward_y <= 0;
            moving_forward_blue <= 0;

			//1507 data colour
			//1535 for lock
	end 
	else if(message_from_ESP32 == 100) begin
		detection_request <= 1;	
	end
	else begin
		if(~valid_r && ~valid_r_1 && ~valid_r_2 && ~valid_r_3 && moving_forward_r)begin 
			selected_r <= 0; 
			moving_forward_r <= 0;
		end
		if(~valid_p && ~valid_p_1 && ~valid_p_2 && ~valid_p_3 && moving_forward_p) begin 
			selected_p <= 0; 
			moving_forward_p <= 0;
		end  
		if(~valid_g && ~valid_g_1 && ~valid_g_2 && ~valid_g_3 && moving_forward_g) begin
			selected_g <= 0;
			moving_forward_g <=0;
		end
		if(~valid_w && ~valid_w_1 && ~valid_w_2 && ~valid_w_3 && moving_forward_w) begin 
			selected_w <= 0; 
			moving_forward_w <= 0;
		end 
		if(~valid_b && ~valid_b_1 && ~valid_b_2 && ~valid_b_3 && moving_forward_b) begin 
			selected_b <= 0; 
			moving_forward_b <= 0;
		end

        if(~valid_y && ~valid_y_1 && ~valid_y_2 && ~valid_y_3 && moving_forward_y)begin 
			selected_y <= 0; 
			moving_forward_y <= 0;
		end
        if(~valid_r && ~valid_c_1 && ~valid_c_2 && ~valid_c_3 && moving_forward_c)begin 
			selected_c <= 0; 
			moving_forward_c <= 0;
		end
        if(~valid_blue && ~valid_blue_1 && ~valid_blue_2 && ~valid_blue_3 && moving_forward_blue)begin 
			selected_blue <= 0; 
			moving_forward_blue <= 0;
		end
	end
	
end

//data_color
always @(posedge clk)begin
	if(message_from_ESP32 == 70) begin
		data_colour <=  4'b1111;
	end
	else begin
        // TODO::NOT enough bits
		data_colour <=  (lock_r) ? 4'b000: 
						(lock_p) ? 4'b001: 
						(lock_g) ? 4'b010: 
						(lock_w) ? 4'b011: 
						(lock_b) ? 4'b100: 
                        (lock_y) ? 4'b101:
                        (lock_c) ? 4'b110:
                        (lock_blue) ? 4'b111:
						(c_8 == distance_r && valid_r) ? 4'b000 :
						(c_8 == distance_p && valid_p) ? 4'b001 :
						(c_8 == distance_g && valid_g) ? 4'b010 :
						(c_8 == distance_w && valid_w) ? 4'b011 :
                        (c_8 == distance_b && valid_b) ? 4'b100 :
                        (c_8 == distance_y && valid_y) ? 4'b101 :
                        (c_8 == distance_c && valid_c) ? 4'b110 :
						(c_8 == distance_b && valid_blue) ? 4'b111 : 4'b1111;	
	end				 
end

always @(*) begin
	if(message_from_ESP32 == 10) begin
		//0
		message_to_ESP32 = {1'b0, 3'b100, 4'b0, slot_7_WB, slot_8_WB, slot_9_WB, slot_10_WB}; end 
	else if(message_from_ESP32 == 11)begin
		//1
		//message_to_ESP32 = {1'b0, 3'b001, 1'b0, y}; end
		//message_to_ESP32 = {1'b0, 3'b001, 4'b0 ,valid_r, valid_p, valid_g, valid_w, valid_b, valid_y, valid_c, valid_blue}; end 
		message_to_ESP32 = {1'b0, 5'b001, count_b_w,count_w_b}; end 
	else if(message_from_ESP32 == 12) begin
		//2
		message_to_ESP32 = {1'b0, 3'b010, 4'b0, selected_r, selected_p, selected_g, selected_w, selected_b, selected_y, selected_c, selected_blue}; end 	
	else if(message_from_ESP32 == 13) begin
		//3
		//message_to_ESP32 = {1'b0, 3'b100, 4'b0, moving_forward_r, moving_forward_p, moving_forward_g, moving_forward_w, moving_forward_b, moving_forward_y, moving_forward_c, moving_forward_blue};
		message_to_ESP32 = {1'b0, 3'b000, 1'b0, distance_g}; end
	else if(message_from_ESP32 == 14) begin
		//4
		message_to_ESP32 = {1'b0, 3'b001, 1'b0, avg_left_g}; end
	else if(message_from_ESP32 == 15) begin
		//5
		//message_to_ESP32 = {1'b0, data_colour, stripe_width}; end
		message_to_ESP32 = {1'b0, 3'b010, 1'b0, avg_right_g}; end
	else if(message_from_ESP32 == 16) begin
		//6
		//message_to_ESP32 = {1'b0, left_slot, right_slot, center_slot }; end
		message_to_ESP32 = {1'b0, 3'b100, 1'b0 , green_center_x_pixel}; end
		//black_center_x_pixel
	else if(message_from_ESP32 == 17) begin
		case(data_colour)
			0 : message_to_ESP32 = (formate_r)? {1'b0, data_colour, distance_r}: {1'b1, data_colour, red_center_x_pixel};	 
			//1 : message_to_ESP32 = (formate_p)? {1'b0, data_colour, distance_p}: {1'b1, data_colour, pink_center_x_pixel};
			2 : message_to_ESP32 = (formate_g)? {1'b0, data_colour, distance_g}: {1'b1, data_colour, green_center_x_pixel};
			3 : message_to_ESP32 = (formate_w)? {1'b0, data_colour, distance_w}: {1'b1, data_colour, white_center_x_pixel};
			4 : message_to_ESP32 = (formate_b)? {1'b0, data_colour, distance_b}: {1'b1, data_colour, black_center_x_pixel};
            5 : message_to_ESP32 = (formate_y)? {1'b0, data_colour, distance_y}: {1'b1, data_colour, yellow_center_x_pixel};
            6 : message_to_ESP32 = (formate_c)? {1'b0, data_colour, distance_c}: {1'b1, data_colour, cyan_center_x_pixel};
            7 : message_to_ESP32 = (formate_blue)? {1'b0, data_colour, distance_blue}: {1'b1, data_colour, blue_center_x_pixel};
			15 : message_to_ESP32 = 16'b1111111111111111;
			default : message_to_ESP32 = 16'b1111111111111111;
		endcase 
	end
	else if(message_from_ESP32 == 18) begin
		message_to_ESP32 = {1'b0, 4'b0, tower_diameter};
	end
	else if (message_from_ESP32 == 70) begin
 		if(~selected_w  && ~selected_r && ~selected_p && ~selected_g && ~selected_b && ~selected_blue && ~selected_y && ~selected_c) begin
			message_to_ESP32 = 16'd60;
		 end else begin
			message_to_ESP32 = 16'd70;
		 end
	end 
	
	else begin
		 // TODO:: not enough bits
		case(data_colour)
			0 : message_to_ESP32 = (formate_r)? {1'b0, data_colour, distance_r}: {1'b1, data_colour, red_center_x_pixel};	 
			//1 : message_to_ESP32 = (formate_p)? {1'b0, data_colour, distance_p}: {1'b1, data_colour, pink_center_x_pixel};
			2 : message_to_ESP32 = (formate_g)? {1'b0, data_colour, distance_g}: {1'b1, data_colour, green_center_x_pixel};
			3 : message_to_ESP32 = (formate_w)? {1'b0, data_colour, distance_w}: {1'b1, data_colour, white_center_x_pixel};
			4 : message_to_ESP32 = (formate_b)? {1'b0, data_colour, distance_b}: {1'b1, data_colour, black_center_x_pixel};
            5 : message_to_ESP32 = (formate_y)? {1'b0, data_colour, distance_y}: {1'b1, data_colour, yellow_center_x_pixel};
            6 : message_to_ESP32 = (formate_c)? {1'b0, data_colour, distance_c}: {1'b1, data_colour, cyan_center_x_pixel};
            7 : message_to_ESP32 = (formate_blue)? {1'b0, data_colour, distance_blue}: {1'b1, data_colour, blue_center_x_pixel};
			15 : message_to_ESP32 = 16'b1111111111111111;
			default : message_to_ESP32 = 16'b1111111111111111;
		endcase 
	end
	//message_to_ESP32 = {distance_r, data_colour, valid_r,valid_b,valid_g,valid_p,valid_r, c_5};
end

reg lock_r, lock_p, lock_w, lock_g, lock_b, lock_c, lock_y, lock_blue;
always @(posedge clk) begin
	if(message_from_ESP32 == 70) begin
		lock_r <= 0;
		lock_p <= 0;
		lock_w <= 0;
		lock_g <= 0;
		lock_b <= 0;
        lock_c <= 0;
        lock_y <= 0;
        lock_blue <= 0;
	end 
	else begin
		case(data_colour)
			0 : begin
					if(selected_r)begin
						lock_r <= 0;
					end 
					else if(formate_r && detection_request) begin
						lock_r <=1;
					end
				end
			1 : begin
					if(selected_p)begin
						lock_p <= 0;
					end 
					else if(formate_p && detection_request) begin
						lock_p <=1;
					end
				end
			2 : begin
					if(selected_g)begin
						lock_g <= 0;
					end 
					else if(formate_g && detection_request) begin
						lock_g <=1;
					end
				end
			3 : begin
					if(selected_w)begin
						lock_w <= 0;
					end 
					else if(formate_w && detection_request) begin
						lock_w <=1;
					end
				end
			4 : begin
					if(selected_b)begin
						lock_b <= 0;
					end 
					else if(formate_b && detection_request) begin
						lock_b <=1;
					end
				end
            5 : begin
					if(selected_y)begin
						lock_y <= 0;
					end 
					else if(formate_y && detection_request) begin
						lock_y <=1;
					end
				end
            6 : begin
					if(selected_c)begin
						lock_c <= 0;
					end 
					else if(formate_c && detection_request) begin
						lock_c <=1;
					end
				end
            7 : begin
					if(selected_blue)begin
						lock_blue <= 0;
					end 
					else if(formate_blue && detection_request) begin
						lock_blue <=1;
					end
				end
		endcase
	end 
end
endmodule



module L_abs(
	input [7:0] L_in,
	output reg [7:0] L_wut
);
	always @(*) begin
			if(2 * L_in > 255) begin
				L_wut = 2 * L_in - 255;	
			end 
			else begin
				L_wut = 255 - 2*L_in;
			end
		end
endmodule

module comparator(
    input [7:0] a_1,
    input [7:0] b_1,
    output reg [7:0] a_0,
    output reg [7:0] b_0
);
    always @(a_1, b_1) begin
        if (a_1 > b_1) begin
            a_0 = a_1;
            b_0 = b_1;
        end
        else begin
            a_0 = b_1;
            b_0 = a_1;
        end
    end
endmodule

module Median(
	input[7:0] reg_5,
	input [10:0] x_value,
	input [7:0] smooth_value,
	input [7:0] a,
	input [7:0] b,
	input [7:0] c,
	input [7:0] d,
	input [7:0] e,
	output [7:0] median
);
	parameter IMAGE_W = 11'd640;
	parameter IMAGE_H = 11'd480;
    wire [7:0] aa, bb, cc, dd, ee;
    wire [7:0] a1, b1, c1, d1, b2, c2, d2, e2, a2, b3, c3, d3, b4, c4, d4, e4, a5, b5, c5, d5;
    comparator c1l1( a,  b, a1, b1);
    comparator c2l1( c,  d, c1, d1);
    comparator c1l2(b1, c1, b2, c2);
    comparator c2l2(d1,  e, d2, e2);
    comparator c1l3(a1, b2, a2, b3);
    comparator c2l3(c2, d2, c3, d3);
    comparator c1l4(b3, c3, b4, c4);
    comparator c2l4(d3, e2, d4, e4);
    comparator c1l5(a2, b4, a5, b5);
    comparator c2l6(c4, d4, c5, d5);
	assign median = (x_value < 2)? smooth_value: (x_value % IMAGE_W > IMAGE_W - 2 )? reg_5 : c5; 

endmodule