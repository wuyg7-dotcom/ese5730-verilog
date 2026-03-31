`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 18:18:01
// Design Name: 
// Module Name: testbench
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
module tb_top_system_final;

    reg clk;
    reg rst_n;

    reg  spi_cs_n;
    reg  spi_din_a;
    reg  spi_din_b;
    wire spi_miso;
    wire spi_loaded;
    wire spi_error;

    reg  start;
    wire done;
    wire sys_ready;

    top_system_final dut(
        .clk(clk),
        .rst_n(rst_n),
        .spi_cs_n(spi_cs_n),
        .spi_din_a(spi_din_a),
        .spi_din_b(spi_din_b),
        .spi_miso(spi_miso),
        .spi_loaded(spi_loaded),
        .spi_error(spi_error),
        .start(start),
        .done(done),
        .sys_ready(sys_ready)
    );

    // ------------------------------------------------------------
    // clock
    // ------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer ii, jj, kk;
    integer acc;
    integer errors;

    // ? 改这里：5-bit
    reg [4:0]   A [0:15];
    reg [4:0]   B [0:15];

    reg [15:0]  Cgold [0:15];
    reg [15:0]  c_read16;

    reg [7:0] hi_b, lo_b;

    // ------------------------------------------------------------
    // ? SPI send 5-bit（替换 nibble）
    // ------------------------------------------------------------
    task spi_send_word5_dual;
        input [4:0] wA;
        input [4:0] wB;
        integer b;
        begin
            spi_din_a = wA[4];
            spi_din_b = wB[4];

            for (b = 3; b >= 0; b = b - 1) begin
                @(negedge clk);
                spi_din_a = wA[b];
                spi_din_b = wB[b];
            end

            @(negedge clk);
        end
    endtask

    task spi_write_frame_AB;
        integer idx;
        begin
            @(negedge clk);
            spi_cs_n = 0;

            for (idx = 0; idx < 16; idx = idx + 1) begin
                spi_send_word5_dual(A[idx], B[idx]);
            end

            @(negedge clk);
            spi_cs_n = 1;
        end
    endtask

    // ------------------------------------------------------------
    // SPI read
    // ------------------------------------------------------------
    task spi_read_byte_miso;
        output [7:0] data;
        integer b;
        begin
            for (b = 7; b >= 0; b = b - 1) begin
                @(negedge clk);
                data[b] = spi_miso;
            end
        end
    endtask

    task spi_read_and_check_C;
        integer idx;
        begin
            errors = 0;

            @(negedge clk);
            spi_cs_n = 0;

            for (idx = 0; idx < 16; idx = idx + 1) begin
                wait (dut.u_c_ro.state == dut.u_c_ro.S_SHIFT);
                wait (dut.u_c_ro.bit_cnt == 0);
                @(negedge clk);

                spi_read_byte_miso(hi_b);
                spi_read_byte_miso(lo_b);

                c_read16 = {hi_b, lo_b};

                if (c_read16 !== Cgold[idx]) begin
                    errors = errors + 1;
                    $display("Mismatch idx=%0d: read=%0d, expect=%0d",
                             idx, c_read16, Cgold[idx]);
                end else begin
                    $display("Match idx=%0d: value=%0d", idx, c_read16);
                end
            end

            @(negedge clk);
            spi_cs_n = 1;
        end
    endtask

    // ------------------------------------------------------------
    // main
    // ------------------------------------------------------------
    initial begin
        spi_cs_n  = 1;
        spi_din_a = 0;
        spi_din_b = 0;
        start     = 0;

        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;

        // ? 5-bit random
        for (ii = 0; ii < 16; ii = ii + 1) begin
            A[ii] = $random & 5'h1F;
            B[ii] = $random & 5'h1F;
        end

        // golden
        for (ii = 0; ii < 4; ii = ii + 1) begin
            for (jj = 0; jj < 4; jj = jj + 1) begin
                acc = 0;
                for (kk = 0; kk < 4; kk = kk + 1) begin
                    acc = acc + (A[ii*4 + kk] * B[kk*4 + jj]);
                end
                Cgold[ii*4 + jj] = acc; // 自动截断到16bit
            end
        end

        wait (sys_ready);

        spi_write_frame_AB();
        wait (spi_loaded);

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (done);
        @(posedge clk);

        spi_read_and_check_C();

        if (errors == 0)
            $display("PASS");
        else
            $display("FAIL: %0d errors", errors);

        #50;
        $finish;
    end

endmodule
