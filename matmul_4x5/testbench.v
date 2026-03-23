`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/23 16:39:12
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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer ii, jj, kk;
    integer acc;
    integer errors;

    // A: 4x5 => 20 entries
    // B: 5x4 => 20 entries
    // C: 4x4 => 16 entries
    reg [7:0]   A [0:19];
    reg [7:0]   B [0:19];
    reg [19:0]  Cgold [0:15];

    reg [7:0] lo_b, hi_b, top_b;
    reg [19:0] c_read20;

    // ---------------- SPI send ----------------
    task spi_send_byte_dual;
        input [7:0] byteA;
        input [7:0] byteB;
        integer b;
        begin
            spi_din_a = byteA[7];
            spi_din_b = byteB[7];

            for (b = 6; b >= 0; b = b - 1) begin
                @(negedge clk);
                spi_din_a = byteA[b];
                spi_din_b = byteB[b];
            end

            @(negedge clk);
        end
    endtask

    task spi_write_frame_AB;
        integer idx;
        begin
            @(negedge clk);
            spi_cs_n = 0;

            // 20 entries
            for (idx = 0; idx < 20; idx = idx + 1) begin
                spi_send_byte_dual(A[idx], B[idx]);
            end

            @(negedge clk);
            spi_cs_n = 1;
        end
    endtask

    // ---------------- SPI read ----------------
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

            // 16 outputs
            for (idx = 0; idx < 16; idx = idx + 1) begin

                wait (dut.u_c_ro.state == dut.u_c_ro.S_SHIFT);
                wait (dut.u_c_ro.bit_cnt == 0);
                @(negedge clk);

                spi_read_byte_miso(lo_b);
                spi_read_byte_miso(hi_b);
                spi_read_byte_miso(top_b);

                c_read20 = { top_b[3:0], hi_b, lo_b };

                if (c_read20 !== Cgold[idx]) begin
                    errors = errors + 1;
                    $display("Mismatch at idx=%0d: read=%0d (0x%05h), expect=%0d (0x%05h)",
                             idx, c_read20, c_read20, Cgold[idx], Cgold[idx]);
                end
            end

            @(negedge clk);
            spi_cs_n = 1;
        end
    endtask

    // ---------------- main ----------------
    initial begin
        spi_cs_n  = 1;
        spi_din_a = 0;
        spi_din_b = 0;
        start     = 0;

        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;

        // random A: 20 entries
        for (ii = 0; ii < 20; ii = ii + 1) begin
            A[ii] = $random;
        end

        // random B: 20 entries
        for (ii = 0; ii < 20; ii = ii + 1) begin
            B[ii] = $random;
        end

        // golden C = A(4x5) * B(5x4) => 4x4
        for (ii = 0; ii < 4; ii = ii + 1) begin
            for (jj = 0; jj < 4; jj = jj + 1) begin
                acc = 0;
                for (kk = 0; kk < 5; kk = kk + 1) begin
                    acc = acc + (A[ii*5 + kk] * B[kk*4 + jj]);
                end
                Cgold[ii*4 + jj] = acc[19:0];
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
            $display("PASS: All 16 outputs correct");
        else
            $display("FAIL: %0d mismatches", errors);

        #50;
        $finish;
    end

endmodule
