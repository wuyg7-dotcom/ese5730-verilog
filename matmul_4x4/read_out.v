`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 18:17:03
// Design Name: 
// Module Name: read_out
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


module spi_c_readout #(
    parameter integer DEPTH = 16,
    parameter integer AW    = 4
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          cs_n,
    input  wire          enable,

    input  wire [7:0]    mem_lo_rdata,
    input  wire [7:0]    mem_hi_rdata,
    input  wire [7:0]    mem_top_rdata,

    output reg  [AW-1:0] rd_addr,
    output reg           miso,
    output reg           active
);

    localparam S_IDLE  = 3'd0;
    localparam S_LOAD  = 3'd1;
    localparam S_WAIT  = 3'd2;
    localparam S_LATCH = 3'd3;
    localparam S_SHIFT = 3'd4;
    localparam S_NEXT  = 3'd5;

    reg [2:0]    state;
    reg [AW-1:0] idx;        // 0..15
    reg [4:0]    bit_cnt;    // 0..23
    reg [23:0]   shreg;      // MSB-first out
    reg [1:0]    wait_cnt;   // wait 2 cycles

    wire frame_active = ~cs_n;

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            idx      <= {AW{1'b0}};
            rd_addr  <= {AW{1'b0}};
            bit_cnt  <= 5'd0;
            shreg    <= 24'd0;
            miso     <= 1'b0;
            active   <= 1'b0;
            wait_cnt <= 2'd0;
        end else begin
            if (!frame_active) begin
                state    <= S_IDLE;
                idx      <= {AW{1'b0}};
                rd_addr  <= {AW{1'b0}};
                bit_cnt  <= 5'd0;
                shreg    <= 24'd0;
                miso     <= 1'b0;
                active   <= 1'b0;
                wait_cnt <= 2'd0;
            end else begin
                case (state)
                    S_IDLE: begin
                        miso   <= 1'b0;
                        active <= 1'b0;
                        idx    <= {AW{1'b0}};
                        if (enable) begin
                            active <= 1'b1;
                            state  <= S_LOAD;
                        end
                    end

                    S_LOAD: begin
                        rd_addr  <= idx;
                        wait_cnt <= 2'd0;
                        state    <= S_WAIT;
                    end

                    // wait 2 cycles to match memory read latency
                    S_WAIT: begin
                        if (wait_cnt == 2'd1) begin
                            state <= S_LATCH;
                        end else begin
                            wait_cnt <= wait_cnt + 2'd1;
                        end
                    end

                    // LO -> HI -> TOP[3:0]
                    S_LATCH: begin
                        shreg   <= {mem_lo_rdata, mem_hi_rdata, {4'b0000, mem_top_rdata[3:0]}};
                        bit_cnt <= 5'd0;
                        state   <= S_SHIFT;
                    end

                    S_SHIFT: begin
                        miso  <= shreg[23];
                        shreg <= {shreg[22:0], 1'b0};

                        if (bit_cnt == 5'd23) begin
                            state <= S_NEXT;
                        end else begin
                            bit_cnt <= bit_cnt + 5'd1;
                        end
                    end

                    S_NEXT: begin
                        if (idx == (DEPTH-1)) begin
                            miso  <= 1'b0;
                            state <= S_IDLE;
                        end else begin
                            idx   <= idx + 1'b1;
                            state <= S_LOAD;
                        end
                    end

                    default: begin
                        state <= S_IDLE;
                    end
                endcase
            end
        end
    end
endmodule
