`timescale 1ns / 1ps

module dot_ij_engine_buf #(
    parameter integer DW    = 4,
    parameter integer DEPTH = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   start_ij,   // 1-cycle pulse
    input  wire [1:0]             i,
    input  wire [1:0]             j,

    output reg                    busy,
    output reg                    done_pulse,
    output reg  [9:0]             sum,

    input  wire [DEPTH*DW-1:0]    A_flat,
    input  wire [DEPTH*DW-1:0]    B_flat
);

    // 地址计算函数
    function [3:0] addr_4x4;
        input [1:0] row;
        input [1:0] col;
        begin
            addr_4x4 = {row, 2'b00} + col; // row*4 + col
        end
    endfunction

    // 状态机编码
    localparam D_IDLE = 2'd0;
    localparam D_MAC  = 2'd1;
    localparam D_DONE = 2'd2;

    reg [1:0] state, next_state;
    reg [1:0] k;

    // 内部计算连线
    wire [3:0] a_idx;
    wire [3:0] b_idx;
    wire [DW-1:0] a_val;
    wire [DW-1:0] b_val;
    wire [2*DW-1:0] mult; // 4x4 -> 8-bit

    // 组合逻辑连接
    assign a_idx = addr_4x4(i, k);
    assign b_idx = addr_4x4(k, j);

    assign a_val = A_flat[a_idx*DW +: DW];
    assign b_val = B_flat[b_idx*DW +: DW];

    // 乘法器实现
    assign mult = a_val * b_val;

    // 状态转移逻辑 (已修改为同步复位)
    always @(posedge clk) begin // 删除了 or negedge rst_n
        if (!rst_n)
            state <= D_IDLE;
        else
            state <= next_state;
    end

    // 下一状态组合逻辑 (保持不变，因为是组合逻辑 @*)
    always @(*) begin
        next_state = state;
        case (state)
            D_IDLE: begin
                if (start_ij) 
                    next_state = D_MAC;
                else 
                    next_state = D_IDLE;
            end
            D_MAC: begin
                if (k == 2'd3) 
                    next_state = D_DONE;
                else 
                    next_state = D_MAC;
            end
            D_DONE: begin
                next_state = D_IDLE;
            end
            default: begin
                next_state = D_IDLE;
            end
        endcase
    end

    // 数据通路与控制逻辑 (已修改为同步复位)
    always @(posedge clk) begin // 删除了 or negedge rst_n
        if (!rst_n) begin
            busy        <= 1'b0;
            done_pulse  <= 1'b0;
            sum         <= 10'd0;
            k           <= 2'd0;
        end else begin
            done_pulse <= 1'b0;

            case (state)
                D_IDLE: begin
                    busy <= 1'b0;
                    if (start_ij) begin
                        busy <= 1'b1;
                        sum  <= 10'd0; 
                        k    <= 2'd0;
                    end
                end

                D_MAC: begin
                    busy <= 1'b1;
                    // 显式补零拼接逻辑保持不变
                    sum  <= sum + {{ (10-(2*DW)) {1'b0} }, mult};
                    
                    if (k == 2'd3)
                        k <= 2'd0;
                    else
                        k <= k + 2'd1;
                end

                D_DONE: begin
                    busy        <= 1'b0;
                    done_pulse  <= 1'b1;
                end

                default: begin
                    busy        <= 1'b0;
                    done_pulse  <= 1'b0;
                end
            endcase
        end
    end

endmodule