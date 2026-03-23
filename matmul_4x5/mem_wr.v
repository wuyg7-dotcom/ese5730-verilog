`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/23 16:12:07
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
    parameter integer DEPTH = 20,
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
    reg        frame_active_d;

    wire frame_active      = ~cs_n;
    wire frame_start_pulse =  frame_active & ~frame_active_d;
    wire frame_end_pulse   = ~frame_active &  frame_active_d;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt            <= {(AW+1){1'b0}};
            loaded         <= 1'b0;
            error          <= 1'b0;
            mem_a_we       <= 1'b0;
            mem_a_addr     <= {AW{1'b0}};
            mem_a_wdata    <= 8'd0;
            frame_active_d <= 1'b0;
        end else begin
            mem_a_we       <= 1'b0;
            frame_active_d <= frame_active;

            // 新 frame 开始：清状态，准备重新接收 DEPTH 个字节
            if (frame_start_pulse) begin
                cnt    <= {(AW+1){1'b0}};
                loaded <= 1'b0;
                error  <= 1'b0;
            end

            // frame 进行中：每收到 1 个有效 byte，顺序写入 memory
            if (frame_active && sys_ready && byte_valid) begin
                if (cnt < DEPTH) begin
                    mem_a_we    <= 1'b1;
                    mem_a_addr  <= cnt[AW-1:0];
                    mem_a_wdata <= byte_in;
                    cnt         <= cnt + {{AW{1'b0}}, 1'b1};
                end else begin
                    // 超过 DEPTH 还继续送数据，报错
                    error <= 1'b1;
                end
            end

            // frame 结束：必须刚好收到 DEPTH 个字节才算 loaded 成功
            if (frame_end_pulse) begin
                if (cnt == DEPTH)
                    loaded <= 1'b1;
                else if (cnt != 0)
                    error <= 1'b1;
            end
        end
    end
endmodule
