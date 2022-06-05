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
output 	 reg		[15:0]	      message_to_ESP32;
input 			[15:0]			  message_from_ESP32;




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
reg [10:0] x, y;
reg packet_video;
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
assign	h_edge_detected_final = (h_edge_detected_1 && h_edge_detected_2 && h_edge_detected_3);


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




assign pink_detected = 
// (	
// (((hue >= 150 && hue <= 180)||(hue <= 6 && hue >= 0)) && (saturation > 84 && value > 245))||
// (hue <= 6 && hue >= 0 && ((value > 229 && saturation > 17 && saturation < 155)||(value > 210 && saturation > 130)))
// || ((hue >= 160 && hue <= 180) && ((saturation >= 76 && value >= 249) || (saturation >= 102 && value >= 140)))
// || (((hue >= 160 && hue <= 180)||(hue >= 0 && hue <= 4)) && (saturation > 140 && saturation <= 179 && value >= 89 && value <= 106)) 
// ||(((hue >= 172 && hue <= 180)||(hue >= 0 && hue <= 6)) && ((value >  105 && saturation > 102) || (saturation > 82 && value > 168)))) //sat > 102
//change 1
//( (145 < hue && hue < 180) &&  (17 < saturation && saturation < 100) && (180 < value))
//change 2 test
//|| ((145 < hue && hue < 180));
// change 3 test
(((hue < 30)) && (saturation < 100 && saturation > 20) && (value > 60));

assign orange_detected = (((hue >= 13 && hue <=25) && (saturation > 133 && value > 108)) || ((hue >= 23 && hue <= 30) && ((value > 155 && saturation > 127)||(saturation >= 153 && value > 252)||(value > 100 && saturation > 247))));

assign green_detected = ((hue >= 50 && hue <= 75) && (saturation > 105 && value >= 50)) || ((hue >= 50 && hue <= 75) && ((saturation > 127 && value > 173)))
//change 2 
//change 3 test
||  ((hue > 40 && hue < 90) && ( 10 < value && value < 80) && (saturation > 30));

// change 1 (hue >= 50 && hue <= 75) && (saturation > 105 && value >= 75)


assign red_detected = (hue < 12 && saturation > 130 && value > 50) || ((hue < 360 && hue > 330) && (saturation > 130) && value > 50);
//assign black_final_detected = (value <= 37 && x > 10 && x < IMAGE_W-10 && y > 10 && y < IMAGE_H - 10);	

//assign black_detected = (0 < hue  && hue < 5);

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


wire red_final_detected, pink_final_detected, green_final_detected, orange_final_detected, black_final_detected;
assign red_final_detected = red_detected_1 && red_detected_2 && red_detected_3 && red_detected_4 && red_detected_5 && red_detected_6;
assign pink_final_detected = pink_detected_1 && pink_detected_2 && pink_detected_3 && pink_detected_4 && pink_detected_5 && pink_detected_6;
assign green_final_detected = green_detected_1 && green_detected_2 && green_detected_3 && green_detected_4 && green_detected_5 && green_detected_6;
assign orange_final_detected = orange_detected_1 && orange_detected_2 && orange_detected_3 && orange_detected_4 && orange_detected_5 && orange_detected_6;
assign black_final_detected = black_detected_1 && black_detected_2 && black_detected_3 && black_detected_4 && black_detected_5 && black_detected_6;

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

 bb_active_r ? {24'hff0000} : 
 bb_active_p ? {24'hfc0394} : 
 bb_active_g ? {24'h1cfc03} : 
 bb_active_o ? {24'hf0f0f0} : 
 bb_active_b ? {24'hff00ff}:
 color_high; 


assign {red_out, green_out, blue_out} = (mode & ~sop & packet_video) ? new_image : 
{red,green,blue};

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

reg h_edge_detected_final_1, h_edge_detected_final_2;

reg [10:0] edge_x_min, edge_x_max, edge_y_min, edge_y_max;



always@(posedge clk) begin
	h_edge_detected_final_1 <= h_edge_detected_final;
	h_edge_detected_final_2 <= h_edge_detected_final_1;
	if (in_valid & sop & in_valid) begin	//Reset bounds on start of packet
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
	end
	else begin
		if (red_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2)) begin	//Update bounds when the pixel is red
			if (x < x_min_r) x_min_r <= x;
			if (x > x_max_r) x_max_r <= x;
			if (y < y_min_r) y_min_r <= y;
			if (y > y_max_r) y_max_r <= y;
		end
		
		else if (green_detected & green_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2)) begin	//Update bounds when the pixel is red
			if (x < x_min_g) x_min_g <= x;
			if (x > x_max_g) x_max_g <= x;
			if (y < y_min_g) y_min_g <= y;
			if (y > y_max_g) y_max_g <= y;
		end

		else if (pink_detected & pink_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2) & in_valid) begin	//Update bounds when the pixel is red
			if (x < x_min_p) x_min_p <= x;
			if (x > x_max_p) x_max_p <= x;
			if (y < y_min_p) y_min_p <= y;
			if (y > y_max_p) y_max_p <= y;
		end
		
		else if (orange_detected & orange_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2) & in_valid) begin	//Update bounds when the pixel is red
			if (x < x_min_o) x_min_o <= x;
			if (x > x_max_o) x_max_o <= x;
			if (y < y_min_o) y_min_o <= y;
			if (y > y_max_o) y_max_o <= y;
		end

		else if (black_detected  & black_final_detected & in_valid & (h_edge_detected_final || h_edge_detected_final_1 || h_edge_detected_final_2) & in_valid) begin	//Update bounds when the pixel is red
			if (x < x_min_b) x_min_b <= x;
			if (x > x_max_b) x_max_b <= x;
			if (y < y_min_b) y_min_b <= y;
			if (y > y_max_b) y_max_b <= y;
		end

		else if (h_edge_detected_final & in_valid ) begin
			if (x < edge_x_min) edge_x_min <= x;
			if (x > edge_x_max) edge_x_max <= x;
			if (y < edge_y_min) edge_y_min <= y;
			if (y > edge_y_max) edge_y_max <= y;
		end
	end
		

end

//Process bounding box at the end of the frame.
reg [1:0] msg_state;
reg [7:0] frame_count;

reg [10:0] left_r_1, left_r_2, left_r_3, left_r_4;
reg [10:0] right_r_1, right_r_2, right_r_3, right_r_4;
reg [10:0] top_r_1, top_r_2, top_r_3, top_r_4;
reg [10:0] bottom_r_1, bottom_r_2, bottom_r_3, bottom_r_4;

reg [10:0] left_p_1, left_p_2, left_p_3, left_p_4;
reg [10:0] right_p_1, right_p_2, right_p_3, right_p_4;
reg [10:0] top_p_1, top_p_2, top_p_3, top_p_4;
reg [10:0] bottom_p_1, bottom_p_2, bottom_p_3, bottom_p_4;

reg [10:0] left_o_1, left_o_2, left_o_3, left_o_4;
reg [10:0] right_o_1, right_o_2, right_o_3, right_o_4;
reg [10:0] top_o_1, top_o_2, top_o_3, top_o_4;
reg [10:0] bottom_o_1, bottom_o_2, bottom_o_3, bottom_o_4;

reg [10:0] left_g_1, left_g_2, left_g_3, left_g_4;
reg [10:0] right_g_1, right_g_2, right_g_3, right_g_4;
reg [10:0] top_g_1, top_g_2, top_g_3, top_g_4;
reg [10:0] bottom_g_1, bottom_g_2, bottom_g_3, bottom_g_4;

reg [10:0] left_b_1, left_b_2, left_b_3, left_b_4;
reg [10:0] right_b_1, right_b_2, right_b_3, right_b_4;
reg [10:0] top_b_1, top_b_2, top_b_3, top_b_4;
reg [10:0] bottom_b_1, bottom_b_2, bottom_b_3, bottom_b_4;

always@(posedge clk) begin
	if (eop & in_valid & packet_video) begin  //Ignore non-video packets
		//Latch edges for display overlay on next frame

			left_r <= x_min_r;
			right_r <= x_max_r;
			top_r <= y_max_r;
			bottom_r <= y_min_r;

			left_g <= x_min_g;
			right_g <= x_max_g;
			top_g <= y_max_g;
			bottom_g <= y_min_g;

			left_p <= x_min_p;
			right_p <= x_max_p;
			top_p <= y_max_p;
			bottom_p <= y_min_p;

			left_o <= x_min_o;
			right_o <= x_max_o;
			top_o <= y_max_o;
			bottom_o <= y_min_o;

			left_edge <= edge_x_min;
			right_edge <= edge_x_max;
			top_edge <= edge_y_max;
			bottom_edge <= edge_y_min;

//   keep last 4 values

			//red

			left_r_1 <= left_r;
			left_r_2 <= left_r_1;
			left_r_3 <= left_r_2;
			left_r_4 <= left_r_3;

			right_r_1 <= right_r;
			right_r_2 <= right_r_1;
			right_r_3 <= right_r_2;
			right_r_4 <= right_r_3;
			
			top_r_1 <= top_r;
			top_r_2 <= top_r_1;
			top_r_3 <= top_r_2;
			top_r_4 <= top_r_3;
			
			bottom_r_1 <= bottom_r;
			bottom_r_2 <= bottom_r_1;
			bottom_r_3 <= bottom_r_2;
			bottom_r_4 <= bottom_r_3;


			// pink
			left_p_1 <= left_p;
			left_p_2 <= left_p_1;
			left_p_3 <= left_p_2;
			left_p_4 <= left_p_3;

			right_p_1 <= right_p;
			right_p_2 <= right_p_1;
			right_p_3 <= right_p_2;
			right_p_4 <= right_p_3;
			
			top_p_1 <= top_p;
			top_p_2 <= top_p_1;
			top_p_3 <= top_p_2;
			top_p_4 <= top_p_3;
			
			bottom_p_1 <= bottom_p;
			bottom_p_2 <= bottom_p_1;
			bottom_p_3 <= bottom_p_2;
			bottom_p_4 <= bottom_p_3;
			

			//orange
			left_o_1 <= left_o;
			left_o_2 <= left_o_1;
			left_o_3 <= left_o_2;
			left_o_4 <= left_o_3;

			right_o_1 <= right_o;
			right_o_2 <= right_o_1;
			right_o_3 <= right_o_2;
			right_o_4 <= right_o_3;
			
			top_o_1 <= top_o;
			top_o_2 <= top_o_1;
			top_o_3 <= top_o_2;
			top_o_4 <= top_o_3;
			
			bottom_o_1 <= bottom_o;
			bottom_o_2 <= bottom_o_1;
			bottom_o_3 <= bottom_o_2;
			bottom_o_4 <= bottom_o_3;

			// green
			left_g_1 <= left_g;
			left_g_2 <= left_g_1;
			left_g_3 <= left_g_2;
			left_g_4 <= left_g_3;

			right_g_1 <= right_g;
			right_g_2 <= right_g_1;
			right_g_3 <= right_g_2;
			right_g_4 <= right_g_3;
			
			top_g_1 <= top_g;
			top_g_2 <= top_g_1;
			top_g_3 <= top_g_2;
			top_g_4 <= top_g_3;
			
			bottom_g_1 <= bottom_g;
			bottom_g_2 <= bottom_g_1;
			bottom_g_3 <= bottom_g_2;
			bottom_g_4 <= bottom_g_3;

			// black
			left_b_1 <= left_b;
			left_b_2 <= left_b_1;
			left_b_3 <= left_b_2;
			left_b_4 <= left_b_3;

			right_b_1 <= right_b;
			right_b_2 <= right_b_1;
			right_b_3 <= right_b_2;
			right_b_4 <= right_b_3;
			
			top_b_1 <= top_b;
			top_b_2 <= top_b_1;
			top_b_3 <= top_b_2;
			top_b_4 <= top_b_3;
			
			bottom_b_1 <= bottom_b;
			bottom_b_2 <= bottom_b_1;
			bottom_b_3 <= bottom_b_2;
			bottom_b_4 <= bottom_b_3;

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



wire [10:0] avg_left_r, avg_right_r, avg_top_r, avg_bottom_r;
wire [10:0] avg_left_p, avg_right_p, avg_top_p, avg_bottom_p;
wire [10:0] avg_left_o, avg_right_o, avg_top_o, avg_bottom_o;
wire [10:0] avg_left_g, avg_right_g, avg_top_g, avg_bottom_g;
wire [10:0] avg_left_b, avg_right_b, avg_top_b, avg_bottom_b;

assign avg_left_r = (left_r + left_r_1 + left_r_2 + left_r_3 + left_r_4) / 5;
assign avg_right_r = (right_r + right_r_1 + right_r_2 + right_r_3 + left_r_4) / 5;
assign avg_top_r = (top_r + top_r_1 + top_r_2 + top_r_3 + top_r_4) / 5;
assign avg_bottom_r = (bottom_r + bottom_r_1 + bottom_r_2 + bottom_r_3 + bottom_r_4) / 5;

assign avg_left_p = (left_p + left_p_1 + left_p_2 + left_p_3 + left_p_4) / 5;
assign avg_right_p = (right_p + right_p_1 + right_p_2 + right_p_3 + left_p_4) / 5;
assign avg_top_p = (top_p + top_p_1 + top_p_2 + top_p_3 + top_p_4) / 5;
assign avg_bottom_p = (bottom_p + bottom_p_1 + bottom_p_2 + bottom_p_3 + bottom_p_4) / 5;

assign avg_left_o = (left_o + left_o_1 + left_o_2 + left_o_3 + left_o_4) / 5;
assign avg_right_o = (right_o + right_o_1 + right_o_2 + right_o_3 + left_o_4) / 5;
assign avg_top_o = (top_o + top_o_1 + top_o_2 + top_o_3 + top_o_4) / 5;
assign avg_bottom_o = (bottom_o + bottom_o_1 + bottom_o_2 + bottom_o_3 + bottom_o_4) / 5;

assign avg_left_g = (left_g + left_g_1 + left_g_2 + left_g_3 + left_g_4) / 5;
assign avg_right_g = (right_g + right_g_1 + right_g_2 + right_g_3 + left_g_4) / 5;
assign avg_top_g = (top_g + top_g_1 + top_g_2 + top_g_3 + top_g_4) / 5;
assign avg_bottom_g = (bottom_g + bottom_g_1 + bottom_g_2 + bottom_g_3 + bottom_g_4) / 5;

assign avg_left_b = (left_b + left_b_1 + left_b_2 + left_b_3 + left_b_4) / 5;
assign avg_right_b = (right_b + right_b_1 + right_b_2 + right_b_3 + left_b_4) / 5;
assign avg_top_b = (top_b + top_b_1 + top_b_2 + top_b_3 + top_b_4) / 5;
assign avg_bottom_b = (bottom_b + bottom_b_1 + bottom_b_2 + bottom_b_3 + bottom_b_4) / 5;
	
	
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
						
////////////////////////////////////////////////////////////////////
// SPI Transimitioin
////////////////////////////////////////////////////////////////////
// data formate 
// colour + coordinate  = {0'b0, colour(3 bits), 12 bits for x_coordinate}
// colour + distance    = {0'b1, colour(3 bits), 12 bits for distance    }

wire formate_r, formate_p, formate_g, formate_o,												formate_b;
wire distance_r, distance_p, distance_g, distance_o,                                            distance_b;
wire valid_r, valid_p, valid_g, valid_o,                     								    valid_b;
wire red_center_x_pixel, pink_center_x_pixel, green_center_x_pixel, orange_center_x_pixel,		black_center_x_pixel;

distance_cal red_ball( 
	.left_bound(x_min_r), 
	.right_bound(x_max_r), 
	.valid(valid_r),
    .formate(formate_r), 
	.target_center_x_pixel(red_center_x_pixel),
	.distance(distance_r) 
);
distance_cal pink_ball( 
	.left_bound(x_min_p),
	.right_bound(x_max_p),
	.formate(formate_p), 
	.target_center_x_pixel(pink_center_x_pixel),
	.distance(distance_p) 
);
distance_cal green_ball(
    .left_bound(x_min_g),
    .right_bound(x_max_g),
    .formate(formate_g),
    .target_center_x_pixel(green_center_x_pixel),
	.distance(distance_g) 
);
distance_cal orange_ball(
    .left_bound(x_min_o),
    .right_bound(x_max_o),
    .formate(formate_o),
    .target_center_x_pixel(orange_center_x_pixel),
	.distance(distance_o) 
);

wire [11:0] c_1,c_2,c_3,c_4,c_5;
wire [2:0] data_colour;
// reg [15:0] message_to_ESP32;ss
assign c_1 = (valid_r && distance_r)? distance_r : 12'b111111111111;
assign c_2 = (valid_p && distance_p < c_1) ? distance_p : c_1;
assign c_3 = (valid_g && distance_g < c_2) ? distance_g : c_2;
assign c_4 = (valid_o && distance_o < c_3) ? distance_o : c_3;
assign c_5 = (valid_b && distance_b < c_4) ? distance_b : c_4;

assign data_colour = (c_5 == distance_r) ? 3'b000 :
					 (c_5 == distance_p) ? 3'b001 :
					 (c_5 == distance_g) ? 3'b001 :
					 (c_5 == distance_o) ? 3'b010 :
					 (c_5 == distance_b) ? 3'b100 : 3'b111;
					 
always @(*) begin
	case(data_colour) 
		0 : message_to_ESP32 = (formate_r)? {1'b0, data_colour, distance_r}: {1'b1, data_colour, red_center_x_pixel};
		1 : message_to_ESP32 = (formate_p)? {1'b0, data_colour, distance_p}: {1'b1, data_colour, pink_center_x_pixel};
		2 : message_to_ESP32 = (formate_g)? {1'b0, data_colour, distance_g}: {1'b1, data_colour, green_center_x_pixel};
		3 : message_to_ESP32 = (formate_o)? {1'b0, data_colour, distance_o}: {1'b1, data_colour, orange_center_x_pixel};
		4 : message_to_ESP32 = (formate_b)? {1'b0, data_colour, distance_b}: {1'b1, data_colour, black_center_x_pixel};
		default : message_to_ESP32 = 0;
	endcase
end

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

endmodule




