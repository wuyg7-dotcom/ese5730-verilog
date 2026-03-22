`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 18:13:01
// Design Name: 
// Module Name: mem_controller
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


module mem_controller_rd(
    input  wire        clk,
    input  wire        rst_n,

    // request (1-cycle pulse)
    input  wire        rd_req,
    input  wire [4:0]  rd_addr,
    output reg         rd_busy,

    // memory port B
    output reg         mem_b_re,
    output reg  [4:0]  mem_b_addr,
    input  wire [7:0]  mem_b_rdata,
    input  wire        mem_b_rvalid,

    // output (aligned with rvalid)
    output reg         out_valid,
    output reg  [7:0]  out_data
);

    localparam IDLE = 1'b0;
    localparam WAIT = 1'b1;

    reg state, next_state;

    always @(posedge clk) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (rd_req)       next_state = WAIT;
            WAIT: if (mem_b_rvalid) next_state = IDLE;
            default:                next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_busy    <= 1'b0;
            mem_b_re   <= 1'b0;
            mem_b_addr <= 5'd0;
            out_valid  <= 1'b0;
            out_data   <= 8'd0;
        end else begin
            mem_b_re  <= 1'b0;
            out_valid <= 1'b0;

            case (state)
                IDLE: begin
                    rd_busy <= 1'b0;
                    if (rd_req) begin
                        mem_b_addr <= rd_addr;
                        mem_b_re   <= 1'b1;  // 1-cycle strobe
                        rd_busy    <= 1'b1;
                    end
                end

                WAIT: begin
                    rd_busy <= 1'b1;
                    if (mem_b_rvalid) begin
                        out_data  <= mem_b_rdata;
                        out_valid <= 1'b1;  // 1-cycle pulse
                    end
                end
            endcase
        end
    end

endmodule
