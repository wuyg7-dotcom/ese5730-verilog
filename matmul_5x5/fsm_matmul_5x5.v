`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 18:16:16
// Design Name: 
// Module Name: fsm_matmul_5x5
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


module fsm_matmul_5x5_simple #(
    parameter integer N = 5
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire        sys_ready,
    output reg         done,

    // -------- preload control
    output reg         preloadB_start,
    input  wire        preloadB_busy,
    input  wire        preloadB_done_pulse,

    output reg         preloadA_start,
    input  wire        preloadA_busy,
    input  wire        preloadA_done_pulse,

    // -------- dot engine
    output reg         start_ij,
    output reg  [2:0]  cur_i,
    output reg  [2:0]  cur_j,
    input  wire        dot_busy,
    input  wire        dot_done_pulse,
    input  wire [19:0] dot_sum,

    // -------- write-back C
    output reg         C_lo_we,
    output reg  [4:0]  C_lo_addr,
    output reg  [7:0]  C_lo_wdata,

    output reg         C_hi_we,
    output reg  [4:0]  C_hi_addr,
    output reg  [7:0]  C_hi_wdata,

    output reg         C_top_we,
    output reg  [4:0]  C_top_addr,
    output reg  [7:0]  C_top_wdata
);

    // ------------------------------------------------------------
    // address: row*5 + col
    // ------------------------------------------------------------
    function [4:0] addr_5x5;
        input [2:0] row;
        input [2:0] col;
        reg   [4:0] row5;
        begin
            row5 = {row,2'b00} + {2'b00,row}; // row*4 + row
            addr_5x5 = row5 + col;
        end
    endfunction

    // ------------------------------------------------------------
    // FSM states
    // ------------------------------------------------------------
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

    reg preB_fired;
    reg preA_fired;

    // ------------------------------------------------------------
    // state register
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    // ------------------------------------------------------------
    // next-state logic
    // ------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:   if (start && sys_ready) next_state = S_PRE_B;

            S_PRE_B:  if (preloadB_done_pulse) next_state = S_PRE_A;
            S_PRE_A:  if (preloadA_done_pulse) next_state = S_ISSUE;

            S_ISSUE:  next_state = S_WAIT;

            S_WAIT:   if (dot_done_pulse) next_state = S_WRITE;

            S_WRITE:  next_state = S_NEXTJ;

            S_NEXTJ:  if (cur_j == 3'd4) next_state = S_NEXTI;
                      else               next_state = S_ISSUE;

            S_NEXTI:  if (cur_i == 3'd4) next_state = S_DONE;
                      else               next_state = S_ISSUE;

            S_DONE:   next_state = S_IDLE;

            default:  next_state = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------
    // outputs + datapath
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            done           <= 1'b0;

            start_ij       <= 1'b0;
            cur_i          <= 3'd0;
            cur_j          <= 3'd0;

            preloadB_start <= 1'b0;
            preloadA_start <= 1'b0;
            preB_fired     <= 1'b0;
            preA_fired     <= 1'b0;

            C_lo_we        <= 1'b0;  C_lo_addr  <= 5'd0;  C_lo_wdata  <= 8'd0;
            C_hi_we        <= 1'b0;  C_hi_addr  <= 5'd0;  C_hi_wdata  <= 8'd0;
            C_top_we       <= 1'b0;  C_top_addr <= 5'd0;  C_top_wdata <= 8'd0;

        end else begin
            done           <= 1'b0;
            start_ij       <= 1'b0;
            preloadB_start <= 1'b0;
            preloadA_start <= 1'b0;

            C_lo_we  <= 1'b0;
            C_hi_we  <= 1'b0;
            C_top_we <= 1'b0;

            if (state != S_PRE_B && next_state == S_PRE_B) preB_fired <= 1'b0;
            if (state != S_PRE_A && next_state == S_PRE_A) preA_fired <= 1'b0;

            case (state)
                S_IDLE: begin
                    cur_i <= 3'd0;
                    cur_j <= 3'd0;
                end

                S_PRE_B: begin
                    if (!preB_fired) begin
                        preloadB_start <= 1'b1;
                        preB_fired     <= 1'b1;
                    end
                end

                S_PRE_A: begin
                    if (!preA_fired) begin
                        preloadA_start <= 1'b1;
                        preA_fired     <= 1'b1;
                    end
                end

                S_ISSUE: begin
                    start_ij <= 1'b1;
                end

                S_WRITE: begin
                    C_lo_addr   <= addr_5x5(cur_i, cur_j);
                    C_hi_addr   <= addr_5x5(cur_i, cur_j);
                    C_top_addr  <= addr_5x5(cur_i, cur_j);

                    C_lo_wdata  <= dot_sum[7:0];
                    C_hi_wdata  <= dot_sum[15:8];
                    C_top_wdata <= {4'b0000, dot_sum[19:16]};

                    C_lo_we  <= 1'b1;
                    C_hi_we  <= 1'b1;
                    C_top_we <= 1'b1;
                end

                S_NEXTJ: begin
                    if (cur_j == 3'd4) cur_j <= 3'd0;
                    else               cur_j <= cur_j + 3'd1;
                end

                S_NEXTI: begin
                    if (cur_i != 3'd4) cur_i <= cur_i + 3'd1;
                end

                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
