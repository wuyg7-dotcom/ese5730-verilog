`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 18:14:59
// Design Name: 
// Module Name: Top_system
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

module top_system_final(
    input  wire        clk,
    input  wire        rst_n,

    // Dual-Data SPI-like input
    input  wire        spi_cs_n,     // active low
    input  wire        spi_din_a,    // lane A -> memA
    input  wire        spi_din_b,    // lane B -> memB
    output wire        spi_miso,     // readback C stream (MSB-first)
    output wire        spi_loaded,   // A & B loaded
    output wire        spi_error,    // any lane error

    // control
    input  wire        start,
    output wire        done,

    // status
    output wire        sys_ready
);

    // ------------------------------------------------------------
    // init status
    // ------------------------------------------------------------
    wire initA_busy, initB_busy, initC_busy;

    // A/B use INIT_CLEAR=0, only wait C memory init done
    assign sys_ready = ~initC_busy;

    // ------------------------------------------------------------
    // SPI lanes: bit -> 5-bit word
    // ------------------------------------------------------------
    wire [4:0] A_data, B_data;
    wire       A_vld,  B_vld;

    spi_lane_word5_rx #(.MSB_FIRST(1)) u_rx_A (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .din(spi_din_a),
        .din_en(~spi_cs_n),
        .word_out(A_data),
        .word_valid(A_vld)
    );

    spi_lane_word5_rx #(.MSB_FIRST(1)) u_rx_B (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .din(spi_din_b),
        .din_en(~spi_cs_n),
        .word_out(B_data),
        .word_valid(B_vld)
    );

    // ------------------------------------------------------------
    // SPI writers: 5-bit data -> memA/memB Port-A
    // ------------------------------------------------------------
    wire        memA_a_we, memB_a_we;
    wire [3:0]  memA_a_addr, memB_a_addr;
    wire [4:0]  memA_a_wdata, memB_a_wdata;

    wire A_loaded, B_loaded;
    wire A_err,    B_err;

    spi_lane_mem_writer #(.DEPTH(16), .AW(4)) u_wr_A (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .sys_ready(sys_ready),
        .data_in(A_data),
        .data_valid(A_vld),
        .loaded(A_loaded),
        .error(A_err),
        .mem_a_we(memA_a_we),
        .mem_a_addr(memA_a_addr),
        .mem_a_wdata(memA_a_wdata)
    );

    spi_lane_mem_writer #(.DEPTH(16), .AW(4)) u_wr_B (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .sys_ready(sys_ready),
        .data_in(B_data),
        .data_valid(B_vld),
        .loaded(B_loaded),
        .error(B_err),
        .mem_a_we(memB_a_we),
        .mem_a_addr(memB_a_addr),
        .mem_a_wdata(memB_a_wdata)
    );

    assign spi_loaded = A_loaded & B_loaded;
    assign spi_error  = A_err | B_err;

    // ------------------------------------------------------------
    // A/B memories (5-bit), C memory (16-bit)
    // ------------------------------------------------------------
    wire [4:0]  memA_a_rdata, memB_a_rdata;
    wire [15:0] memC_a_rdata;

    // A/B engine read on Port-B
    wire        memA_b_re, memB_b_re;
    wire [3:0]  memA_b_addr, memB_b_addr;
    wire [4:0]  memA_b_rdata, memB_b_rdata;
    wire        memA_b_rvalid, memB_b_rvalid;

    // C write on Port-B
    wire        C_we;
    wire [3:0]  C_addr;
    wire [15:0] C_wdata;

    // C readback uses Port-A
    wire [3:0]  c_rd_addr;
    wire        c_rd_active;

    mem16_dp #(.AW(4), .DW(5), .INIT_CLEAR(0)) u_memA (
        .clk(clk),
        .rst_n(rst_n),
        .a_we(memA_a_we),
        .a_addr(memA_a_addr),
        .a_wdata(memA_a_wdata),
        .a_rdata(memA_a_rdata),
        .b_we(1'b0),
        .b_re(memA_b_re),
        .b_addr(memA_b_addr),
        .b_wdata(5'd0),
        .b_rdata(memA_b_rdata),
        .b_rvalid(memA_b_rvalid),
        .init_busy(initA_busy)
    );

    mem16_dp #(.AW(4), .DW(5), .INIT_CLEAR(0)) u_memB (
        .clk(clk),
        .rst_n(rst_n),
        .a_we(memB_a_we),
        .a_addr(memB_a_addr),
        .a_wdata(memB_a_wdata),
        .a_rdata(memB_a_rdata),
        .b_we(1'b0),
        .b_re(memB_b_re),
        .b_addr(memB_b_addr),
        .b_wdata(5'd0),
        .b_rdata(memB_b_rdata),
        .b_rvalid(memB_b_rvalid),
        .init_busy(initB_busy)
    );

    mem16_dp #(.AW(4), .DW(16), .INIT_CLEAR(1)) u_memC (
        .clk(clk),
        .rst_n(rst_n),
        .a_we(1'b0),
        .a_addr(c_rd_addr),
        .a_wdata(16'd0),
        .a_rdata(memC_a_rdata),
        .b_we(C_we),
        .b_re(1'b0),
        .b_addr(C_addr),
        .b_wdata(C_wdata),
        .b_rdata(),
        .b_rvalid(),
        .init_busy(initC_busy)
    );

    // ------------------------------------------------------------
    // Memory controllers (read A/B using port B)
    // ------------------------------------------------------------
    wire        A_rd_req, B_rd_req;
    wire [3:0]  A_rd_addr, B_rd_addr;
    wire        A_rd_busy, B_rd_busy;
    wire        A_out_valid, B_out_valid;
    wire [4:0]  A_out_data,  B_out_data;

    mem_controller_rd #(.AW(4), .DW(5)) u_memctrl_A (
        .clk(clk),
        .rst_n(rst_n),
        .rd_req(A_rd_req),
        .rd_addr(A_rd_addr),
        .rd_busy(A_rd_busy),
        .mem_b_re(memA_b_re),
        .mem_b_addr(memA_b_addr),
        .mem_b_rdata(memA_b_rdata),
        .mem_b_rvalid(memA_b_rvalid),
        .out_valid(A_out_valid),
        .out_data(A_out_data)
    );

    mem_controller_rd #(.AW(4), .DW(5)) u_memctrl_B (
        .clk(clk),
        .rst_n(rst_n),
        .rd_req(B_rd_req),
        .rd_addr(B_rd_addr),
        .rd_busy(B_rd_busy),
        .mem_b_re(memB_b_re),
        .mem_b_addr(memB_b_addr),
        .mem_b_rdata(memB_b_rdata),
        .mem_b_rvalid(memB_b_rvalid),
        .out_valid(B_out_valid),
        .out_data(B_out_data)
    );

    // ------------------------------------------------------------
    // Preload modules x2 (read A/B into flat buffers)
    // ------------------------------------------------------------
    wire preloadB_start, preloadA_start;
    wire preloadB_busy,  preloadA_busy;
    wire preloadB_done_pulse, preloadA_done_pulse;

    wire preloadA_rd_req, preloadB_rd_req;
    wire [3:0] preloadA_rd_addr, preloadB_rd_addr;

    wire [16*5-1:0] A_flat;
    wire [16*5-1:0] B_flat;

    assign A_rd_req  = preloadA_rd_req;
    assign A_rd_addr = preloadA_rd_addr;

    assign B_rd_req  = preloadB_rd_req;
    assign B_rd_addr = preloadB_rd_addr;

    preload_mem_rd #(.DEPTH(16), .AW(4), .DW(5)) u_preload_B (
        .clk(clk),
        .rst_n(rst_n),
        .start(preloadB_start),
        .busy(preloadB_busy),
        .done_pulse(preloadB_done_pulse),
        .rd_req(preloadB_rd_req),
        .rd_addr(preloadB_rd_addr),
        .rd_busy(B_rd_busy),
        .out_valid(B_out_valid),
        .out_data(B_out_data),
        .buf_flat(B_flat)
    );

    preload_mem_rd #(.DEPTH(16), .AW(4), .DW(5)) u_preload_A (
        .clk(clk),
        .rst_n(rst_n),
        .start(preloadA_start),
        .busy(preloadA_busy),
        .done_pulse(preloadA_done_pulse),
        .rd_req(preloadA_rd_req),
        .rd_addr(preloadA_rd_addr),
        .rd_busy(A_rd_busy),
        .out_valid(A_out_valid),
        .out_data(A_out_data),
        .buf_flat(A_flat)
    );

    // ------------------------------------------------------------
    // Dot engine (buffer-based)
    // ------------------------------------------------------------
    wire        start_ij;
    wire [1:0]  cur_i, cur_j;
    wire        dot_busy;
    wire        dot_done_pulse;
    wire [11:0] dot_sum;

    dot_ij_engine_buf #(.DW(5), .DEPTH(16), .SUM_W(12)) u_doteng (
        .clk(clk),
        .rst_n(rst_n),
        .start_ij(start_ij),
        .i(cur_i),
        .j(cur_j),
        .busy(dot_busy),
        .done_pulse(dot_done_pulse),
        .sum(dot_sum),
        .A_flat(A_flat),
        .B_flat(B_flat)
    );

    // ------------------------------------------------------------
    // Outer FSM (gate start with spi_loaded)
    // ------------------------------------------------------------
    wire start_gated = start & spi_loaded & ~spi_error;

    fsm_matmul_4x4_simple u_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_gated),
        .sys_ready(sys_ready),
        .done(done),

        .preloadB_start(preloadB_start),
        .preloadB_done_pulse(preloadB_done_pulse),

        .preloadA_start(preloadA_start),
        .preloadA_done_pulse(preloadA_done_pulse),

        .start_ij(start_ij),
        .cur_i(cur_i),
        .cur_j(cur_j),
        .dot_done_pulse(dot_done_pulse),
        .dot_sum(dot_sum),

        .C_we(C_we),
        .C_addr(C_addr),
        .C_wdata(C_wdata)
    );

    // ------------------------------------------------------------
    // DONE sticky latch for readback
    // ------------------------------------------------------------
    reg done_sticky;
    always @(posedge clk) begin
        if (!rst_n) begin
            done_sticky <= 1'b0;
        end else if (start_gated) begin
            done_sticky <= 1'b0;
        end else if (done) begin
            done_sticky <= 1'b1;
        end
    end

    // ------------------------------------------------------------
    // SPI readout of C (16-bit per element)
    // ------------------------------------------------------------
    wire c_read_enable = done_sticky & spi_loaded & ~spi_error;

    spi_c_readout #(.DEPTH(16), .AW(4), .DW(16)) u_c_ro (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .enable(c_read_enable),
        .mem_c_rdata(memC_a_rdata),
        .rd_addr(c_rd_addr),
        .miso(spi_miso),
        .active(c_rd_active)
    );

endmodule