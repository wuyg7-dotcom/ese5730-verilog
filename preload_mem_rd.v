`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/02/18 20:42:43
// Design Name: 
// Module Name: preload_mem_rd
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


module preload_mem_rd #(
    parameter integer DEPTH = 36,     // number of bytes to preload
    parameter integer AW    = 6,      // address width (>= $clog2(DEPTH))
    parameter integer DW    = 8       // data width
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 start,       // 1-cycle pulse
    output reg                  busy,
    output reg                  done_pulse,  // 1-cycle

    // connect to mem_controller_rd
    output reg                  rd_req,
    output reg  [AW-1:0]         rd_addr,
    input  wire                 rd_busy,
    input  wire                 out_valid,
    input  wire [DW-1:0]         out_data,

    // flattened buffer output: buf[idx] at flat[idx*DW +: DW]
    output reg  [DEPTH*DW-1:0]   buf_flat
);

    localparam P_IDLE  = 2'd0;
    localparam P_ISSUE = 2'd1;
    localparam P_WAIT  = 2'd2;
    localparam P_DONE  = 2'd3;

    reg [1:0] state, next_state;

    // idx needs to count 0..DEPTH-1
    reg [AW-1:0] idx;

    // state reg
    always @(posedge clk) begin
        if (!rst_n) state <= P_IDLE;
        else        state <= next_state;
    end

    // next state
    always @(*) begin
        next_state = state;
        case (state)
            P_IDLE:  if (start) next_state = P_ISSUE;

            // wait until controller is free, then strobe rd_req
            P_ISSUE: if (!rd_busy) next_state = P_WAIT;

            // wait for out_valid, then store and advance
            P_WAIT:  if (out_valid) begin
                        if (idx == (DEPTH-1)) next_state = P_DONE;
                        else                  next_state = P_ISSUE;
                     end

            P_DONE:  next_state = P_IDLE;

            default: next_state = P_IDLE;
        endcase
    end

    // outputs/datapath
    always @(posedge clk) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            done_pulse <= 1'b0;
            rd_req     <= 1'b0;
            rd_addr    <= {AW{1'b0}};
            idx        <= {AW{1'b0}};
            buf_flat   <= {(DEPTH*DW){1'b0}};
        end else begin
            done_pulse <= 1'b0;
            rd_req     <= 1'b0;

            case (state)
                P_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        idx  <= {AW{1'b0}};
                    end
                end

                P_ISSUE: begin
                    busy <= 1'b1;
                    if (!rd_busy) begin
                        rd_addr <= idx;
                        rd_req  <= 1'b1; // 1-cycle strobe
                    end
                end

                P_WAIT: begin
                    busy <= 1'b1;
                    if (out_valid) begin
                        buf_flat[idx*DW +: DW] <= out_data;
                        if (idx != (DEPTH-1)) idx <= idx + {{(AW-1){1'b0}},1'b1};
                    end
                end

                P_DONE: begin
                    busy       <= 1'b0;
                    done_pulse <= 1'b1;
                end
            endcase
        end
    end

endmodule

