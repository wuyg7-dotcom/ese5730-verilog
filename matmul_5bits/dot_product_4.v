`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 18:10:04
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
    parameter integer DW      = 5,
    parameter integer DEPTH   = 16,
    parameter integer SUM_W   = 12
)(
    input  wire                    clk,
    input  wire                    rst_n,

    input  wire                    start_ij,   // 1-cycle pulse
    input  wire [1:0]              i,
    input  wire [1:0]              j,

    output reg                     busy,
    output reg                     done_pulse,
    output reg  [SUM_W-1:0]        sum,

    input  wire [DEPTH*DW-1:0]     A_flat,
    input  wire [DEPTH*DW-1:0]     B_flat
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

    wire [3:0]      a_idx;
    wire [3:0]      b_idx;
    wire [DW-1:0]   a_val;
    wire [DW-1:0]   b_val;
    wire [2*DW-1:0] mult;

    assign a_idx = addr_4x4(i, k); // A[i,k]
    assign b_idx = addr_4x4(k, j); // B[k,j]

    assign a_val = A_flat[a_idx*DW +: DW];
    assign b_val = B_flat[b_idx*DW +: DW];

    assign mult = a_val * b_val;   // 5b x 5b -> 10b when DW=5

    always @(posedge clk) begin
        if (!rst_n)
            state <= D_IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            D_IDLE: if (start_ij)  next_state = D_MAC;
            D_MAC:  if (k == 2'd3) next_state = D_DONE;
            D_DONE:                next_state = D_IDLE;
            default:               next_state = D_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            done_pulse <= 1'b0;
            sum        <= {SUM_W{1'b0}};
            k          <= 2'd0;
        end else begin
            done_pulse <= 1'b0;

            case (state)
                D_IDLE: begin
                    busy <= 1'b0;
                    if (start_ij) begin
                        busy <= 1'b1;
                        sum  <= {SUM_W{1'b0}};
                        k    <= 2'd0;
                    end
                end

                D_MAC: begin
                    busy <= 1'b1;
                    sum  <= sum + {{(SUM_W-(2*DW)){1'b0}}, mult};
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

