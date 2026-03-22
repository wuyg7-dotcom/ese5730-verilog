`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 18:12:14
// Design Name: 
// Module Name: mem_wr
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

module spi_lane_mem_writer #(
    parameter integer DEPTH = 25,
    parameter integer AW    = 5
)(
    input  wire          clk,
    input  wire          rst_n,

    input  wire          cs_n,
    input  wire          sys_ready,

    input  wire [7:0]    byte_in,
    input  wire          byte_valid,

    output reg           loaded,
    output reg           error,

    output reg           mem_a_we,
    output reg [AW-1:0]  mem_a_addr,
    output reg [7:0]     mem_a_wdata
);
    reg [AW:0] cnt;
    wire frame_active = ~cs_n;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt        <= 0;
            loaded     <= 0;
            error      <= 0;
            mem_a_we   <= 0;
            mem_a_addr <= 0;
            mem_a_wdata<= 0;
        end else begin
            mem_a_we <= 0;

            if (!frame_active) begin
                // frame结束：检查是否刚好写满25个字节
                if (cnt == DEPTH)
                    loaded <= 1;
                else if (cnt != 0)
                    error <= 1;
            end else if (sys_ready && byte_valid) begin
                if (cnt < DEPTH) begin
                    mem_a_we    <= 1;
                    mem_a_addr  <= cnt[AW-1:0];
                    mem_a_wdata <= byte_in;
                    cnt         <= cnt + 1;
                end else begin
                    error <= 1;
                end
            end
        end
    end
endmodule
