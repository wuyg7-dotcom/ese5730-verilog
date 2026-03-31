`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 18:03:01
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

module spi_lane_word5_rx #(
    parameter MSB_FIRST = 1   // 1: MSB-first, 0: LSB-first
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       cs_n,       // active low
    input  wire       din,        // 1-bit serial data
    input  wire       din_en,     // usually ~cs_n

    output reg [4:0]  word_out,
    output reg        word_valid
);
    reg [4:0] shreg;
    reg [2:0] bit_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            shreg      <= 5'd0;
            bit_cnt    <= 3'd0;
            word_out   <= 5'd0;
            word_valid <= 1'b0;
        end else begin
            word_valid <= 1'b0;

            if (cs_n) begin
                shreg   <= 5'd0;
                bit_cnt <= 3'd0;
            end else if (din_en) begin
                if (MSB_FIRST) begin
                    shreg <= {shreg[3:0], din};
                end else begin
                    shreg <= {din, shreg[4:1]};
                end

                if (bit_cnt == 3'd4) begin
                    if (MSB_FIRST)
                        word_out <= {shreg[3:0], din};
                    else
                        word_out <= {din, shreg[4:1]};

                    word_valid <= 1'b1;
                    bit_cnt    <= 3'd0;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end
endmodule