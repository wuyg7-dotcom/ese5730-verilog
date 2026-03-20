`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2026/02/18 21:34:45
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
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2026/02/18 21:34:45
// Design Name:
// Module Name: tb_top_system_final
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.02 - Fix readback alignment per element (handle gaps)
//
//////////////////////////////////////////////////////////////////////////////////

module tb_top_system_final;

    reg clk;
    reg rst_n;

    // SPI dual data + miso
    reg  spi_cs_n;
    reg  spi_din_a;
    reg  spi_din_b;
    wire spi_miso;
    wire spi_loaded;
    wire spi_error;

    reg  start;
    wire done;
    wire sys_ready;

    // DUT
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

    // clock: reuse clk as "SPI bit clock"
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 100MHz
    end

    // ---------------------------
    // TB storage
    // ---------------------------
    integer ii, jj, kk;
    integer acc;
    integer errors;

    reg [7:0]   A [0:35];
    reg [7:0]   B [0:35];
    reg [19:0]  Cgold [0:35];

    reg [7:0]  lo_b;
    reg [7:0]  hi_b;
    reg [7:0]  top_b;
    reg [19:0] c_read20;

    // ------------------------------------------------------------
    // SPI write (MSB-first) tasks
    //
    // IMPORTANT ALIGNMENT:
    //   - DUT samples din at posedge
    //   - TB updates din at negedge
    //   - Therefore, after pulling CS low, we MUST ensure the
    //     first bit is placed on din BEFORE the first posedge.
    // ------------------------------------------------------------

    // Send one byte on both lanes, MSB-first.
    // This version "preloads" the first bit immediately,
    // then advances bits on each negedge.
    task spi_send_byte_dual;
        input [7:0] byteA;
        input [7:0] byteB;
        integer b;
        begin
            // preload first bit (bit7) immediately (no waiting)
            spi_din_a = byteA[7];
            spi_din_b = byteB[7];

            // now shift remaining bits on each negedge
            for (b = 6; b >= 0; b = b - 1) begin
                @(negedge clk);
                spi_din_a = byteA[b];
                spi_din_b = byteB[b];
            end

            // one extra negedge to finish the last bit's sampling window
            @(negedge clk);
        end
    endtask

    task spi_write_frame_AB;
        integer idx;
        begin
            @(negedge clk);
            spi_cs_n = 1'b0;

            for (idx = 0; idx < 36; idx = idx + 1) begin
                spi_send_byte_dual(A[idx], B[idx]);
            end

            @(negedge clk);
            spi_cs_n  = 1'b1;
            spi_din_a = 1'b0;
            spi_din_b = 1'b0;
        end
    endtask

    // ---------------------------
    // SPI read (MISO) tasks
    // NOTE: assume DUT updates miso at posedge, so sample at negedge
    // ---------------------------
    task spi_read_byte_miso;
        output [7:0] data;
        integer b;
        reg [7:0] tmp;
        begin
            tmp = 8'd0;
            for (b = 7; b >= 0; b = b - 1) begin
                @(negedge clk);
                tmp[b] = spi_miso;
            end
            data = tmp;
        end
    endtask

    // ------------------------------------------------------------
    // Readback + compare, robust to DUT gaps between elements
    //
    // Key idea:
    //   DUT readout is NOT a continuous 36*24-bit stream.
    //   Between elements it goes:
    //     NEXT -> LOAD -> WAIT -> LATCH -> SHIFT
    //   TB must re-sync at each element boundary.
    // ------------------------------------------------------------
    task spi_read_and_check_C;
        integer idx;
        begin
            errors = 0;

            // start read frame
            @(negedge clk);
            spi_cs_n  = 1'b0;
            spi_din_a = 1'b0;
            spi_din_b = 1'b0;

            for (idx = 0; idx < 36; idx = idx + 1) begin
                // ? Re-sync at the start of each element's SHIFT phase
                wait (dut.u_c_ro.state == dut.u_c_ro.S_SHIFT);
                wait (dut.u_c_ro.bit_cnt == 0);

                // ? align TB sampling edge
                @(negedge clk);

                // each element: LO -> HI -> TOP (3 bytes)
                spi_read_byte_miso(lo_b);
                spi_read_byte_miso(hi_b);
                spi_read_byte_miso(top_b);

                c_read20 = { top_b[3:0], hi_b, lo_b };

                if (c_read20 !== Cgold[idx]) begin
                    errors = errors + 1;
                    // Uncomment for debug:
                    // $display("Mismatch @%0d: got=%h expected=%h (top=%02h hi=%02h lo=%02h)",
                    //          idx, c_read20, Cgold[idx], top_b, hi_b, lo_b);
                end
            end

            // end frame
            @(negedge clk);
            spi_cs_n = 1'b1;
        end
    endtask

    // ---------------------------
    // main
    // ---------------------------
    initial begin
        // init
        spi_cs_n  = 1'b1;
        spi_din_a = 1'b0;
        spi_din_b = 1'b0;
        start     = 1'b0;

        // reset
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;

        // random A/B
        for (ii=0; ii<36; ii=ii+1) begin
            A[ii] = $random;
            B[ii] = $random;
        end

        // golden 20-bit
        for (ii=0; ii<6; ii=ii+1) begin
            for (jj=0; jj<6; jj=jj+1) begin
                acc = 0;
                for (kk=0; kk<6; kk=kk+1) begin
                    acc = acc + (A[ii*6+kk] * B[kk*6+jj]);
                end
                Cgold[ii*6+jj] = acc[19:0];
            end
        end

        // wait init of C memories
        wait (sys_ready == 1'b1);

        // write A/B via SPI
        spi_write_frame_AB();

        if (spi_error) begin
            $display("FAIL: spi_error asserted during/after load.");
            $finish;
        end

        // wait loaded
        wait (spi_loaded == 1'b1);

        // start (1-cycle pulse)
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        // wait compute done pulse
        wait (done == 1'b1);
        @(posedge clk);

        // read back C via MISO and compare
        spi_read_and_check_C();

        if (errors == 0) begin
            $display("PASS: All 36 outputs match golden (20-bit full precision).");
        end else begin
            $display("FAIL: %0d mismatches.", errors);
        end

        #50;
        $finish;
    end

endmodule





