`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/23 16:29:03
// Design Name: 
// Module Name: dot_product
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
    parameter integer DEPTH = 20
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

    function [4:0] addr_a_4x5;
        input [1:0] row;
        input [2:0] col;
        reg   [4:0] row5;
        begin
            row5 = {row, 2'b00} + {3'b000, row}; // row*4 + row = row*5
            addr_a_4x5 = row5 + col;             // row*5 + col
        end
    endfunction

    function [4:0] addr_b_5x4;
        input [2:0] row;
        input [1:0] col;
        begin
            addr_b_5x4 = {row, 2'b00} + col;     // row*4 + col
        end
    endfunction

    localparam D_IDLE = 2'd0;
    localparam D_MAC  = 2'd1;
    localparam D_DONE = 2'd2;

    reg [1:0] state, next_state;
    reg [2:0] k;

    wire [4:0] a_idx = addr_a_4x5(i, k); // A[i,k], i=0..3, k=0..4
    wire [4:0] b_idx = addr_b_5x4(k, j); // B[k,j], k=0..4, j=0..3

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
            D_MAC:  if (k == 3'd4) next_state = D_DONE;
            D_DONE: next_state = D_IDLE;
            default: next_state = D_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            done_pulse <= 1'b0;
            sum        <= 20'd0;
            k          <= 3'd0;
        end else begin
            done_pulse <= 1'b0;

            case (state)
                D_IDLE: begin
                    busy <= 1'b0;
                    if (start_ij) begin
                        busy <= 1'b1;
                        sum  <= 20'd0;
                        k    <= 3'd0;
                    end
                end

                D_MAC: begin
                    busy <= 1'b1;
                    sum  <= sum + {4'd0, mult};
                    if (k != 3'd4)
                        k <= k + 3'd1;
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
