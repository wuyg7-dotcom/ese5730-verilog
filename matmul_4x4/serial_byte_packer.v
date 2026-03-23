`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/02/18 20:59:59
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

module spi_lane_byte_rx #(
    parameter MSB_FIRST = 1   // 1: MSB-first, 0: LSB-first
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       cs_n,     // active low
    input  wire       din,      // 1-bit serial data
    input  wire       din_en,   // usually ~cs_n

    output reg [7:0]  byte_out,
    output reg        byte_valid
);
    reg [7:0] shreg;
    reg [2:0] bit_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            shreg      <= 8'd0;
            bit_cnt    <= 3'd0;
            byte_out   <= 8'd0;
            byte_valid <= 1'b0;
        end else begin
            byte_valid <= 1'b0;

            if (cs_n) begin
                shreg   <= 8'd0;
                bit_cnt <= 3'd0;
            end else if (din_en) begin
                if (MSB_FIRST) begin
                    shreg <= {shreg[6:0], din};
                end else begin
                    shreg <= {din, shreg[7:1]};
                end

                if (bit_cnt == 3'd7) begin
                    if (MSB_FIRST) byte_out <= {shreg[6:0], din};
                    else           byte_out <= {din, shreg[7:1]};
                    byte_valid <= 1'b1;
                    bit_cnt    <= 3'd0;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end
endmodule