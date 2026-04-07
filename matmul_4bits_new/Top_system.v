`timescale 1ns / 1ps

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
    // 1. 显式定义常数信号（物理接地线）
    // ------------------------------------------------------------
    // 先声明 wire，再用 assign 赋值，这种写法兼容性最强，不会报错
    wire        GND_BIT;
    wire [3:0]  GND_4BIT;
    wire [15:0] GND_16BIT;

    assign GND_BIT   = 1'b0;
    assign GND_4BIT  = 4'b0000;
    assign GND_16BIT = 16'h0000;

    // ------------------------------------------------------------
    // 2. 状态逻辑与使能信号
    // ------------------------------------------------------------
    wire initA_busy, initB_busy, initC_busy;
    assign sys_ready = ~initC_busy;

    wire [3:0] A_data, B_data;
    wire       A_vld,  B_vld;
    wire       lane_en = ~spi_cs_n;

    // ------------------------------------------------------------
    // 3. SPI 接收模块实例化
    // ------------------------------------------------------------
    spi_lane_nibble_rx #(.MSB_FIRST(1)) u_rx_A (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .din(spi_din_a),
        .din_en(lane_en),
        .nibble_out(A_data),
        .nibble_valid(A_vld)
    );

    spi_lane_nibble_rx #(.MSB_FIRST(1)) u_rx_B (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(spi_cs_n),
        .din(spi_din_b),
        .din_en(lane_en),
        .nibble_out(B_data),
        .nibble_valid(B_vld)
    );

    // ------------------------------------------------------------
    // 4. SPI 写入存储器模块
    // ------------------------------------------------------------
    wire        memA_a_we, memB_a_we;
    wire [3:0]  memA_a_addr, memB_a_addr;
    wire [3:0]  memA_a_wdata, memB_a_wdata;
    wire        A_loaded, B_loaded, A_err, B_err;

    spi_lane_mem_writer #(.DEPTH(16), .AW(4)) u_wr_A (
        .clk(clk), .rst_n(rst_n), .cs_n(spi_cs_n), .sys_ready(sys_ready),
        .data_in(A_data), .data_valid(A_vld), .loaded(A_loaded), .error(A_err),
        .mem_a_we(memA_a_we), .mem_a_addr(memA_a_addr), .mem_a_wdata(memA_a_wdata)
    );

    spi_lane_mem_writer #(.DEPTH(16), .AW(4)) u_wr_B (
        .clk(clk), .rst_n(rst_n), .cs_n(spi_cs_n), .sys_ready(sys_ready),
        .data_in(B_data), .data_valid(B_vld), .loaded(B_loaded), .error(B_err),
        .mem_a_we(memB_a_we), .mem_a_addr(memB_a_addr), .mem_a_wdata(memB_a_wdata)
    );

    assign spi_loaded = A_loaded & B_loaded;
    assign spi_error  = A_err | B_err;

    // ------------------------------------------------------------
    // 5. 存储器实例化 (核心修复：补零与接地)
    // ------------------------------------------------------------
    wire [3:0]  memA_a_rdata, memB_a_rdata;
    wire [15:0] memC_a_rdata;
    wire        memA_b_re, memB_b_re;
    wire [3:0]  memA_b_addr, memB_b_addr;
    wire [3:0]  memA_b_rdata, memB_b_rdata;
    wire        memA_b_rvalid, memB_b_rvalid;

    wire        C_we;
    wire [3:0]  C_addr;
    wire [9:0]  C_wdata_10bit; // 来自 FSM 的 10 位数据
    wire [15:0] memC_b_wdata;  // 拼接给存储器的 16 位线缆

    // 这里执行第二次补零：物理位宽适配
    assign memC_b_wdata = {GND_BIT, GND_BIT, GND_BIT, GND_BIT, GND_BIT, GND_BIT, C_wdata_10bit};

    mem16_dp #(.AW(4), .DW(4), .INIT_CLEAR(0)) u_memA (
        .clk(clk), .rst_n(rst_n),
        .a_we(memA_a_we), .a_addr(memA_a_addr), .a_wdata(memA_a_wdata), .a_rdata(memA_a_rdata),
        .b_we(GND_BIT), .b_re(memA_b_re), .b_addr(memA_b_addr), .b_wdata(GND_4BIT),
        .b_rdata(memA_b_rdata), .b_rvalid(memA_b_rvalid), .init_busy(initA_busy)
    );

    mem16_dp #(.AW(4), .DW(4), .INIT_CLEAR(0)) u_memB (
        .clk(clk), .rst_n(rst_n),
        .a_we(memB_a_we), .a_addr(memB_a_addr), .a_wdata(memB_a_wdata), .a_rdata(memB_a_rdata),
        .b_we(GND_BIT), .b_re(memB_b_re), .b_addr(memB_b_addr), .b_wdata(GND_4BIT),
        .b_rdata(memB_b_rdata), .b_rvalid(memB_b_rvalid), .init_busy(initB_busy)
    );

    // C 存储器：A口读（SPI用），B口写（计算用）
    wire [3:0] c_rd_addr; 
    mem16_dp #(.AW(4), .DW(16), .INIT_CLEAR(1)) u_memC (
        .clk(clk), .rst_n(rst_n),
        .a_we(GND_BIT), .a_addr(c_rd_addr), .a_wdata(GND_16BIT), .a_rdata(memC_a_rdata),
        .b_we(C_we), .b_re(GND_BIT), .b_addr(C_addr), .b_wdata(memC_b_wdata),
        .b_rdata(), .b_rvalid(), .init_busy(initC_busy)
    );

    // ------------------------------------------------------------
    // 6. 控制器与预加载逻辑
    // ------------------------------------------------------------
    wire        A_rd_req, B_rd_req, A_rd_busy, B_rd_busy, A_out_valid, B_out_valid;
    wire [3:0]  A_rd_addr, B_rd_addr, A_out_data, B_out_data;

    mem_controller_rd #(.AW(4), .DW(4)) u_memctrl_A (
        .clk(clk), .rst_n(rst_n), .rd_req(A_rd_req), .rd_addr(A_rd_addr), .rd_busy(A_rd_busy),
        .mem_b_re(memA_b_re), .mem_b_addr(memA_b_addr), .mem_b_rdata(memA_b_rdata),
        .mem_b_rvalid(memA_b_rvalid), .out_valid(A_out_valid), .out_data(A_out_data)
    );

    mem_controller_rd #(.AW(4), .DW(4)) u_memctrl_B (
        .clk(clk), .rst_n(rst_n), .rd_req(B_rd_req), .rd_addr(B_rd_addr), .rd_busy(B_rd_busy),
        .mem_b_re(memB_b_re), .mem_b_addr(memB_b_addr), .mem_b_rdata(memB_b_rdata),
        .mem_b_rvalid(memB_b_rvalid), .out_valid(B_out_valid), .out_data(B_out_data)
    );

    wire preloadB_start, preloadA_start, preloadB_busy, preloadA_busy, preloadB_done_pulse, preloadA_done_pulse;
    wire preloadA_rd_req, preloadB_rd_req;
    wire [3:0] preloadA_rd_addr, preloadB_rd_addr;
    wire [16*4-1:0] A_flat, B_flat;

    assign A_rd_req = preloadA_rd_req; assign A_rd_addr = preloadA_rd_addr;
    assign B_rd_req = preloadB_rd_req; assign B_rd_addr = preloadB_rd_addr;

    preload_mem_rd #(.DEPTH(16), .AW(4), .DW(4)) u_preload_B (
        .clk(clk), .rst_n(rst_n), .start(preloadB_start), .busy(preloadB_busy), .done_pulse(preloadB_done_pulse),
        .rd_req(preloadB_rd_req), .rd_addr(preloadB_rd_addr), .rd_busy(B_rd_busy),
        .out_valid(B_out_valid), .out_data(B_out_data), .buf_flat(B_flat)
    );

    preload_mem_rd #(.DEPTH(16), .AW(4), .DW(4)) u_preload_A (
        .clk(clk), .rst_n(rst_n), .start(preloadA_start), .busy(preloadA_busy), .done_pulse(preloadA_done_pulse),
        .rd_req(preloadA_rd_req), .rd_addr(preloadA_rd_addr), .rd_busy(A_rd_busy),
        .out_valid(A_out_valid), .out_data(A_out_data), .buf_flat(A_flat)
    );

    // ------------------------------------------------------------
    // 7. 计算引擎与 FSM
    // ------------------------------------------------------------
    wire        start_ij, dot_busy, dot_done_pulse;
    wire [1:0]  cur_i, cur_j;
    wire [9:0]  dot_sum_engine;

    dot_ij_engine_buf #(.DW(4), .DEPTH(16)) u_doteng (
        .clk(clk), .rst_n(rst_n), .start_ij(start_ij), .i(cur_i), .j(cur_j),
        .busy(dot_busy), .done_pulse(dot_done_pulse), .sum(dot_sum_engine),
        .A_flat(A_flat), .B_flat(B_flat)
    );

    wire start_gated = start & spi_loaded & ~spi_error;

    fsm_matmul_4x4_simple u_fsm (
        .clk(clk), .rst_n(rst_n), .start(start_gated), .sys_ready(sys_ready), .done(done),
        .preloadB_start(preloadB_start), .preloadB_done_pulse(preloadB_done_pulse),
        .preloadA_start(preloadA_start), .preloadA_done_pulse(preloadA_done_pulse),
        .start_ij(start_ij), .cur_i(cur_i), .cur_j(cur_j), .dot_done_pulse(dot_done_pulse),
        .dot_sum(dot_sum_engine), .C_we(C_we), .C_addr(C_addr), .C_wdata(C_wdata_10bit)
    );

    // ------------------------------------------------------------
    // 8. 输出逻辑与 SPI 读取
    // ------------------------------------------------------------
    reg done_sticky;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            done_sticky <= 1'b0;
        else if (start_gated) 
            done_sticky <= 1'b0;
        else if (done) 
            done_sticky <= 1'b1;
    end

    wire c_read_enable = done_sticky & spi_loaded & ~spi_error;
    wire c_rd_active;

    spi_c_readout #(.DEPTH(16), .AW(4), .DW(16)) u_c_ro (
        .clk(clk), .rst_n(rst_n), .cs_n(spi_cs_n), .enable(c_read_enable),
        .mem_c_rdata(memC_a_rdata), .rd_addr(c_rd_addr), .miso(spi_miso), .active(c_rd_active)
    );

endmodule