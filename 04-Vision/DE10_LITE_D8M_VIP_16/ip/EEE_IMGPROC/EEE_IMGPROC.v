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
	mode
	
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

////////////////////////////////////////////////////////////////////////
//
//HSV and Luminance



parameter IMAGE_W = 11'd640;
parameter IMAGE_H = 11'd480;
parameter MESSAGE_BUF_MAX = 256;
parameter MSG_INTERVAL = 6;
parameter BB_COL_DEFAULT = 24'h00ff00;

wire [7:0]   red, green, blue, grey;
wire [7:0]   red_out, green_out, blue_out;

wire         sop, eop, in_valid, out_ready;
////////////////////////////////////////////////////////////////////////
wire red_detected, green_detected, pink_detected, orange_detected;
wire [23:0] color_high;
reg [7:0] min_value;
reg [8:0] hue;
reg [7:0] luminosity;
reg [7:0] saturation;

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
		smooth_green = Red_stage_5;
		smooth_blue = Red_stage_5;
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
///////////////////////////////////////////////////
// 1D Edge Detection
//////////////////////////////////////////////////

wire [14:0] L_r, L_g, L_b; 
wire [7:0] L;
// Luminance = 0.3R + 0.59G + 0.11B 
assign L_r = 39 * smooth_red;
assign L_g = 75 * smooth_green;
assign L_b = 14 * smooth_blue;
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
	if (x > IMAGE_W-11'h5) begin
		h_edge = 0;
	end 
	else begin
		h_edge = L_5 + L_4 - L_2 - L_1;
	end
	//assign h_edge_detected = (h_edge[8]==0)? h_edge > 0.5 : (-1 * h_edge) > 0.5;
	if (h_edge[8] == 0) begin
		if (h_edge > 5) begin
			h_edge_detected = 1;

		end
		else begin
			h_edge_detected = 0;
		end
	end
	if (h_edge[8] == 1) begin
		if (h_edge < -5) begin
			h_edge_detected = 1;

		end
		else begin
			h_edge_detected = 0;
		end
	end
end



// always @(posedge clk) begin
// 	if(sop & in_valid) begin 
// 		x_min_o <= IMAGE_W-11'h1;
// 		x_max_o <= 0;
// 		y_min_o <= IMAGE_H-11'h1;
// 		y_max_o <= 0;
// 	end

// 	if(x >= 1 && x <= N-1 && y >=1) begin
// 		if(final_g_x) begin
// 				if (x < x_min_o) x_min_o <= x;
// 				if (x > x_max_o) x_max_o <= x;		
// 		end 
// 		else if(g_angle == 0 && g_strength > 150) begin
// 				if (y-2 < y_min_o) y_min_o <= y-2;
// 				if (y-2 > y_max_o) y_max_o <= y-2;
// 		end
// 	end 
// end

///////////////////////////////////////////////////////////////////////
//sobel filter (Canny)
///////////////////////////////////////////////////////////////////////

// reg valid_filtered;
// parameter N = IMAGE_W;	//Image columns
// parameter M = IMAGE_H;	//Image rows
// parameter K = 3; 	//Kernel size
// always @(*) begin
	
// 	if( 1 < x < IMAGE_W - 1)begin
// 		valid_filtered = 1;
// 		can_input11 = L_Storage[3][x - 1];
// 		can_input12 = L_Storage[3][ x ];
// 		can_input13 = L_Storage[3][x + 1];
// 		can_input21 = L_Storage[2][x - 1];
// 		can_input22 = L_Storage[2][ x ];
// 		can_input23 = L_Storage[2][x + 1];
// 		can_input31 = L_Storage[1][x - 1];
// 		can_input32 = L_Storage[1][ x ];
// 		can_input33 = L_Storage[1][ x + 1 ];
// 	end
// 	else if ( x < 1 || x > 1) begin
// 		valid_filtered = 0;
// 	end 
// 	else if(x > K*N && x < (IMAGE_W*IMAGE_H)+1) begin
// 			if((x == 1 ||x == N-1 )) begin
// 				valid_filtered = 0;
// 			end else valid_filtered = 1;
// 	end
// 	else begin
// 			valid_filtered = 0;
// 	end
// end 

// wire [7:0] g_strength, g_angle;


// canny cy(
// 		.row1_1_input(can_input11), .row1_2_input(can_input12), .row1_3_input(can_input13),
//         .row2_1_input(can_input21), .row2_2_input(can_input22), .row2_3_input(can_input23),
//         .row3_1_input(can_input31), .row3_2_input(can_input32), .row3_3_input(can_input33),
//         .gradient_strength(g_strength), .gradient_angle(g_angle)
// 		); 
// wire g_x,g_y,final_g_x;
// assign g_x = (g_strength > 150 && g_angle == 90);	
//assign g_y = (g_strength > 150 && g_angle == 0);

// reg g_strength_x_1, g_strength_x_2, g_strength_x_3;
//reg g_strength_y_1, g_strength_y_2, g_strength_y_3;

// always@(*) begin
// 	g_strength_x_1 <= g_x;
// 	g_strength_x_2 <= g_strength_x_1;
// 	g_strength_x_3 <= g_strength_x_2;

	// g_strength_y_1 <= g_y;
	// g_strength_y_2 <= g_strength_y_1;
	// g_strength_y_3 <= g_strength_y_2;
//end



//assign final_g_x = g_strength_x_1 && g_strength_x_2 && g_strength_x_3;

//assign final_g_y = g_strength_y_1 && g_strength_y_2 && g_strength_y_3;

// always @(posedge clk) begin
// 	if(sop & in_valid) begin 
// 		x_min_o <= IMAGE_W-11'h1;
// 		x_max_o <= 0;
// 		y_min_o <= IMAGE_H-11'h1;
// 		y_max_o <= 0;
// 	end

// 	if(x >= 1 && x <= N-1 && y >=1) begin
// 		if(final_g_x) begin
// 				if (x < x_min_o) x_min_o <= x;
// 				if (x > x_max_o) x_max_o <= x;		
// 		end 
// 		else if(g_angle == 0 && g_strength > 150) begin
// 				if (y-2 < y_min_o) y_min_o <= y-2;
// 				if (y-2 > y_max_o) y_max_o <= y-2;
// 		end
// 	end 
// end

//luminance buffer

// reg [7:0] L_Storage [0:3][0:IMAGE_W - 1];
// integer  i;
// always @(posedge clk) begin
// 	//fill L_Storage[0]
// 	L_Storage[0][0] <= L;
// 	for (i = 0; i < IMAGE_W - 1 ; i = i+1) begin
// 		L_Storage[0][i + 1] <= L_Storage[0][i];
// 	end
// end



//Hue = Red is Max Hue = (G-B)/(max-min)
//      Green is Max Hue = 2.0 + (B-R)/(max-min)
//		Blue is Max  Hue = 4.0 + (R-G)/(max-min)


//simon hue
//assign max_color = (red >= green && red >= blue) ? 0 : (green >= red && green >= blue ) ? 1 : (blue >= red && blue >= green) ? 2 : 3;
// wire [7:0] value, min;
// assign value = (smooth_red > smooth_green) ? ((smooth_red > smooth_blue) ? smooth_red[7:0] : smooth_blue[7:0]) : (smooth_green > smooth_blue) ? smooth_green[7:0] : smooth_blue[7:0];
// assign min = (smooth_red < smooth_green)? ((smooth_red<smooth_blue) ? smooth_red[7:0] : smooth_blue[7:0]) : (smooth_green < smooth_blue) ? smooth_green[7:0] : smooth_blue[7:0];
// assign hue = (smooth_red == smooth_green && smooth_red == smooth_blue) ? 0 :((value != smooth_red)? (value != smooth_green) ? (((240*((value - min))+ (60* (smooth_red - smooth_green)))/(value-min))>>1):
//                 ((120*(value-min)+60*(smooth_blue - smooth_red))/(value - min)>>1): 
//                 (smooth_blue < smooth_green) ? ((60*(smooth_green - smooth_blue)/(value - min))>>1): (((360*(value-min) +(60*(smooth_green - smooth_blue)))/(value - min))>>1));
reg luminosity_1 [7:0];
wire [7:0] L_out_l;
always @(*) begin
	if (smooth_red >= smooth_green && smooth_red >= smooth_blue) begin
		// min_value = (smooth_green >= smooth_blue)? smooth_blue : smooth_green
		if(smooth_green >= smooth_blue)begin
			hue = 60 * (smooth_green - smooth_blue) / (smooth_red - smooth_blue);
			luminosity = (smooth_red + smooth_blue)>>1;
			if(luminosity == 255)begin
				saturation = 0; 
			end
			else begin
				saturation = 255 * (smooth_red - smooth_blue) / (255 - L_out_l);
			end			
		end
		else begin
			hue = 60 * (6 - (smooth_blue - smooth_green) / (smooth_red - smooth_green));
			luminosity = (smooth_red + smooth_green)>>1;
			if (luminosity == 255) begin
				saturation = 0; 
			end
			else begin
				saturation = 255 * (smooth_red - smooth_green) / (255 - L_out_l);
			end
		end
		
	end
	else if (smooth_green >= smooth_red && smooth_green >= smooth_blue ) begin
		if(smooth_blue >= smooth_red)begin
			hue = 60 * (2 + (smooth_blue-smooth_red) / (smooth_green - smooth_red));
			luminosity = (smooth_green + smooth_red)>>1;
			if(luminosity == 255) begin
				saturation = 0 ;
			end
			else begin
				saturation = 255 * (smooth_green - smooth_red) / (255 - L_out_l);
			end	
		end 
		else begin
			hue = 60 * (2 - (smooth_red-smooth_blue) / (smooth_green - smooth_blue));
			luminosity = (smooth_green + smooth_blue)>>1;
			if(luminosity == 255)begin
				saturation = 0 ;
			end
			else begin
				saturation = 255 * (smooth_green + smooth_blue) / (255 - L_out_l);
			end	
		end
	end 
	else if (smooth_blue >= smooth_red && smooth_blue >= smooth_green) begin
		if(smooth_green >= smooth_red)begin
			hue = 60* (4 - ((smooth_green-smooth_red) / (smooth_blue - smooth_red)));
			luminosity = (smooth_blue + smooth_red)>>1;
			if(luminosity == 255)begin
				saturation = 0 ;
			end
			else begin
				saturation = 255 * (smooth_blue - smooth_red) / (255 - L_out_l);
			end	
		end else begin
			hue = 60 * (4 + ((smooth_red-smooth_green) / (smooth_blue - smooth_green)));
			luminosity = (smooth_blue + smooth_green)>>1;
			if(luminosity == 255)begin
				saturation = 0 ;
			end
			else begin
				saturation = 255 * (smooth_blue - smooth_green) / (255 - L_out_l);
			end	
		end
	end
	else begin
		// undefined
	end
	
end
// 0 red ma
// 1 green max
// 2 blue max
// 4 error
reg red_detected_1,red_detected_2,red_detected_3; //red_detected_4, red_detected_5, red_detected_6;
reg pink_detected_1,pink_detected_2,pink_detected_3; //pink_detected_4, pink_detected_5, pink_detected_6;
reg green_detected_1,green_detected_2,green_detected_3; // green_detected_4, green_detected_5, green_detected_6;
reg orange_detected_1, orange_detected_2, orange_detected_3; // orange_detected_4, orange_detected_5, orange_detected_6;


initial begin
	red_detected_1 = 0;
	red_detected_2 = 0;
	red_detected_3 = 0;
	// red_detected_4 = 0;
	// red_detected_5 = 0;
	// red_detected_6 = 0;
	
	pink_detected_1 = 0;
	pink_detected_2 = 0;
	pink_detected_3 = 0;
	// pink_detected_4 = 0;
	// pink_detected_5 = 0;
	// pink_detected_6 = 0;

	green_detected_1 = 0;
	green_detected_2 = 0;
	green_detected_3 = 0;
	// green_detected_4 = 0;
	// green_detected_5 = 0;
	// green_detected_6 = 0;

	
	orange_detected_1 = 0;
	orange_detected_2 = 0;
	orange_detected_3 = 0;
	// orange_detected_4 = 0;
	// orange_detected_5 = 0;
	// orange_detected_6 = 0;

end
always @(posedge clk)begin
	red_detected_1 <= red_detected;
	red_detected_2 <= red_detected_1;
	red_detected_3 <= red_detected_2;
	// red_detected_4 <= red_detected_3;
	// red_detected_5 <= red_detected_4;
	// red_detected_6 <= red_detected_5;
	
	pink_detected_1 <= pink_detected;
	pink_detected_2 <= pink_detected_1;
	pink_detected_3 <= pink_detected_2;
	// pink_detected_4 <= pink_detected_3;
	// pink_detected_5 <= pink_detected_4;
	// pink_detected_6 <= pink_detected_5;
	
	green_detected_1 <= green_detected;
	green_detected_2 <= green_detected_1;
	green_detected_3 <= green_detected_2;
	// green_detected_4 <= green_detected_3;
	// green_detected_5 <= green_detected_4;
	// green_detected_6 <= green_detected_5;
	
	orange_detected_1 <= orange_detected;
	orange_detected_2 <= orange_detected_1;
	orange_detected_3 <= orange_detected_2;
	// orange_detected_4 <= orange_detected_3;
	// orange_detected_5 <= orange_detected_4;
	// orange_detected_6 <= orange_detected_5;

end

wire red_final_detected, pink_final_detected, green_final_detected, orange_final_detected;
assign red_final_detected = red_detected_1 && red_detected_2 && red_detected_3; //&& red_detected_4 && red_detected_5 && red_detected_6;
assign pink_final_detected = pink_detected_1 && pink_detected_2 && pink_detected_3; //&& pink_detected_4 && pink_detected_5 && pink_detected_6;
assign green_final_detected = green_detected_1 && green_detected_2 && green_detected_3; //&& green_detected_4 && green_detected_5 && green_detected_6;
assign orange_final_detected = orange_detected_1 && orange_detected_2 && orange_detected_3; //&& orange_detected_4 && orange_detected_5 && orange_detected_6;

assign red_detected =   (hue >= 340 || hue <= 22)&&( saturation >= 178 && saturation <= 230) &&(luminosity >= 70 && luminosity <= 170) ||
					    (hue >= 5 && hue <= 22) && (saturation >= 191 && saturation <= 230)  && (luminosity >= 70 && luminosity <= 153);
//(hue >= 335 || hue <= 10)  && (saturation >= 153 && saturation <= 255)  && (luminosity >= 102 && luminosity <= 153)||
//(hue >= 335 || hue <= 10) && (saturation > 75) && (saturation > 51) ||


assign pink_detected  = (hue >= 270 && hue <= 320) && (saturation >= 102 && saturation <= 255)  && (saturation >= 179 && saturation <= 204) ||
						(hue >= 335 || hue <= 10) && (saturation > 75) && (saturation > 51)||
						(hue >= 335 || hue <= 10)  && (saturation >= 153 && saturation <= 255)  && (luminosity >= 179 && luminosity <= 204) ||
						(hue >= 335 || hue <= 10) && (saturation >= 100);

assign green_detected =
						(hue >= 150 && hue <= 180) && (saturation >= 100 && saturation <= 179) && (luminosity >= 51 && luminosity <= 120) ||
 						(hue >= 150 && hue <= 180) && (saturation >= 70 && saturation <= 170) && (luminosity >= 10 && luminosity <= 120); 
						
					//(hue >= 80 && hue <= 160) && (saturation >= 128 && saturation <= 255) && (luminosity >= 51 && luminosity <= 153);
					//  (hue >= 80 && hue <= 160);
					//	(hue >= 80 && hue <= 160) && (saturation >= 128 && saturation <= 255);
					//  (hue >= 80 && hue <= 160) && (luminosity >= 51 && luminosity <= 153);
					

assign orange_detected  = 
//(hue >= 30 && hue <= 55) && (saturation >= 100 && saturation <= 240) && (luminosity >= 127 && luminosity <= 230) ||
//						  (hue >= 25 && hue <= 60) && (saturation >= 80 && saturation <= 240) && (luminosity >= 70 && luminosity <= 242) ||
						  //yellow light
						   (hue >= 25 && hue <= 65)  && (saturation >= 100);  //&& (saturation >= 100) && (luminosity >= 200);
						  
 						//(hue >= 30 && hue <= 55);
						//(hue >= 30 && hue <= 55) && (luminosity >= 179 && luminosity <= 230);
						//(hue >= 30 && hue <= 55) && (saturation >= 100 && saturation <= 240);

// (hue >= 25 && hue <= 50) && (saturation >= 153 && saturation <= 255) && (luminosity >= 128 && luminosity <= 179);

// RED   ::: 355° to 10°
// Greem ::: 81° to 140°
// pink  ::: 331° to 331° 
// orange  ::: 221° to 240°
// Find boundary of cursor box
// Highlight detected areas


assign grey = green[7:1] + red[7:2] + blue[7:2]; //Grey = green/2 + red/4 + blue/4

assign color_high  =  (red_final_detected) ? {8'hff, 8'h0, 8'h0} : 
					  (green_final_detected) ? {8'h04,8'hbd,8'h42} :
					  (pink_final_detected) ? {8'hff,8'h00,8'h5d} :
					  (orange_final_detected) ? {8'hff,8'h77,8'h00} : {grey, grey, grey};

//red_high pure red if red_detect else grey.


// Show bounding box

wire [23:0] new_image;
wire bb_active_r, bb_active_g, bb_active_p, bb_active_o, bb_active_edge;

reg [10:0] left_r, left_p, left_g, left_o;
reg [10:0] right_r, right_p, right_g, right_o;
reg [10:0] top_r, top_p, top_g, top_o;
reg [10:0] bottom_r, bottom_p, bottom_g, bottom_o;
//reg [10:0] left_edge, right_edge, top_edge, bottom_edge;

assign bb_active_r = (x == left_r && left_r != IMAGE_W-11'h1) || (x == right_r && right_r != 0) || (y == top_r && top_r != IMAGE_H-11'h1) || (y == bottom_r && bottom_r != 0);
assign bb_active_p = (x == left_p && left_p != IMAGE_W-11'h1) || (x == right_p && right_p != 0) || (y == top_p && top_p != IMAGE_H-11'h1) || (y == bottom_p && bottom_p != 0);
assign bb_active_g = (x == left_g && left_g != IMAGE_W-11'h1) || (x == right_g && right_g != 0) || (y == top_g && top_g != IMAGE_H-11'h1) || (y == bottom_g && bottom_g != 0);
assign bb_active_o = (x == left_o && left_o != IMAGE_W-11'h1) || (x == right_o && right_o != 0) || (y == top_o && top_o != IMAGE_H-11'h1) || (y == bottom_o && bottom_o != 0);
//assign bb_active_edge = (x == left_edge && left_edge != IMAGE_W-11'h1) || (x == right_edge && right_edge != 0) || (y == top_edge && top_edge != IMAGE_H-11'h1) || (y == bottom_edge && bottom_edge != 0);

// active r = x = left_r |  && red_detected
assign new_image = 
//bb_active_edge ? {24'h00ff00} : {h_edge_detected_final_shifted,h_edge_detected_final_shifted,h_edge_detected_final_shifted};
//{h_edge_detected_final_shifted,h_edge_detected_final_shifted,h_edge_detected_final_shifted};
// bb_active_r ? {24'hff0000} : 
 bb_active_p ? {24'h00ff00} : color_high; 
// bb_active_g ? {24'h0000ff} : 
 //bb_active_o ? {24'hf0f0f0} : color_high;



// bb_col : green   red_high : red | grey
// Switch output pixels depending on mode switch
// Don't modify the start-of-packet word - it's a packet discriptor
// Don't modify data in non-video packets
//assign {red_out, green_out, blue_out} = red_detected? {8'hff, 8'h0, 8'h0} : {red,green,blue};
assign {red_out, green_out, blue_out} = (mode & ~sop & packet_video) ? new_image : 
//{h_edge_detected_final_shifted, h_edge_detected_final_shifted, h_edge_detected_final_shifted};
{red,green,blue};
// Toggling switch SW0 switch between raw camera data and a basic red image
//sop : start of packet 

//source reg data input 

//Count valid pixels to tget the image coordinates. Reset and detect packet type on Start of Packet.
reg [10:0] x, y;
reg packet_video;
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

			// move to upper layer
			// for (i = 0; i < IMAGE_W - 1 ; i = i+1) begin
			// 	L_Storage[1][i] <= L_Storage[0][i];
			// 	L_Storage[2][i] <= L_Storage[1][i];
			// 	L_Storage[3][i] <= L_Storage[2][i];
			// end
			// L_Storage[1] <= L_Storage [0];
			// L_Storage[2] <= L_Storage [1];
			// L_Storage[3] <= L_Storage [2];
			// L_Storage[4] <= L_Storage [3];
		end
		else begin
			x <= x + 11'h1;
		end
	end
end

// x,y represent position of a single pixel. Every clk 1 new pixel coming in.


//Find first and last red pixels
reg [10:0] x_min, y_min, x_max, y_max;
reg [10:0] x_min_r, x_min_p, x_min_g, x_min_o;
reg [10:0] y_min_r, y_min_p, y_min_g, y_min_o;
reg [10:0] x_max_r, x_max_p, x_max_g, x_max_o;
reg [10:0] y_max_r, y_max_p, y_max_g, y_max_o;

reg [10:0] edge_x_min, edge_x_max, edge_y_min, edge_y_max;

always@(posedge clk) begin
	if (red_final_detected & in_valid) begin	//Update bounds when the pixel is red
		if (x < x_min_r) x_min_r <= x;
		if (x > x_max_r) x_max_r <= x;
		if (y < y_min_r) y_min_r <= y;
		if (y > y_max_r) y_max_r <= y;
	end
	
	else if (green_detected & green_final_detected & in_valid) begin	//Update bounds when the pixel is red
		if (x < x_min_g) x_min_g <= x;
		if (x > x_max_g) x_max_g <= x;
		if (y < y_min_g) y_min_g <= y;
		if (y > y_max_g) y_max_g <= y;
	end

	else if (pink_detected & pink_final_detected & h_edge_detected_final & in_valid) begin	//Update bounds when the pixel is red
		if (x < x_min_p) x_min_p <= x;
		if (x > x_max_p) x_max_p <= x;
		if (y < y_min_p) y_min_p <= y;
		if (y > y_max_p) y_max_p <= y;
	end
	
	else if (orange_detected & orange_final_detected & h_edge_detected_final & in_valid) begin	//Update bounds when the pixel is red
		if (x < x_min_o) x_min_o <= x;
		if (x > x_max_o) x_max_o <= x;
		if (y < y_min_o) y_min_o <= y;
		if (y > y_max_o) y_max_o <= y;
	end

	// else if (h_edge_detected_final & in_valid) begin
	// 	if (x < edge_x_min) edge_x_min <= x;
	// 	if (x > edge_x_max) edge_x_max <= x;
	// 	if (y < edge_y_min) edge_y_min <= y;
	// 	if (y > edge_y_max) edge_y_max <= y;
	// end
	
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
		// edge_x_min <= IMAGE_W-11'h1;
		// edge_x_max <= 0;
		// edge_y_min <= IMAGE_H-11'h1;
		// edge_y_max <= 0;
	end
	//parameter IMAGE_W = 11'd640; IMAGE_H = 11'd480;
end

//Process bounding box at the end of the frame.
reg [1:0] msg_state;
reg [7:0] frame_count;
always@(posedge clk) begin
	if (eop & in_valid & packet_video) begin  //Ignore non-video packets
		//Latch edges for display overlay on next frame
		//if (red_detected) begin
			left_r <= x_min_r;
			right_r <= x_max_r;
			top_r <= y_min_r;
			bottom_r <= y_max_r;
		//end
		
		//else if (green_detected) begin
			left_g <= x_min_g;
			right_g <= x_max_g;
			top_g <= y_min_g;
			bottom_g <= y_max_g;
		//end
		
		//else if(pink_detected) begin
			left_p <= x_min_p;
			right_p <= x_max_p;
			top_p <= y_min_p;
			bottom_p <= y_max_p;
		//end

		//else if (orange_detected) begin
			left_o <= x_min_o;
			right_o <= x_max_o;
			top_o <= y_min_o;
			bottom_o <= y_max_o;
		//end

		
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
			msg_buf_in = `RED_BOX_MSG_ID;	//Message ID
			msg_buf_wr = 1'b1;
		end
		2'b10: begin
			msg_buf_in = {5'b0, x_min, 5'b0, y_min};	//Top left coordinate
			msg_buf_wr = 1'b1;
		end
		2'b11: begin
			msg_buf_in = {5'b0, x_max, 5'b0, y_max}; //Bottom right coordinate
			msg_buf_wr = 1'b1;
		end
	endcase
end

// two pipeline stages source to sink
//data-in D             data-out Q
//in_valid              out_valid
//ready_in   backpressure input from the next stage         ready_out backpressure output to the previous stage

//L_abs
L_abs luminosityN (
	.L_in(luminosity),
	.L_out(L_out_l)
	);


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