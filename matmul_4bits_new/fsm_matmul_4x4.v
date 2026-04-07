`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 15:34:15
// Design Name: 
// Module Name: fsm_matmul_4x4
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

module fsm_matmul_4x4_simple #(
    parameter integer N = 4
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire        sys_ready,
    output reg         done,

    // -------- preload control
    output reg         preloadB_start,
    input  wire        preloadB_done_pulse,

    output reg         preloadA_start,
    input  wire        preloadA_done_pulse,

    // -------- dot engine
    output reg         start_ij,
    output reg  [1:0]  cur_i,
    output reg  [1:0]  cur_j,
    input  wire        dot_done_pulse,
    input  wire [9:0]  dot_sum,

    // -------- write-back C (16-bit)
    output reg         C_we,
    output reg  [3:0]  C_addr,
    output reg  [15:0] C_wdata
);

    function [3:0] addr_4x4;
        input [1:0] row;
        input [1:0] col;
        begin
            addr_4x4 = {row, 2'b00} + col; // row*4 + col
        end
    endfunction

    localparam S_IDLE   = 4'd0;
    localparam S_PRE_B  = 4'd1;
    localparam S_PRE_A  = 4'd2;
    localparam S_ISSUE  = 4'd3;
    localparam S_WAIT   = 4'd4;
    localparam S_WRITE  = 4'd5;
    localparam S_NEXTJ  = 4'd6;
    localparam S_NEXTI  = 4'd7;
    localparam S_DONE   = 4'd8;

    reg [3:0] state, next_state;

    // state register
    always @(posedge clk) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:   if (start && sys_ready)      next_state = S_PRE_B;
            S_PRE_B:  if (preloadB_done_pulse)     next_state = S_PRE_A;
            S_PRE_A:  if (preloadA_done_pulse)     next_state = S_ISSUE;
            S_ISSUE:                               next_state = S_WAIT;
            S_WAIT:   if (dot_done_pulse)          next_state = S_WRITE;
            S_WRITE:                               next_state = S_NEXTJ;

            S_NEXTJ:  if (cur_j == 2'd3)           next_state = S_NEXTI;
                      else                         next_state = S_ISSUE;

            S_NEXTI:  if (cur_i == 2'd3)           next_state = S_DONE;
                      else                         next_state = S_ISSUE;

            S_DONE:                                next_state = S_IDLE;
            default:                               next_state = S_IDLE;
        endcase
    end

    // output + datapath
    always @(posedge clk) begin
        if (!rst_n) begin
            done           <= 1'b0;
            start_ij       <= 1'b0;
            cur_i          <= 2'd0;
            cur_j          <= 2'd0;

            preloadB_start <= 1'b0;
            preloadA_start <= 1'b0;

            C_we           <= 1'b0;
            C_addr         <= 4'd0;
            C_wdata        <= 16'd0;
        end else begin
            done           <= 1'b0;
            start_ij       <= 1'b0;
            preloadB_start <= 1'b0;
            preloadA_start <= 1'b0;
            C_we           <= 1'b0;

            case (state)
                S_IDLE: begin
                    cur_i <= 2'd0;
                    cur_j <= 2'd0;
                end

                S_PRE_B: begin
                    preloadB_start <= 1'b1;
                end

                S_PRE_A: begin
                    preloadA_start <= 1'b1;
                end

                S_ISSUE: begin
                    start_ij <= 1'b1;
                end

                S_WRITE: begin
                    C_addr  <= addr_4x4(cur_i, cur_j);
                    C_wdata <= {6'b000000, dot_sum}; // 10-bit result -> 16-bit storage
                    C_we    <= 1'b1;
                end

                S_NEXTJ: begin
                    if (cur_j == 2'd3)
                        cur_j <= 2'd0;
                    else
                        cur_j <= cur_j + 2'd1;
                end

                S_NEXTI: begin
                    if (cur_i != 2'd3)
                        cur_i <= cur_i + 2'd1;
                end

                S_DONE: begin
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule

