module buildiing_distance_cal
(
    //input [7:0] height_rt_cam,
    //input [7:0] cali_size,
    //input [7:0] cali_distance,
    //change
	input clk,
    input [4:0] center_slot,
	input [4:0] left_slot,
	input [4:0] right_slot,
    input [10:0] f_slot_7_blackToWhite,
    input [10:0] f_slot_8_blackToWhite,
    input [10:0] f_slot_9_blackToWhite,
    input [10:0] f_slot_10_blackToWhite,

    input [10:0] f_slot_7_whiteToBlack,
    input [10:0] f_slot_8_whiteToBlack,
    input [10:0] f_slot_9_whiteToBlack,
    input [10:0] f_slot_10_whiteToBlack,
	//input [4:0] count_w_b, 
	//input [4:0] count_b_w,
	input [10:0] left_most_bound,
	input [10:0] right_most_bound,

    input eop,
    
    output reg valid,
    output reg formate,
    output reg [10:0] target_center_x_pixel,
    output reg [11:0] distance,
	output reg [11:0] diameter,
    
    output reg [10:0] slot_7,
    output reg [10:0] slot_8,
    output reg [10:0] slot_9,
    output reg [10:0] slot_10,

    output reg [1:0] slot_7_WB,
    output reg [1:0] slot_8_WB,
    output reg [1:0] slot_9_WB,
    output reg [1:0] slot_10_WB,
	output reg [10:0] stripe_width
    //output [7:0] distance,
    // output [7:0] heigh 
);
parameter IMAGE_W = 11'd640;
parameter cali_size = 11'd70;
parameter cali_distance = 11'd30;
// reg [10:0] slot_7, slot_8, slot_9, slot_10;
// reg slot_7_WB, slot_8_WB, slot_9_Wb, slot_10_WB;

reg [4:0] count_slots;
reg [10:9] left_slot_1, right_slot_1;
reg [11:0] total_slot;
reg [10:0] tmp_white_width, tmp_black_width;
reg [10:0] min_white_width, min_black_width;
reg [4:0] first_wb, first_bw;
wire [10:0] min_slot_7, min_slot_8, min_slot_9, min_slot_10;
reg [10:0] max_width_inside_slot;
//reg [4:0] count_tot_slots;

// formate = 0 :: center
wire [10:0] c_1, c_2, c_3, c_4;
assign min_slot_7 = (slot_7_WB == 3)? (f_slot_7_blackToWhite > f_slot_7_whiteToBlack) ? (f_slot_7_blackToWhite - f_slot_7_whiteToBlack) : (f_slot_7_whiteToBlack - f_slot_7_blackToWhite) : 0;
assign min_slot_8 = (slot_8_WB == 3)? (f_slot_8_blackToWhite > f_slot_8_whiteToBlack) ? (f_slot_8_blackToWhite - f_slot_8_whiteToBlack) : (f_slot_8_whiteToBlack - f_slot_8_blackToWhite) : 0;
assign min_slot_9 = (slot_9_WB == 3)? (f_slot_9_blackToWhite > f_slot_9_whiteToBlack) ? (f_slot_9_blackToWhite - f_slot_9_whiteToBlack) : (f_slot_9_whiteToBlack - f_slot_9_blackToWhite) : 0;
assign min_slot_10 = (slot_10_WB == 3)? (f_slot_10_blackToWhite > f_slot_10_whiteToBlack) ? (f_slot_10_blackToWhite - f_slot_10_whiteToBlack) : (f_slot_10_whiteToBlack - f_slot_10_blackToWhite) : 0;

// assign c_1 = min_slot_7;
// assign c_2 = ((min_slot_8 < c_1) && (min_slot_8 != 0)) ? min_slot_8 : c_1;
// assign c_3 = ((min_slot_9 < c_2) && (min_slot_9 != 0)) ? min_slot_9 : c_2;
// assign c_4 = ((min_slot_10 < c_3) && (min_slot_10 != 0)) ? min_slot_10 : c_3; 

assign c_1 = min_slot_7;
assign c_2 = (min_slot_8 > c_1) ? min_slot_8 : c_1;
assign c_3 = (min_slot_9 > c_2 ) ? min_slot_9 : c_2;
assign c_4 = (min_slot_10 > c_3) ? min_slot_10 : c_3; 
always @(*) begin
       
        //  <---- 7 --WB--> <----8--BW--> <----9-WB---> <----10--BW-->
        //  <---- 7 --BW--> <----8--WB--> <----9-BW---> <----10--WB-->
        //  <---- 7 --BW--> <----8--miss--> <----9-BW---> <----10--WB-->
        //  <---- 7---BW-> <----8----> <WB--9----> <---BW 10 ---->
        //  <---- 7---BW-> <----8----> <----9----> <---- WB----> gg miss2 or 
			
		
		slot_7 =(f_slot_7_blackToWhite != 0)? f_slot_7_blackToWhite : (f_slot_7_whiteToBlack != 0)? f_slot_7_whiteToBlack : 0;
		slot_7_WB = ((f_slot_7_blackToWhite != 0) && (f_slot_7_whiteToBlack != 0))? 3: 
					(f_slot_7_blackToWhite != 0)? 2 :
					(f_slot_7_whiteToBlack != 0)? 1 : 0;
		
		slot_8 = (f_slot_8_blackToWhite != 0)? f_slot_8_blackToWhite : (f_slot_8_whiteToBlack != 0)? f_slot_8_whiteToBlack : 0;
		slot_8_WB = ((f_slot_8_blackToWhite != 0) && (f_slot_8_whiteToBlack != 0))? 3: 
					(f_slot_8_blackToWhite != 0)? 2 : 
					(f_slot_8_whiteToBlack != 0)? 1 : 0;

		slot_9 = (f_slot_9_blackToWhite != 0)? f_slot_9_blackToWhite : (f_slot_9_whiteToBlack != 0)? f_slot_9_whiteToBlack : 0;
		slot_9_WB = ((f_slot_9_blackToWhite != 0) && (f_slot_9_whiteToBlack != 0))? 3: 
					(f_slot_9_blackToWhite != 0)? 2 : 
					(f_slot_9_whiteToBlack != 0)? 1 : 0;

		slot_10 = (f_slot_10_blackToWhite != 0)? f_slot_10_blackToWhite : (f_slot_10_whiteToBlack != 0)? f_slot_10_whiteToBlack : 0;
		slot_10_WB = 	((f_slot_7_blackToWhite != 0) && (f_slot_7_whiteToBlack != 0))? 3: 
						(f_slot_10_blackToWhite != 0)? 2 : 
						(f_slot_10_whiteToBlack != 0)? 1 : 0;
		
		
		first_wb = 0;
		first_bw = 0;
		tmp_white_width = 900;
		tmp_black_width = 900;
		min_white_width = 900;
		min_black_width = 900;
		max_width_inside_slot = 0;
		
		if(~(min_slot_7 != 0 || min_slot_8 != 0 || min_slot_9 != 0 || min_slot_10 != 0))  begin
			//slot 7 ------>
			if(slot_7_WB == 1)begin
				first_wb = 7;
			end
			else if(slot_7_WB == 2)begin
				first_bw = 7;
			end

			//slot 8 ------>
			if(slot_8_WB == 1)begin
				//wb detected
				if(first_bw != 0)begin
					//bw ------wb
					tmp_white_width = slot_8 - slot_7;
				end 
				//wb----wb
				first_wb = 8;
				if(min_white_width > tmp_white_width)begin
					min_white_width = tmp_white_width;
				end
			end

			else if(slot_8_WB == 2)begin
				//bw detected
				if(first_wb != 0)begin
					//wb ----bw
					tmp_black_width = slot_8 - slot_7;
				end
				//bw-----bw
				first_bw = 8;
				if(min_black_width > tmp_black_width)begin
					min_black_width = tmp_black_width;
				end
			end

			//slot 9 ------>
			if(slot_9_WB == 1)begin
				//wb detected
				if(first_bw != 0)begin
					if(first_bw == 7)begin
						//bw -----wb------wb? but min is already recorded ignore
						//bw -----?------wb
						tmp_white_width = slot_9 - slot_7;
					end
					else begin
						//first_bw == 8
						//-------bw------wb
						tmp_white_width = slot_9 - slot_8;
					end
					
				end
				first_wb = 9;
				if(min_white_width > tmp_white_width)begin
					min_white_width = tmp_white_width;
				end
			end
			else if(slot_9_WB == 2)begin
				//bw detected
				if(first_wb != 0)begin
					if(first_wb == 7)begin
						//wb------bw-------bw ignore
						tmp_black_width = slot_9 - slot_7;
					end
					else begin
						//first_wb == 8
						//------wb------bw
						tmp_black_width = slot_9 - slot_8;
					end
					
				end
				first_bw = 9;
				if(min_black_width > tmp_black_width)begin
					min_black_width = tmp_black_width;
				end
			end
		
			//slot10 ------>

			if(slot_10_WB == 1)begin
				//wb detected
				if(first_bw != 0)begin
					if(first_bw == 7)begin
						tmp_white_width = slot_9 - slot_7;
					end
					else if(first_bw == 8) begin
						tmp_white_width = slot_10 - slot_8;
					end
					else begin
						//first_bw == 9
						tmp_white_width = slot_10 - slot_9;
					end
				end
				if(min_white_width > tmp_white_width)begin
					min_white_width = tmp_white_width;
				end
			end
			else if(slot_10_WB == 2)begin
				//bw detected
				if(first_wb != 0)begin
					if(first_wb == 7)begin
						tmp_black_width = slot_10 - slot_7;
					end
					else if(first_wb == 8)begin
						tmp_black_width = slot_10 - slot_8;
					end
					else begin
						//first_wb == 9
						tmp_black_width = slot_10 - slot_9;
					end
				end
				if(min_black_width > tmp_black_width)begin
					min_black_width = tmp_black_width;
				end
			end
		end
		
end


always @(posedge clk) begin
    if(eop)begin
		left_slot_1 <= left_slot;
		right_slot_1 <= right_slot;
	end
end



always @(*) begin
    if(eop)begin
		stripe_width = (min_slot_7 != 0 || min_slot_8 != 0 || min_slot_9 != 0 || min_slot_10 != 0)? c_4 : (min_black_width> min_white_width) ? tmp_white_width : tmp_black_width;
        distance = ((cali_size * cali_distance) / (stripe_width*2));
        valid = 	(left_slot <= 1 && right_slot >= 15 )? 0 : // TODO:: this might effect two buildings
					//(right_bound - left_bound > 200)? 0:
					// (upper_bound >= 90) ? 0:
					(right_slot - left_slot <= 2)? 0 : 1;
					//(((left_slot_1 > left_slot) && (left_slot_1 - left_slot > 1))|| ((left_slot_1 <= left_slot) && (left_slot - left_slot_1 > 1)))? 0 :
					//(((right_slot_1 > right_slot) && (right_slot_1 - right_slot > 1)) || ((right_slot_1 <= right_slot) && (right_slot - right_slot_1 > 1)))? 0:
                 	//(distance <= 55 && distance >= 15)? 1:0;
			
        // formate = ((left_bound + right_bound) >> 1 > 260) && ((left_bound + right_bound) >> 1 < 380);
        // target_center_x_pixel = (left_bound + right_bound) >> 1;
        formate = (center_slot == 8 || center_slot == 9);
        target_center_x_pixel = 40 * center_slot - 20;
		//total_slot = count_b_w + count_w_b - 1;
		total_slot= ((right_most_bound - left_most_bound) / stripe_width );
		diameter = total_slot * 2;
		//diameter = total_slot;
    end
end
endmodule


