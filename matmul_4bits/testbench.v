`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 15:55:18
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

`timescale 1ns / 1ps

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

    // 4x4 => 16 entries, each element is 4-bit
    reg [3:0]   A [0:15];
    reg [3:0]   B [0:15];

    // final C stored as 16-bit
    reg [15:0]  Cgold [0:15];
    reg [15:0]  c_read16;

    // temporary bytes for SPI readback
    reg [7:0] hi_b, lo_b;

    // ------------------------------------------------------------
    // SPI send: send one 4-bit nibble on both lanes, MSB first
    // ------------------------------------------------------------
    task spi_send_nibble_dual;
        input [3:0] nibA;
        input [3:0] nibB;
        integer b;
        begin
            spi_din_a = nibA[3];
            spi_din_b = nibB[3];

            for (b = 2; b >= 0; b = b - 1) begin
                @(negedge clk);
                spi_din_a = nibA[b];
                spi_din_b = nibB[b];
            end

            @(negedge clk);
        end
    endtask

    task spi_write_frame_AB;
        integer idx;
        begin
            @(negedge clk);
            spi_cs_n = 0;

            // send 16 entries for A and 16 entries for B in parallel
            for (idx = 0; idx < 16; idx = idx + 1) begin
                spi_send_nibble_dual(A[idx], B[idx]);
            end

            @(negedge clk);
            spi_cs_n = 1;
        end
    endtask

    // ------------------------------------------------------------
    // SPI read: read one byte from MISO, MSB first
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

            // 16 outputs, each is 16-bit
            for (idx = 0; idx < 16; idx = idx + 1) begin
                wait (dut.u_c_ro.state == dut.u_c_ro.S_SHIFT);
                wait (dut.u_c_ro.bit_cnt == 0);
                @(negedge clk);

                spi_read_byte_miso(hi_b);
                spi_read_byte_miso(lo_b);

                c_read16 = {hi_b, lo_b};

                if (c_read16 !== Cgold[idx]) begin
                    errors = errors + 1;
                    $display("Mismatch at idx=%0d: read=%0d (0x%04h), expect=%0d (0x%04h)",
                             idx, c_read16, c_read16, Cgold[idx], Cgold[idx]);
                end else begin
                    $display("Match at idx=%0d: value=%0d (0x%04h)",
                             idx, c_read16, c_read16);
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

        // generate random 4-bit entries
        for (ii = 0; ii < 16; ii = ii + 1) begin
            A[ii] = $random & 4'hF;
            B[ii] = $random & 4'hF;
        end

        // golden 4x4 matrix multiply
        // A and B are 4-bit, result stored as 16-bit
        for (ii = 0; ii < 4; ii = ii + 1) begin
            for (jj = 0; jj < 4; jj = jj + 1) begin
                acc = 0;
                for (kk = 0; kk < 4; kk = kk + 1) begin
                    acc = acc + (A[ii*4 + kk] * B[kk*4 + jj]);
                end
                Cgold[ii*4 + jj] = acc[15:0];
            end
        end

        // optional print input matrices
        $display("---- Matrix A ----");
        for (ii = 0; ii < 4; ii = ii + 1) begin
            $display("%0d %0d %0d %0d",
                A[ii*4+0], A[ii*4+1], A[ii*4+2], A[ii*4+3]);
        end

        $display("---- Matrix B ----");
        for (ii = 0; ii < 4; ii = ii + 1) begin
            $display("%0d %0d %0d %0d",
                B[ii*4+0], B[ii*4+1], B[ii*4+2], B[ii*4+3]);
        end

        wait (sys_ready);

        // load A/B through SPI
        spi_write_frame_AB();

        wait (spi_loaded);

        // start computation
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (done);
        @(posedge clk);

        // read back C and compare
        spi_read_and_check_C();

        if (errors == 0)
            $display("PASS: All 16 outputs correct");
        else
            $display("FAIL: %0d mismatches", errors);

        #50;
        $finish;
    end

endmodule
