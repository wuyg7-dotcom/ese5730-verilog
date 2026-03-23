`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 23:28:40
// Design Name: 
// Module Name: dot_product_4
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

module dot_ij_engine_buf #(
    parameter integer DW    = 8,
    parameter integer DEPTH = 16
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 start_ij,   // 1-cycle pulse
    input  wire [1:0]           i,
    input  wire [1:0]           j,

    output reg                  busy,
    output reg                  done_pulse,
    output reg  [19:0]          sum,

    input  wire [DEPTH*DW-1:0]  A_flat,
    input  wire [DEPTH*DW-1:0]  B_flat
);

    function [3:0] addr_4x4;
        input [1:0] row;
        input [1:0] col;
        begin
            addr_4x4 = {row, 2'b00} + col; // row*4 + col
        end
    endfunction

    localparam D_IDLE = 2'd0;
    localparam D_MAC  = 2'd1;
    localparam D_DONE = 2'd2;

    reg [1:0] state, next_state;
    reg [1:0] k;

    wire [3:0] a_idx = addr_4x4(i, k); // A[i,k]
    wire [3:0] b_idx = addr_4x4(k, j); // B[k,j]

    wire [7:0] a_val = A_flat[a_idx*8 +: 8];
    wire [7:0] b_val = B_flat[b_idx*8 +: 8];

    wire [15:0] mult = a_val * b_val;

    always @(posedge clk) begin
        if (!rst_n) state <= D_IDLE;
        else        state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            D_IDLE: if (start_ij) next_state = D_MAC;
            D_MAC:  if (k == 2'd3) next_state = D_DONE;
            D_DONE: next_state = D_IDLE;
            default: next_state = D_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            done_pulse <= 1'b0;
            sum        <= 20'd0;
            k          <= 2'd0;
        end else begin
            done_pulse <= 1'b0;

            case (state)
                D_IDLE: begin
                    busy <= 1'b0;
                    if (start_ij) begin
                        busy <= 1'b1;
                        sum  <= 20'd0;
                        k    <= 2'd0;
                    end
                end

                D_MAC: begin
                    busy <= 1'b1;
                    sum  <= sum + {4'd0, mult};
                    if (k != 2'd3)
                        k <= k + 2'd1;
                end

                D_DONE: begin
                    busy       <= 1'b0;
                    done_pulse <= 1'b1;
                end

                default: begin
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule