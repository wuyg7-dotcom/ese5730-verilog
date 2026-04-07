`timescale 1ns/1ps

module a211oi_1 (
    input  A2,
    input  A1,
    input  B1,
    input  C1,
    output Y
);
    assign Y = ~((A2 & A1) | B1 | C1);
endmodule

module a21oi_1 (
    input  A2,
    input  A1,
    input  B1,
    output Y
);
    assign Y = ~((A2 & A1) | B1);
endmodule

module a22oi_1 (
    input  A2,
    input  A1,
    input  B2,
    input  B1,
    output Y
);
    assign Y = ~((A2 & A1) | (B2 & B1));
endmodule

module a31oi_1 (
    input  A1,
    input  A2,
    input  A3,
    input  B1,
    output Y
);
    assign Y = ~((A1 & A2 & A3) | B1);
endmodule

module inv_1 (
    input  A,
    output Y
);
    assign Y = ~A;
endmodule

module nand2_1 (
    input  A,
    input  B,
    output Y
);
    assign Y = ~(A & B);
endmodule

module nand2b_1 (
    input  A_N,
    input  B,
    output Y
);
    assign Y = ~((~A_N) & B);
endmodule

module nand3_1 (
    input  B,
    input  A,
    input  C,
    output Y
);
    assign Y = ~(B & A & C);
endmodule

module nand3b_1 (
    input  A_N,
    input  C,
    input  B,
    output Y
);
    assign Y = ~((~A_N) & C & B);
endmodule

module nor2_1 (
    input  A,
    input  B,
    output Y
);
    assign Y = ~(A | B);
endmodule

module nor3_1 (
    input  B,
    input  A,
    input  C,
    output Y
);
    assign Y = ~(B | A | C);
endmodule

module o21a_1 (
    input  A1,
    input  A2,
    input  B1,
    output X
);
    assign X = (A1 | A2) & B1;
endmodule

module xor2_1 (
    input  B,
    input  A,
    output X
);
    assign X = B ^ A;
endmodule

module dfxtp (
    input      CLK,
    input      D,
    output reg Q
);
    always @(posedge CLK)
        Q <= D;
endmodule
