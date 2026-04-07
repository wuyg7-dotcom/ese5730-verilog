`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 15:28:41
// Design Name: 
// Module Name: mem16_dp
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

module mem16_dp #(
    parameter AW = 4,
    parameter DW = 4,
    parameter INIT_CLEAR = 1  // 1: resetºóÇå³ý mem[0..15]
)(
    input  wire             clk,
    input  wire             rst_n,

    // Port A
    input  wire             a_we,
    input  wire [AW-1:0]    a_addr,
    input  wire [DW-1:0]    a_wdata,
    output reg  [DW-1:0]    a_rdata,

    // Port B
    input  wire             b_we,
    input  wire             b_re,
    input  wire [AW-1:0]    b_addr,
    input  wire [DW-1:0]    b_wdata,
    output reg  [DW-1:0]    b_rdata,
    output reg              b_rvalid,

    // status
    output reg              init_busy
);

    // 4x4 matrix => 16 entries
    reg [DW-1:0] mem [0:15];

    // init clear FSM
    reg [AW-1:0] init_addr;
    reg          init_done;

    // sync read address pipelines
    reg [AW-1:0] a_addr_q;
    reg [AW-1:0] b_addr_q;
    reg          b_re_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            init_busy <= (INIT_CLEAR != 0);
            init_addr <= {AW{1'b0}};
            init_done <= 1'b0;

            a_addr_q  <= {AW{1'b0}};
            b_addr_q  <= {AW{1'b0}};
            b_re_q    <= 1'b0;

            a_rdata   <= {DW{1'b0}};
            b_rdata   <= {DW{1'b0}};
            b_rvalid  <= 1'b0;
        end else begin
            // -----------------------
            // init clear
            // -----------------------
            if (INIT_CLEAR != 0) begin
                if (!init_done) begin
                    mem[init_addr] <= {DW{1'b0}};

                    if (init_addr == {AW{1'b1}}) begin
                        init_done <= 1'b1;
                        init_busy <= 1'b0;
                    end else begin
                        init_addr <= init_addr + {{(AW-1){1'b0}}, 1'b1};
                        init_busy <= 1'b1;
                    end
                end
            end else begin
                init_busy <= 1'b0;
            end

            // -----------------------
            // normal operation
            // -----------------------
            if ((INIT_CLEAR == 0) || (init_busy == 1'b0)) begin
                // Port A write
                if (a_we) begin
                    mem[a_addr] <= a_wdata;
                end

                // Port B write
                if (b_we) begin
                    mem[b_addr] <= b_wdata;
                end

                // latch read addresses
                a_addr_q <= a_addr;

                if (b_re) begin
                    b_addr_q <= b_addr;
                end
                b_re_q <= b_re;

                // 1-cycle delayed read output
                a_rdata <= mem[a_addr_q];
                b_rdata <= mem[b_addr_q];

                // align valid with b_rdata
                b_rvalid <= b_re_q;

            end else begin
                // during init, block engine interface
                b_re_q   <= 1'b0;
                b_rvalid <= 1'b0;

                // host read still allowed during init
                a_addr_q <= a_addr;
                a_rdata  <= mem[a_addr_q];
            end
        end
    end

endmodule