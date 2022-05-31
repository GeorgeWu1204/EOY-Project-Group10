module distance_cal
(
    //input [7:0] height_rt_cam,
    //input [7:0] cali_size,
    //input [7:0] cali_distance,
    input [10:0] left_bound,
    input [10:0] right_bound,
    input eop,

    output valid,
    output formate,
    output [11:0] target_center_x_pixel,
    output reg [11:0] distance
    //output [7:0] distance,
    // output [7:0] heigh 
);
parameter IMAGE_W = 11'd640;
parameter cali_size = 11'd70;
parameter cali_distance = 11'd30;

assign valid = (left_bound <= 30 && right_bound >= IMAGE_W - 30 )? 0 : (distance <= 50 && distance >= 25)? 1:0;
// formate = 0 :: center 
assign formate = ((left_bound + right_bound) >> 1 > 300) && ((left_bound + right_bound) >> 1 < 340);
assign target_center_x_pixel = (left_bound + right_bound) >> 1;
always @(*) begin
    if(eop)begin
        distance = (cali_size * cali_distance) / (right_bound - left_bound);
    end
end
endmodule


