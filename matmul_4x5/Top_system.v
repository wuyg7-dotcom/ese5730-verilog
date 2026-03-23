`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/23 16:38:37
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
    input  wire        spi_din_a,    // lane A -> mem1(A)
    input  wire        spi_din_b,    // lane B -> mem2(B)
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
    wire init1_busy, init2_busy, init3_busy, init4_busy, init5_busy;

    // Only wait C memories init done (lo/hi/top)
    assign sys_ready = ~(init3_busy | init4_busy | init5_busy);

    // ------------------------------------------------------------
    // Engine port signals
    // ------------------------------------------------------------
    // mem1/mem2 engine read (port B)
    wire        mem1_b_re, mem2_b_re;
    wire [4:0]  mem1_b_addr, mem2_b_addr;
    wire [7:0]  mem1_b_rdata, mem2_b_rdata;
    wire        mem1_b_rvalid, mem2_b_rvalid;

    // mem3/mem4/mem5 engine write (port B)
    wire        mem3_b_we, mem4_b_we, mem5_b_we;
    wire [3:0]  mem3_b_addr, mem4_b_addr, mem5_b_addr;
    wire [7:0]  mem3_b_wdata, mem4_b_wdata, mem5_b_wdata;

    // unused reads on C memories port B
    wire        mem3_b_re = 1'b0;
    wire        mem4_b_re = 1'b0;
    wire        mem5_b_re = 1'b0;
    wire [7:0]  mem3_b_rdata, mem4_b_rdata, mem5_b_rdata;
    wire        mem3_b_rvalid, mem4_b_rvalid, mem5_b_rvalid;

    // ------------------------------------------------------------
    // SPI lanes: bit -> byte
    // ------------------------------------------------------------
    wire [7:0] A_byte, B_byte;
    wire       A_vld,  B_vld;

    spi_lane_byte_rx #(.MSB_FIRST(1)) u_rx_A (
        .clk(clk), .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .din(spi_din_a),
        .din_en(~spi_cs_n),
        .byte_out(A_byte),
        .byte_valid(A_vld)
    );

    spi_lane_byte_rx #(.MSB_FIRST(1)) u_rx_B (
        .clk(clk), .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .din(spi_din_b),
        .din_en(~spi_cs_n),
        .byte_out(B_byte),
        .byte_valid(B_vld)
    );

    // ------------------------------------------------------------
    // SPI writers: byte -> mem1/mem2 Port-A
    // ------------------------------------------------------------
    wire        mem1_a_we, mem2_a_we;
    wire [4:0]  mem1_a_addr, mem2_a_addr;
    wire [7:0]  mem1_a_wdata, mem2_a_wdata;

    wire A_loaded, B_loaded;
    wire A_err,    B_err;

    spi_lane_mem_writer #(.DEPTH(20), .AW(5)) u_wr_A (
        .clk(clk), .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .sys_ready(sys_ready),
        .byte_in(A_byte),
        .byte_valid(A_vld),
        .loaded(A_loaded),
        .error(A_err),
        .mem_a_we(mem1_a_we),
        .mem_a_addr(mem1_a_addr),
        .mem_a_wdata(mem1_a_wdata)
    );

    spi_lane_mem_writer #(.DEPTH(20), .AW(5)) u_wr_B (
        .clk(clk), .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .sys_ready(sys_ready),
        .byte_in(B_byte),
        .byte_valid(B_vld),
        .loaded(B_loaded),
        .error(B_err),
        .mem_a_we(mem2_a_we),
        .mem_a_addr(mem2_a_addr),
        .mem_a_wdata(mem2_a_wdata)
    );

    assign spi_loaded = A_loaded & B_loaded;
    assign spi_error  = A_err | B_err;

    // ------------------------------------------------------------
    // Memories
    // ------------------------------------------------------------
    wire [7:0] mem1_a_rdata, mem2_a_rdata;
    wire [7:0] mem3_a_rdata, mem4_a_rdata, mem5_a_rdata;

    // C readback uses Port-A address on mem3/4/5
    wire [3:0] c_rd_addr;
    wire       c_rd_active;

    // mem1(A) / mem2(B): 20-depth, INIT_CLEAR=0, written by SPI via Port-A
    mem20_dp #(.AW(5), .DW(8), .INIT_CLEAR(0)) u_mem1 (
        .clk(clk), .rst_n(rst_n),
        .a_we(mem1_a_we), .a_addr(mem1_a_addr), .a_wdata(mem1_a_wdata), .a_rdata(mem1_a_rdata),
        .b_we(1'b0), .b_re(mem1_b_re), .b_addr(mem1_b_addr), .b_wdata(8'h00),
        .b_rdata(mem1_b_rdata), .b_rvalid(mem1_b_rvalid),
        .init_busy(init1_busy)
    );

    mem20_dp #(.AW(5), .DW(8), .INIT_CLEAR(0)) u_mem2 (
        .clk(clk), .rst_n(rst_n),
        .a_we(mem2_a_we), .a_addr(mem2_a_addr), .a_wdata(mem2_a_wdata), .a_rdata(mem2_a_rdata),
        .b_we(1'b0), .b_re(mem2_b_re), .b_addr(mem2_b_addr), .b_wdata(8'h00),
        .b_rdata(mem2_b_rdata), .b_rvalid(mem2_b_rvalid),
        .init_busy(init2_busy)
    );

    // mem3/4/5: 16-depth, INIT_CLEAR=1 default, Port-A used for readback only
    mem16_dp #(.AW(4), .DW(8), .INIT_CLEAR(1)) u_mem3 (
        .clk(clk), .rst_n(rst_n),
        .a_we(1'b0), .a_addr(c_rd_addr), .a_wdata(8'd0), .a_rdata(mem3_a_rdata),
        .b_we(mem3_b_we), .b_re(mem3_b_re), .b_addr(mem3_b_addr), .b_wdata(mem3_b_wdata),
        .b_rdata(mem3_b_rdata), .b_rvalid(mem3_b_rvalid),
        .init_busy(init3_busy)
    );

    mem16_dp #(.AW(4), .DW(8), .INIT_CLEAR(1)) u_mem4 (
        .clk(clk), .rst_n(rst_n),
        .a_we(1'b0), .a_addr(c_rd_addr), .a_wdata(8'd0), .a_rdata(mem4_a_rdata),
        .b_we(mem4_b_we), .b_re(mem4_b_re), .b_addr(mem4_b_addr), .b_wdata(mem4_b_wdata),
        .b_rdata(mem4_b_rdata), .b_rvalid(mem4_b_rvalid),
        .init_busy(init4_busy)
    );

    mem16_dp #(.AW(4), .DW(8), .INIT_CLEAR(1)) u_mem5 (
        .clk(clk), .rst_n(rst_n),
        .a_we(1'b0), .a_addr(c_rd_addr), .a_wdata(8'd0), .a_rdata(mem5_a_rdata),
        .b_we(mem5_b_we), .b_re(mem5_b_re), .b_addr(mem5_b_addr), .b_wdata(mem5_b_wdata),
        .b_rdata(mem5_b_rdata), .b_rvalid(mem5_b_rvalid),
        .init_busy(init5_busy)
    );

    // ------------------------------------------------------------
    // Memory controllers (read A/B using port B)
    // ------------------------------------------------------------
    wire        A_rd_req, B_rd_req;
    wire [4:0]  A_rd_addr, B_rd_addr;
    wire        A_rd_busy, B_rd_busy;
    wire        A_out_valid, B_out_valid;
    wire [7:0]  A_out_data,  B_out_data;

    mem_controller_rd #(.AW(5)) u_memctrl_A (
        .clk(clk), .rst_n(rst_n),
        .rd_req(A_rd_req), .rd_addr(A_rd_addr), .rd_busy(A_rd_busy),
        .mem_b_re(mem1_b_re), .mem_b_addr(mem1_b_addr),
        .mem_b_rdata(mem1_b_rdata), .mem_b_rvalid(mem1_b_rvalid),
        .out_valid(A_out_valid), .out_data(A_out_data)
    );

    mem_controller_rd #(.AW(5)) u_memctrl_B (
        .clk(clk), .rst_n(rst_n),
        .rd_req(B_rd_req), .rd_addr(B_rd_addr), .rd_busy(B_rd_busy),
        .mem_b_re(mem2_b_re), .mem_b_addr(mem2_b_addr),
        .mem_b_rdata(mem2_b_rdata), .mem_b_rvalid(mem2_b_rvalid),
        .out_valid(B_out_valid), .out_data(B_out_data)
    );

    // ------------------------------------------------------------
    // Preload modules x2 (read A/B into flat buffers)
    // ------------------------------------------------------------
    wire preloadB_start, preloadA_start;
    wire preloadB_busy,  preloadA_busy;
    wire preloadB_done_pulse, preloadA_done_pulse;

    wire preloadA_rd_req, preloadB_rd_req;
    wire [4:0] preloadA_rd_addr, preloadB_rd_addr;

    wire [20*8-1:0] A_flat;
    wire [20*8-1:0] B_flat;

    assign A_rd_req  = preloadA_rd_req;
    assign A_rd_addr = preloadA_rd_addr;

    assign B_rd_req  = preloadB_rd_req;
    assign B_rd_addr = preloadB_rd_addr;

    preload_mem_rd #(.DEPTH(20), .AW(5), .DW(8)) u_preload_B (
        .clk(clk), .rst_n(rst_n),
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

    preload_mem_rd #(.DEPTH(20), .AW(5), .DW(8)) u_preload_A (
        .clk(clk), .rst_n(rst_n),
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
    wire [19:0] dot_sum;

    dot_ij_engine_buf #(.DW(8), .DEPTH(20)) u_doteng (
        .clk(clk), .rst_n(rst_n),
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
    wire        C_lo_we, C_hi_we, C_top_we;
    wire [3:0]  C_lo_addr, C_hi_addr, C_top_addr;
    wire [7:0]  C_lo_wdata, C_hi_wdata, C_top_wdata;

    wire start_gated = start & spi_loaded & ~spi_error;

    fsm_matmul_4x4_simple u_fsm (
        .clk(clk), .rst_n(rst_n),
        .start(start_gated),
        .sys_ready(sys_ready),
        .done(done),

        .preloadB_start(preloadB_start),
        .preloadB_busy(preloadB_busy),
        .preloadB_done_pulse(preloadB_done_pulse),

        .preloadA_start(preloadA_start),
        .preloadA_busy(preloadA_busy),
        .preloadA_done_pulse(preloadA_done_pulse),

        .start_ij(start_ij),
        .cur_i(cur_i),
        .cur_j(cur_j),
        .dot_busy(dot_busy),
        .dot_done_pulse(dot_done_pulse),
        .dot_sum(dot_sum),

        .C_lo_we(C_lo_we),
        .C_lo_addr(C_lo_addr),
        .C_lo_wdata(C_lo_wdata),

        .C_hi_we(C_hi_we),
        .C_hi_addr(C_hi_addr),
        .C_hi_wdata(C_hi_wdata),

        .C_top_we(C_top_we),
        .C_top_addr(C_top_addr),
        .C_top_wdata(C_top_wdata)
    );

    // write-back to C memories (engine port B)
    assign mem3_b_we    = C_lo_we;
    assign mem3_b_addr  = C_lo_addr;
    assign mem3_b_wdata = C_lo_wdata;

    assign mem4_b_we    = C_hi_we;
    assign mem4_b_addr  = C_hi_addr;
    assign mem4_b_wdata = C_hi_wdata;

    assign mem5_b_we    = C_top_we;
    assign mem5_b_addr  = C_top_addr;
    assign mem5_b_wdata = C_top_wdata;

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
    // SPI readout of C (24-bit per element: lo -> hi -> top)
    // ------------------------------------------------------------
    wire c_read_enable = done_sticky & spi_loaded & ~spi_error;

    spi_c_readout #(.DEPTH(16), .AW(4)) u_c_ro (
        .clk(clk), .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .enable(c_read_enable),

        .mem_lo_rdata(mem3_a_rdata),
        .mem_hi_rdata(mem4_a_rdata),
        .mem_top_rdata(mem5_a_rdata),

        .rd_addr(c_rd_addr),
        .miso(spi_miso),
        .active(c_rd_active)
    );

endmodule
