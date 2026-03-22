`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/02/18 20:44:57
// Design Name: 
// Module Name: fsm_matmul_6x6
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


module fsm_matmul_6x6_simple #(
    parameter integer N = 6
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire        sys_ready,
    output reg         done,

    // -------- preload control (standard preload module x2)
    output reg         preloadB_start,       // 1-cycle pulse
    input  wire        preloadB_busy,
    input  wire        preloadB_done_pulse,  // 1-cycle pulse

    output reg         preloadA_start,       // 1-cycle pulse
    input  wire        preloadA_busy,
    input  wire        preloadA_done_pulse,  // 1-cycle pulse

    // -------- interface to dot engine
    output reg         start_ij,      // 1-cycle pulse
    output reg  [2:0]  cur_i,
    output reg  [2:0]  cur_j,
    input  wire        dot_busy,      // (optional) can be unused
    input  wire        dot_done_pulse,
    input  wire [19:0] dot_sum,

    // -------- write-back C
    output reg         C_lo_we,
    output reg  [5:0]  C_lo_addr,
    output reg  [7:0]  C_lo_wdata,

    output reg         C_hi_we,
    output reg  [5:0]  C_hi_addr,
    output reg  [7:0]  C_hi_wdata,

    output reg         C_top_we,
    output reg  [5:0]  C_top_addr,
    output reg  [7:0]  C_top_wdata
);

    // ------------------------------------------------------------
    // address helper: row*6 + col (shift-add)
    // ------------------------------------------------------------
    function [5:0] addr_6x6;
        input [2:0] row;
        input [2:0] col;
        reg   [5:0] row6;
        begin
            row6 = {row,2'b00} + {row,1'b0}; // row*4 + row*2
            addr_6x6 = row6 + col;
        end
    endfunction

    // ------------------------------------------------------------
    // FSM states (need 4-bit now)
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

    // "fire once" flags for preload start pulses
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
            S_IDLE: begin
                if (start && sys_ready) next_state = S_PRE_B;
            end

            S_PRE_B: begin
                if (preloadB_done_pulse) next_state = S_PRE_A;
                else                     next_state = S_PRE_B;
            end

            S_PRE_A: begin
                if (preloadA_done_pulse) next_state = S_ISSUE;
                else                     next_state = S_PRE_A;
            end

            S_ISSUE: begin
                next_state = S_WAIT;
            end

            S_WAIT: begin
                if (dot_done_pulse) next_state = S_WRITE;
                else                next_state = S_WAIT;
            end

            S_WRITE: begin
                next_state = S_NEXTJ;
            end

            S_NEXTJ: begin
                if (cur_j == 3'd5) next_state = S_NEXTI;
                else               next_state = S_ISSUE;
            end

            S_NEXTI: begin
                if (cur_i == 3'd5) next_state = S_DONE;
                else               next_state = S_ISSUE;
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // ------------------------------------------------------------
    // outputs + counters
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            done           <= 1'b0;

            // job control
            start_ij       <= 1'b0;
            cur_i          <= 3'd0;
            cur_j          <= 3'd0;

            // preload control
            preloadB_start <= 1'b0;
            preloadA_start <= 1'b0;
            preB_fired     <= 1'b0;
            preA_fired     <= 1'b0;

            // writeback
            C_lo_we        <= 1'b0;  C_lo_addr  <= 6'd0;  C_lo_wdata  <= 8'd0;
            C_hi_we        <= 1'b0;  C_hi_addr  <= 6'd0;  C_hi_wdata  <= 8'd0;
            C_top_we       <= 1'b0;  C_top_addr <= 6'd0;  C_top_wdata <= 8'd0;

        end else begin
            // defaults (1-cycle pulses)
            done           <= 1'b0;
            start_ij       <= 1'b0;
            preloadB_start <= 1'b0;
            preloadA_start <= 1'b0;

            // defaults (write strobes)
            C_lo_we        <= 1'b0;
            C_hi_we        <= 1'b0;
            C_top_we       <= 1'b0;

            // preload fired flags: reset when we ENTER preload states
            if (state != S_PRE_B && next_state == S_PRE_B) preB_fired <= 1'b0;
            if (state != S_PRE_A && next_state == S_PRE_A) preA_fired <= 1'b0;

            case (state)
                S_IDLE: begin
                    cur_i <= 3'd0;
                    cur_j <= 3'd0;
                end

                // ---- Preload B (fire start once)
                S_PRE_B: begin
                    if (!preB_fired) begin
                        preloadB_start <= 1'b1;
                        preB_fired     <= 1'b1;
                    end
                end

                // ---- Preload A (fire start once)
                S_PRE_A: begin
                    if (!preA_fired) begin
                        preloadA_start <= 1'b1;
                        preA_fired     <= 1'b1;
                    end
                end

                // ---- Issue one dot job (cur_i, cur_j)
                S_ISSUE: begin
                    start_ij <= 1'b1;
                end

                // ---- Wait dot_done_pulse
                S_WAIT: begin
                    // no action
                end

                // ---- Write back dot_sum into C memories
                S_WRITE: begin
                    C_lo_addr   <= addr_6x6(cur_i, cur_j);
                    C_hi_addr   <= addr_6x6(cur_i, cur_j);
                    C_top_addr  <= addr_6x6(cur_i, cur_j);

                    C_lo_wdata  <= dot_sum[7:0];
                    C_hi_wdata  <= dot_sum[15:8];
                    C_top_wdata <= {4'b0000, dot_sum[19:16]};

                    C_lo_we     <= 1'b1;
                    C_hi_we     <= 1'b1;
                    C_top_we    <= 1'b1;
                end

                // ---- advance j
                S_NEXTJ: begin
                    if (cur_j == 3'd5) cur_j <= 3'd0;
                    else               cur_j <= cur_j + 3'd1;
                end

                // ---- advance i (only when we finished a row)
                S_NEXTI: begin
                    if (cur_i != 3'd5) cur_i <= cur_i + 3'd1;
                end

                // ---- done pulse
                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
