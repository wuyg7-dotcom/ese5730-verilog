`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 15:21:52
// Design Name: 
// Module Name: serial_byte_packer
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


module spi_lane_nibble_rx #(
    parameter MSB_FIRST = 1   // 1: MSB-first, 0: LSB-first
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       cs_n,       // active low
    input  wire       din,        // 1-bit serial data
    input  wire       din_en,     // usually ~cs_n

    output reg [3:0]  nibble_out,
    output reg        nibble_valid
);
    reg [3:0] shreg;
    reg [1:0] bit_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            shreg        <= 4'd0;
            bit_cnt      <= 2'd0;
            nibble_out   <= 4'd0;
            nibble_valid <= 1'b0;
        end else begin
            nibble_valid <= 1'b0;

            if (cs_n) begin
                shreg   <= 4'd0;
                bit_cnt <= 2'd0;
            end else if (din_en) begin
                if (MSB_FIRST) begin
                    shreg <= {shreg[2:0], din};
                end else begin
                    shreg <= {din, shreg[3:1]};
                end

                if (bit_cnt == 2'd3) begin
                    if (MSB_FIRST)
                        nibble_out <= {shreg[2:0], din};
                    else
                        nibble_out <= {din, shreg[3:1]};

                    nibble_valid <= 1'b1;
                    bit_cnt      <= 2'd0;
                end else begin
                    bit_cnt <= bit_cnt + 2'd1;
                end
            end
        end
    end
endmodule
