`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/01/2026 08:58:44 PM
// Design Name: 
// Module Name: led_counter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module led_counter(
    input   clk,
    input   reset_n,
    output  [7:0]LED
    );
    // 50 mhz clock, 15ns period
    // 1usec pulse = 1usec/15ns = 15,0000 clk cycles = 1usec
    // 15,000 cycles = 3A98h
    localparam  MAX_COUNT = 32'h017D783F;
    logic       [24:0]  count = 0;
    logic       [7:0]   led_reg = 8'h01;
    logic       shift;

    always_ff @(posedge clk) begin
        if(reset_n == 1'b0) begin
            count <= 0;
            shift <= 1'b0;
        end
        else if(MAX_COUNT == count) begin
            shift <= 1'b1;
            count <= 0;
        end
        else begin
            shift <= 1'b0;   
            count <= count + 1'b1;
        end
    end

    always_ff @( posedge clk ) begin
        if (shift == 1'b1)
            led_reg <= {led_reg[6:0], led_reg[7]};
    end

    assign LED = led_reg;
endmodule
