module buildiing_distance_cal
(
    input [10:0] left_bound,
    input [10:0] right_bound,
    input [10:0] upper_bound,
    input [10:0] lower_bound,
    input eop,
    output reg valid,
    output reg formate,
    output reg [10:0] target_center_x_pixel,
    output reg [10:0] distance
    //output [7:0] distance,
    // output [7:0] heigh 
);
parameter IMAGE_W = 11'd640;
parameter cali_size = 11'd70;
parameter cali_distance = 11'd30;
// diameter = 10
// formate = 0 :: center 
always @(*) begin
    if(eop)begin
      
        distance = (cali_size * cali_distance) / (upper_bound - lower_bound);
        valid =     (left_bound <= 30 && right_bound >= IMAGE_W - 30 )? 0 :
                    (right_bound - left_bound > 200)? 0:
                //  (upper_bound >= 90) ? 0:
                    (distance <= 55 && distance >= 15)? 1:0;
        formate = ((left_bound + right_bound) >> 1 > 260) && ((left_bound + right_bound) >> 1 < 380);
        target_center_x_pixel = (left_bound + right_bound) >> 1;
    end
end
endmodule


