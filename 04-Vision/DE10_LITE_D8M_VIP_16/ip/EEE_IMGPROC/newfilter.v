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
output	reg	[31:0]	s_readdata;
input	[31:0]				s_writedata;
input	[2:0]					s_address;


// streaming sink
input	[23:0]            	sink_data;
input								sink_valid;
output							sink_ready;
input								sink_sop;
input								sink_eop;

// streaming source
output	[23:0]			  	   source_data;
output								source_valid;
input									source_ready;
output								source_sop;
output								source_eop;

// conduit export
input                         mode;
output				[15:0]    message_to_ESP32;
input				[15:0]    message_from_ESP32;




////////////////////////////////////////////////////////////////////////
//
//HSV and Luminance



parameter IMAGE_W = 11'd640;
parameter IMAGE_H = 11'd480;
parameter MESSAGE_BUF_MAX = 256;
parameter MSG_INTERVAL = 6;
parameter BB_COL_DEFAULT = 24'h00ff00;
parameter horizontal_edge_region_threshold = 6'd30;
parameter vertical_region_confirm_threshold = 6'd50;

wire [7:0]   red, green, blue, grey;
wire [7:0]   red_out, green_out, blue_out;

wire         sop, eop, in_valid, out_ready;
////////////////////////////////////////////////////////////////////////
wire red_detected, green_detected, pink_detected, orange_detected, black_detected;
wire [23:0] color_high;

//reg [7:0] min_value;
//reg signed [9:0] hue; 

wire[9:0] hue ;
wire[7:0] saturation, value, min;

// reg [7:0] luminosity;
// reg [7:0] saturation;

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
// [0.006 0.061 0.242 0.383 0.242 0.061 0.006]

// [0.061 0.242 0.383 0.242 0.061] 

// [8/128 , 31/128 , 49/128 , 31/128 , 8/128]
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


//////////////////////////////////////////////////////////
//Median Filter
//////////////////////////////////////////////////////////
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


///////////////////////////////////////////////////
// 1D Edge Detection
//////////////////////////////////////////////////

wire [14:0] L_r, L_g, L_b; 
wire [7:0] L;
// Luminance = 0.3R + 0.59G + 0.11B 
assign L_r = 39 * median_red;
assign L_g = 75 * median_green;
assign L_b = 14 * median_blue;
assign L = L_r[14:7] + L_g[14:7] + L_b[14:7];

reg [7:0] L_1, L_2, L_3, L_4, L_5;
//wire [15:0] tmp_l_1, tmp_l_2, tmp_l_3, tmp_l_4, tmp_l_5;
reg signed [8:0] h_edge; 
reg h_edge_detected_1, h_edge_detected_2, h_edge_detected_3;
wire h_edge_detected_final;
wire [7:0] h_edge_detected_final_shifted;
reg h_edge_detected;

always @(posedge clk) begin
	L_1 <= L;
	L_2 <= L_1;
	L_3 <= L_2;
	L_4 <= L_3;
	L_5 <= L_4;
	h_edge_detected_1 <= h_edge_detected;
    h_edge_detected_2 <= h_edge_detected_1;
	h_edge_detected_3 <= h_edge_detected_2;	
end

assign h_edge_detected_final_shifted = h_edge_detected_final ? 8'hfa : 8'h0;

// always @(posedge clk)begin

assign	h_edge_detected_final = (h_edge_detected_1 && h_edge_detected_2 && h_edge_detected_3);
//end
// Luminance 1 2 3 4 5 
//RGB        1 2 3 4 5

always @(*) begin
	if (x < 5) begin
		h_edge = 0;
	end 
	if (x > IMAGE_W - 5) begin
		h_edge = 0;
	end 
	else begin
		h_edge = L_5 + L_4 - L_2 - L_1;
	end
	//assign h_edge_detected = (h_edge[8]==0)? h_edge > 0.5 : (-1 * h_edge) > 0.5;
	if (h_edge[8] == 0) begin
		if (h_edge > 150) begin
			h_edge_detected = 1;

		end
		else begin
			h_edge_detected = 0;
		end
	end
	if (h_edge[8] == 1) begin
		if (h_edge < -150) begin
			h_edge_detected = 1;

		end
		else begin
			h_edge_detected = 0;
		end
	end
end


// detecting edge surrounding


///////////////////////////////////////////////////////////////////
//HSV Convertion
///////////////////////////////////////////////////////////////////
assign value = (red > green) ? ((red > blue) ? red[7:0] : blue[7:0]) : (green > blue) ? green[7:0] : blue[7:0];						
assign min = (red < green)? ((red<blue) ? red[7:0] : blue[7:0]) : (green < blue) ? green [7:0] : blue[7:0];
assign saturation = (value - min)* 255 / value;
assign hue = (red == green && red == blue) ? 0 :((value != red)? (value != green) ? (((240*((value - min))+ (60* (red - green)))/(value-min))>>1):
                ((120*(value-min)+60*(blue - red))/(value - min)>>1): 
                (blue < green) ? ((60*(green - blue)/(value - min))>>1): (((360*(value-min) +(60*(green - blue)))/(value - min))>>1));


reg red_detected_1,red_detected_2,red_detected_3 ,red_detected_4, red_detected_5, red_detected_6;
reg pink_detected_1,pink_detected_2,pink_detected_3 ,pink_detected_4, pink_detected_5, pink_detected_6;
reg green_detected_1,green_detected_2,green_detected_3, green_detected_4, green_detected_5, green_detected_6;
reg orange_detected_1, orange_detected_2, orange_detected_3, orange_detected_4, orange_detected_5, orange_detected_6;
reg black_detected_1, black_detected_2, black_detected_3, black_detected_4, black_detected_5, black_detected_6;

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

	orange_detected_1 = 0;
	orange_detected_2 = 0;
	orange_detected_3 = 0;
	orange_detected_4 = 0;
	orange_detected_5 = 0;
	orange_detected_6 = 0;
	
	black_detected_1 = 0;
	black_detected_2 = 0;
	black_detected_3 = 0;
	black_detected_4 = 0;
	black_detected_5 = 0;
	black_detected_6 = 0;

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
	
	orange_detected_1 <= orange_detected;
	orange_detected_2 <= orange_detected_1;
	orange_detected_3 <= orange_detected_2;
	orange_detected_4 <= orange_detected_3;
	orange_detected_5 <= orange_detected_4;
	orange_detected_6 <= orange_detected_5;

	black_detected_1 <= black_detected;
	black_detected_2 <= black_detected_1;
	black_detected_3 <= black_detected_2;
	black_detected_4 <= black_detected_3;
	black_detected_5 <= black_detected_4;
	black_detected_6 <= black_detected_5;
end

assign black_detected = (10 < hue  && hue < 25);

assign pink_detected = 
// (	

//change 1
( (145 < hue && hue < 180) &&  (60 < saturation && saturation < 100) && (180 < value)) ||
//change 2 test
//|| ((145 < hue && hue < 180));
// change 3 test
((hue < 30) && (saturation < 100 && saturation > 60) && (value > 60));

assign orange_detected = (((hue >= 13 && hue <=25) && (saturation > 133 && value > 108)) || ((hue >= 23 && hue <= 30) && ((value > 155 && saturation > 127)||(saturation >= 153 && value > 252)||(value > 100 && saturation > 247))));

assign green_detected = ((hue >= 50 && hue <= 75) && (saturation > 105 && value >= 50)) || ((hue >= 50 && hue <= 75) && ((saturation > 127 && value > 173)))
//change 2 
//change 3 test
||  ((hue > 40 && hue < 90) && ( 10 < value && value < 80) && (saturation > 30));

// change 1 (hue >= 50 && hue <= 75) && (saturation > 105 && value >= 75)
assign red_detected = (hue < 12 && saturation > 130 && value > 50) || ((hue < 360 && hue > 330) && (saturation > 130) && value > 50);
//assign black_final_detected = (value <= 37 && x > 10 && x < IMAGE_W-10 && y > 10 && y < IMAGE_H - 10);	

//assign black_detected = (0 < hue  && hue < 5);


wire red_final_detected, pink_final_detected, green_final_detected, orange_final_detected, black_final_detected;
assign red_final_detected = red_detected_1 && red_detected_2 && red_detected_3 && red_detected_4 && red_detected_5 && red_detected_6;
assign pink_final_detected = pink_detected_1 && pink_detected_2 && pink_detected_3 && pink_detected_4 && pink_detected_5 && pink_detected_6;
assign green_final_detected = green_detected_1 && green_detected_2 && green_detected_3 && green_detected_4 && green_detected_5 && green_detected_6;
assign orange_final_detected = orange_detected_1 && orange_detected_2 && orange_detected_3 && orange_detected_4 && orange_detected_5 && orange_detected_6;
assign black_final_detected = black_detected_1 && black_detected_2 && black_detected_3 && black_detected_4 && black_detected_5 && black_detected_6;


// (hue >= 25 && hue <= 50) && (saturation >= 153 && saturation <= 255) && (luminosity >= 128 && luminosity <= 179);

// RED   ::: 355° to 10°
// Greem ::: 81° to 140°
// pink  ::: 331° to 331° 
// orange  ::: 221° to 240°
// Find boundary of cursor box
// Highlight detected areas


assign grey = green[7:1] + red[7:2] + blue[7:2]; //Grey = green/2 + red/4 + blue/4

assign color_high  =  
					  (red_final_detected) ? {8'hff, 8'h0, 8'h0} : 
					  (green_final_detected) ? {8'h04,8'hbd,8'h42} :
					  (pink_final_detected) ? {8'hff,8'h00,8'h5d} :
					  (orange_final_detected) ? {8'hff,8'h77,8'h00} : 
					  (black_final_detected) ? (24'h00ffff) : 
					  {grey, grey, grey};

//red_high pure red if red_detect else grey.


// Show bounding box

wire [23:0] new_image;
wire bb_active_r, bb_active_g, bb_active_p, bb_active_o, bb_active_edge, bb_active_b;

reg [10:0] left_r, left_p, left_g, left_o, left_b;
reg [10:0] right_r, right_p, right_g, right_o, right_b;
reg [10:0] top_r, top_p, top_g, top_o, top_b;
reg [10:0] bottom_r, bottom_p, bottom_g, bottom_o, bottom_b;
reg [10:0] left_edge, right_edge, top_edge, bottom_edge;

assign bb_active_r = (x == left_r && left_r != IMAGE_W-11'h1) || (x == right_r && right_r != 0) || (y == top_r && top_r != IMAGE_H-11'h1) || (y == bottom_r && bottom_r != 0);
assign bb_active_p = (x == left_p && left_p != IMAGE_W-11'h1) || (x == right_p && right_p != 0) || (y == top_p && top_p != IMAGE_H-11'h1) || (y == bottom_p && bottom_p != 0);
assign bb_active_g = (x == left_g && left_g != IMAGE_W-11'h1) || (x == right_g && right_g != 0) || (y == top_g && top_g != IMAGE_H-11'h1) || (y == bottom_g && bottom_g != 0);
assign bb_active_o = (x == left_o && left_o != IMAGE_W-11'h1) || (x == right_o && right_o != 0) || (y == top_o && top_o != IMAGE_H-11'h1) || (y == bottom_o && bottom_o != 0);
assign bb_active_edge = (x == left_edge && left_edge != IMAGE_W-11'h1) || (x == right_edge && right_edge != 0) || (y == top_edge && top_edge != IMAGE_H-11'h1) || (y == bottom_edge && bottom_edge != 0);
assign bb_active_b = (x == left_b && left_b != IMAGE_W-11'h1) || (x == right_b && right_b != 0) || (y == top_b && top_b != IMAGE_H-11'h1) || (y == bottom_b && bottom_b != 0);


// active r = x = left_r |  && red_detected 
assign new_image = 
//bb_active_edge ? {24'hf20b97} : 
//{h_edge_detected_final_shifted,h_edge_detected_final_shifted,h_edge_detected_final_shifted}; 
//{h_edge_detected_final_shifted,h_edge_detected_final_shifted,h_edge_detected_final_shifted}; 
// bb_active_r ? {24'hff0000} : 
 //bb_active_p ? {24'h00ff00} : 
// bb_active_g ? {24'h0000ff} : 
 bb_active_o ? {24'hf0f0f0} : 
 bb_active_b ? {24'hff00ff} :
 color_high; 

assign {red_out, green_out, blue_out} = (mode & ~sop & packet_video) ? new_image : 
//{h_edge_detected_final_shifted,h_edge_detected_final_shifted,h_edge_detected_final_shifted}:
{red,green,blue};
// Toggling switch SW0 switch between raw camera data and a basic red image
//sop : start of packet 

//source reg data input 




///////////////////////////////////////////////////////////////////////////////////////////////////
// Refined Filter
///////////////////////////////////////////////////////////////////////////////////////////////////
//Count valid pixels to tget the image coordinates. Reset and detect packet type on Start of Packet.
reg [10:0] x, y;
reg packet_video;

reg [10:0] count_r, count_p, count_o, count_g, count_b;
//count how many pixels in this color between the edge gap
reg [10:0] max_start_edge_x_position_r,  max_start_edge_x_position_p, max_start_edge_x_position_o, max_start_edge_x_position_g, max_start_edge_x_position_b;
reg [10:0] max_end_edge_x_position_r, max_end_edge_x_position_p, max_end_edge_x_position_o, max_end_edge_x_position_g, max_end_edge_x_position_b;
reg [10:0] pre_edge_x_position, imm_edge_x_position;

wire [7:0] current_valid_region_r, current_valid_region_p, current_valid_region_o, current_valid_region_g, current_valid_region_b;
reg  [7:0] max_valid_region_r, max_valid_region_p, max_valid_region_o, max_valid_region_g, max_valid_region_b;

assign current_valid_region_r = 100 * (count_r / (x - pre_edge_x_position));
assign current_valid_region_p = 100 * (count_p / (x - pre_edge_x_position));
assign current_valid_region_o = 100 * (count_o / (x - pre_edge_x_position));
assign current_valid_region_g = 100 * (count_g / (x - pre_edge_x_position));
assign current_valid_region_b = 100 * (count_b / (x - pre_edge_x_position));


reg [10:0] estimatated_region_start_r, estimatated_region_end_r;
reg [10:0] estimatated_region_start_p, estimatated_region_end_p;
reg [10:0] estimatated_region_start_o, estimatated_region_end_o;
reg [10:0] estimatated_region_start_g, estimatated_region_end_g;
reg [10:0] estimatated_region_start_b, estimatated_region_end_b;
reg[7:0] estimated_val_r, estimated_val_p, estimated_val_o, estimated_val_g, estimated_val_b ;

wire [10:0] mid_deviation_r, mid_deviation_p, mid_deviation_o, mid_deviation_g, mid_deviation_b;

assign mid_deviation_r =  ((estimatated_region_end_r + estimatated_region_start_r) > (max_start_edge_x_position_r + max_end_edge_x_position_r)) ? 
							((estimatated_region_end_r + estimatated_region_start_r) - (max_start_edge_x_position_r + max_end_edge_x_position_r))
							: ((max_start_edge_x_position_r + max_end_edge_x_position_r) - ( estimatated_region_end_r + estimatated_region_start_r ));


assign mid_deviation_p =  ((estimatated_region_end_p + estimatated_region_start_p) > (max_start_edge_x_position_p + max_end_edge_x_position_p)) ? 
							((estimatated_region_end_p + estimatated_region_start_p) - (max_start_edge_x_position_p + max_end_edge_x_position_p))
							: ((max_start_edge_x_position_p + max_end_edge_x_position_p) - ( estimatated_region_end_p + estimatated_region_start_p ));


assign mid_deviation_o =  ((estimatated_region_end_o + estimatated_region_start_o) > (max_start_edge_x_position_o + max_end_edge_x_position_o)) ? 
							((estimatated_region_end_o + estimatated_region_start_o) - (max_start_edge_x_position_o + max_end_edge_x_position_o))
							: ((max_start_edge_x_position_o + max_end_edge_x_position_o) - ( estimatated_region_end_o + estimatated_region_start_o ));

assign mid_deviation_g =  ((estimatated_region_end_g + estimatated_region_start_g) > (max_start_edge_x_position_g + max_end_edge_x_position_g)) ? 
							((estimatated_region_end_g + estimatated_region_start_g) - (max_start_edge_x_position_g + max_end_edge_x_position_g))
							: ((max_start_edge_x_position_g + max_end_edge_x_position_g) - ( estimatated_region_end_g + estimatated_region_start_g ));

assign mid_deviation_b =  ((estimatated_region_end_b + estimatated_region_start_b) > (max_start_edge_x_position_b + max_end_edge_x_position_b)) ? 
							((estimatated_region_end_b + estimatated_region_start_b) - (max_start_edge_x_position_b + max_end_edge_x_position_b))
							: ((max_start_edge_x_position_b + max_end_edge_x_position_b) - ( estimatated_region_end_b + estimatated_region_start_b ));

// TODO : add difference if it is possible


always@(posedge clk) begin

    if (in_valid) begin
		if (sop & in_valid) begin	//Reset bounds on start of packet
			x_min_r <= IMAGE_W-11'h1;
			x_max_r <= 0;
			y_min_r <= IMAGE_H-11'h1;
			y_max_r <= 0;
			x_min_g <= IMAGE_W-11'h1;
			x_max_g <= 0;
			y_min_g <= IMAGE_H-11'h1;
			y_max_g <= 0;
			x_min_o <= IMAGE_W-11'h1;
			x_max_o <= 0;
			y_min_o <= IMAGE_H-11'h1;
			y_max_o <= 0;
			x_min_p <= IMAGE_W-11'h1;
			x_max_p <= 0;
			y_min_p <= IMAGE_H-11'h1;
			y_max_p <= 0;
			edge_x_min <= IMAGE_W-11'h1;
			edge_x_max <= 0;
			edge_y_min <= IMAGE_H-11'h1;
			edge_y_max <= 0;
			// count_r <= 0; 
			// count_p <= 0; 
			// count_o <= 0; 
			// count_g <= 0; 
			// count_b <= 0;
			estimated_val_r <= 0;
			estimated_val_p <= 0;
			estimated_val_o <= 0;
			estimated_val_g <= 0;
			estimated_val_b <= 0;
		end
		else begin
			/////////////////////////////////////////////////
			// Row :: locating max_valid_region in a row or counting red..
			/////////////////////////////////////////////////
			if (in_valid)begin
				if(h_edge_detected_final) begin 
					imm_edge_x_position <= x;
					if ((x - pre_edge_x_position > horizontal_edge_region_threshold) && (x - imm_edge_x_position > 20)) begin
						pre_edge_x_position <= x;
					// 1 limition - detect a clear edge
					// 2 limitation - the distance between the two edges larger than 50
					
						if ( (current_valid_region_r > max_valid_region_r) &&  (current_valid_region_r > horizontal_edge_region_threshold) ) begin
							// if the percentage of certain colored pixel is max, record the start and end position.
							//percentage record
							max_valid_region_r <= current_valid_region_r;
							//position record
							max_start_edge_x_position_r <= pre_edge_x_position;
							max_end_edge_x_position_r <= x;
						end

						if ( (current_valid_region_p > max_valid_region_p) &&  (current_valid_region_p > horizontal_edge_region_threshold) ) begin
						
							max_valid_region_p <= current_valid_region_p;
							//position record
							max_start_edge_x_position_p <= pre_edge_x_position;
							max_end_edge_x_position_p <= x;
						end

						if ( (current_valid_region_o > max_valid_region_o) &&  (current_valid_region_o > 0) ) begin
							max_valid_region_o <= current_valid_region_o;
							//position record
							max_start_edge_x_position_o <= pre_edge_x_position;
							max_end_edge_x_position_o <= x;
						end

						if ( (current_valid_region_g > max_valid_region_g) &&  (current_valid_region_g > horizontal_edge_region_threshold) ) begin
							max_valid_region_g <= current_valid_region_g;
							//position record
							max_start_edge_x_position_g <= pre_edge_x_position;
							max_end_edge_x_position_g <= x;
							
						end

						if ( (current_valid_region_b > max_valid_region_b) &&  (current_valid_region_b > horizontal_edge_region_threshold) ) begin
							max_valid_region_b <= current_valid_region_b;
							//position record
							max_start_edge_x_position_b <= pre_edge_x_position;
							max_end_edge_x_position_b <= x;
						end
						count_r <= 0;
						count_p <= 0;
						count_o <= 0;
						count_g <= 0;
						count_b <= 0;

					end
					else begin
						
						if (red_final_detected) begin
							count_r <= count_r + 1;
						end

						if (pink_final_detected) begin
							count_p <= count_p + 1;
						end
						
						if (orange_final_detected) begin
							count_o <= count_o + 1;
						end

						if (green_final_detected) begin
							count_g <= count_g + 1;
						end

						if (black_final_detected) begin
							count_b <= count_b + 1;
						end

					end
					

				end
				else begin
					if (red_final_detected) begin
						count_r <= count_r + 1;
					end

					if (pink_final_detected) begin
						count_p <= count_p + 1;
					end
					
					if (orange_final_detected) begin
						count_o <= count_o + 1;
					end

					if (green_final_detected) begin
						count_g <= count_g + 1;
					end

					if (black_final_detected) begin
						count_b <= count_b + 1;
					end

				end
			end

     		//////////////////////////////////////////////////////////////
			// Column :: 
     		//////////////////////////////////////////////////////////////
			if (x == IMAGE_W-1) begin
				max_valid_region_r <= 0;
				max_valid_region_p <= 0;
				max_valid_region_o <= 0;
				max_valid_region_g <= 0;
				max_valid_region_b <= 0;
				pre_edge_x_position <= 0;
				
				max_start_edge_x_position_r <= 0;
				max_end_edge_x_position_r <= 0;
				max_start_edge_x_position_p <= 0;
				max_end_edge_x_position_p <= 0;
				max_start_edge_x_position_o <= 0;
				max_end_edge_x_position_o <= 0;
				max_start_edge_x_position_g <= 0;
				max_end_edge_x_position_g <= 0;
				max_start_edge_x_position_b <= 0;
				max_end_edge_x_position_b <= 0;


				// when the estimation is not valid
				//Red
				if(max_start_edge_x_position_r != max_end_edge_x_position_r )begin
					if(estimated_val_r == 0) begin
						estimatated_region_start_r <= max_start_edge_x_position_r;
						estimatated_region_end_r <= max_end_edge_x_position_r;
						// error choice, reset.
						x_min_r <= IMAGE_W-11'h1;
						x_max_r <= 0;
						y_min_r <= IMAGE_H-11'h1;
						y_max_r <= 0;
						estimated_val_r <= 1;
					end

					else begin
						if(mid_deviation_r > horizontal_edge_region_threshold)begin
							estimated_val_r <= estimated_val_r - 1;
						end
						else begin

							estimated_val_r <= estimated_val_r + 1;
							// choose the x region
							if(x_min_r > max_start_edge_x_position_r) begin
								x_min_r <= max_start_edge_x_position_r;
							end
							if(x_max_r < max_end_edge_x_position_r) begin
								x_max_r <= max_end_edge_x_position_r;
							end
							// choose y region
							if (y_min_r > y) begin
								y_min_r <= y;
							end
							if (y_max_r < y)begin
								y_max_r <= y;
							end
						
						end
					end
				end
				

				//Pink
				if(max_start_edge_x_position_p != max_end_edge_x_position_p)begin
					if(estimated_val_p == 0)begin
						estimatated_region_start_p <= max_start_edge_x_position_p;
						estimatated_region_end_p <= max_end_edge_x_position_p;
						//reset
						left_p <= IMAGE_W-11'h1;
						right_p <= 0;
						top_p <= IMAGE_W-11'h1;
						bottom_p <= 0;
						estimated_val_p <= 1;
					end
					else begin
						if(mid_deviation_p > horizontal_edge_region_threshold)begin
							estimated_val_p <= estimated_val_p - 1;
						
						end
						else begin
							estimated_val_p <= estimated_val_p + 1;

							if(x_min_p > max_start_edge_x_position_p) begin
								x_min_p <= max_start_edge_x_position_p;
							end
							if(x_max_p < max_end_edge_x_position_p) begin
								x_max_p <= max_end_edge_x_position_p;
							end
							// choose y region
							if (y_min_p > y) begin
								y_min_p <= y;
							end
							if (y_max_p < y)begin
								y_max_p <= y;
							end
						end
					end
				end
				//Orange
				if(max_start_edge_x_position_o != max_end_edge_x_position_o )begin
					if(estimated_val_o == 0)begin
						estimatated_region_start_o <= max_start_edge_x_position_o;
						estimatated_region_end_o <= max_end_edge_x_position_o;
						//reset
						x_min_o <= IMAGE_W-11'h1;
						x_max_o <= 0;
						y_min_o <= IMAGE_H-11'h1;
						y_max_o <= 0;
						estimated_val_o <= 1;
					end
					else begin
						if(mid_deviation_o > horizontal_edge_region_threshold)begin
							estimated_val_o <= estimated_val_o - 1;
						end
						else begin
							estimated_val_o <= estimated_val_o + 1;
							if(x_min_o > max_start_edge_x_position_o) begin
								x_min_o <= max_start_edge_x_position_o;
							end
							if(x_max_o < max_end_edge_x_position_o) begin
								x_max_o <= max_end_edge_x_position_o;
							end
							// choose y region
							if (y_min_o > y) begin
								y_min_o <= y;
							end
							if (y_max_o < y)begin
								y_max_o <= y;
							end
						end
					end
				end

				//Green
				if(max_start_edge_x_position_g != max_end_edge_x_position_g )begin
					if(estimated_val_g == 0)begin
						estimatated_region_start_g <= max_start_edge_x_position_g;
						estimatated_region_end_g <= max_end_edge_x_position_g;
						//reset
						x_min_g <= IMAGE_W-11'h1;
						x_max_g <= 0;
						y_min_g <= IMAGE_H-11'h1;
						y_max_g <= 0;
						estimated_val_g <= 1;

					end
					else begin
						if(mid_deviation_g > horizontal_edge_region_threshold)begin
						estimated_val_g <= estimated_val_g - 1;
						end
						else begin
							estimated_val_g <= estimated_val_g + 1;
							if(x_min_g > max_start_edge_x_position_g) begin
								x_min_g <= max_start_edge_x_position_g;
							end
							if(x_max_g < max_end_edge_x_position_g) begin
								x_max_g <= max_end_edge_x_position_g;
							end
							// choose y region
							if (y_min_g > y) begin
								y_min_g <= y;
							end
							if (y_max_g < y)begin
								y_max_g <= y;
							end

						end
					end
				end
				//Black
				if(max_start_edge_x_position_b != max_end_edge_x_position_b )begin
					if(estimated_val_b == 0)begin
						estimatated_region_start_b <= max_start_edge_x_position_b;
						estimatated_region_end_b <= max_end_edge_x_position_b;
						//reset
						x_min_b <= IMAGE_W-11'h1;
						x_max_b <= 0;
						y_min_b <= IMAGE_H-11'h1;
						y_max_b <= 0;
						estimated_val_b <= 1;
					end
					else begin
						if(mid_deviation_b > horizontal_edge_region_threshold)begin
							estimated_val_b <= estimated_val_b - 1;
						end
						else begin
							estimated_val_b <= estimated_val_b + 1;
							if(x_min_b > max_start_edge_x_position_b) begin
								x_min_b <= max_start_edge_x_position_b;
							end
							if(x_max_b < max_end_edge_x_position_b) begin
								x_max_b <= max_end_edge_x_position_b;
							end
							// choose y region
							if (y_min_b > y) begin
								y_min_b <= y;
							end
							if (y_max_b < y)begin
								y_max_b <= y;
							end
						end
					end
				end
			end
		end
	end
end




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
reg [10:0] x_min, y_min, x_max, y_max;
reg [10:0] x_min_r, x_min_p, x_min_g, x_min_o, x_min_b;
reg [10:0] y_min_r, y_min_p, y_min_g, y_min_o, y_min_b;
reg [10:0] x_max_r, x_max_p, x_max_g, x_max_o, x_max_b;
reg [10:0] y_max_r, y_max_p, y_max_g, y_max_o, y_max_b;

reg [10:0] edge_x_min, edge_x_max, edge_y_min, edge_y_max;





//Process bounding box at the end of the frame.
reg [1:0] msg_state;
reg [7:0] frame_count;
always@(posedge clk) begin
	if (eop & in_valid & packet_video) begin  //Ignore non-video packets
		//Latch edges for display overlay on next frame
		//if (red_detected) begin
			left_r <= x_min_r;
			right_r <= x_max_r;
			top_r <= y_max_r;
			bottom_r <= y_min_r;
		//end
		
		//else if (green_detected) begin
			left_g <= x_min_g;
			right_g <= x_max_g;
			top_g <= y_max_g;
			bottom_g <= y_min_g;
		//end
		
		//else if(pink_detected) begin
			left_p <= x_min_p;
			right_p <= x_max_p;
			top_p <= y_max_p;
			bottom_p <= y_min_p;
		//end

		//else if (orange_detected) begin
			left_o <= x_min_o;
			right_o <= x_max_o;
			top_o <= y_max_o;
			bottom_o <= y_min_o;
		//end
			left_edge <= edge_x_min;
			right_edge <= edge_x_max;
			top_edge <= edge_y_max;
			bottom_edge <= edge_y_min;

		
		//window for last frame, frame is refreshed every eop
		
		//Start message writer FSM once every MSG_INTERVAL frames, if there is room in the FIFO
		frame_count <= frame_count - 1;
		
		if (frame_count == 0 && msg_buf_size < MESSAGE_BUF_MAX - 3) begin
			msg_state <= 2'b01;
			frame_count <= MSG_INTERVAL-1;
		end
	end
	//parameter MESSAGE_BUF_MAX = 256 parameter MSG_INTERVAL = 6;
	
	//Cycle through message writer states once started
	if (msg_state != 2'b00) msg_state <= msg_state + 2'b01;

end
	
//Generate output messages for CPU
reg [31:0] msg_buf_in;  
wire [31:0] msg_buf_out;
reg msg_buf_wr;
wire msg_buf_rd, msg_buf_flush;
wire [7:0] msg_buf_size;
wire msg_buf_empty;

`define RED_BOX_MSG_ID "RBB"

always@(*) begin	//Write words to FIFO as state machine advances
	case(msg_state)
		2'b00: begin
			msg_buf_in = 32'b0;
			msg_buf_wr = 1'b0;
		end
		2'b01: begin
			//msg_buf_in = 
			msg_buf_in = {24'b0,current_valid_region_o};
			
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

// two pipeline stages source to sink
//data-in D             data-out Q
//in_valid              out_valid
//ready_in   backpressure input from the next stage         ready_out backpressure output to the previous stage


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
`define REG_STATUS    			0
`define READ_MSG    				1
`define READ_ID    				2
`define REG_BBCOL					3

//Status register bits
// 31:16 - unimplemented
// 15:8 - number of words in message buffer (read only)
// 7:5 - unused
// 4 - flush message buffer (write only - read as 0)
// 3:0 - unused


// Process write

reg  [7:0]   reg_status;
reg	[23:0]	bb_col;

always @ (posedge clk)
begin
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


// Process reads
reg read_d; //Store the read signal for correct updating of the message buffer

// Copy the requested word to the output port when there is a read.
always @ (posedge clk)
begin
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
						
assign message_to_ESP32 = max_valid_region_r;

endmodule






module L_abs(
	input [7:0] L_in,
	output reg [7:0] L_out
);
	always @(*) begin
			if(2 * L_in > 255) begin
				L_out = 2 * L_in - 255;	
			end 
			else begin
				L_out = 255 - 2*L_in;
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
    // assign aa = a5;
    // assign bb = b5;
    // assign cc = c5;
    // assign dd = d5;
    // assign ee = e4;
	// median = c5;
endmodule



