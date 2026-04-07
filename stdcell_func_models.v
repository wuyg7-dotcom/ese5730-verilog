`timescale 1ns/1ps

// --- 基础门电�? ---

// 反相�?: 端口 A, Y
module inv_1 (input A, output Y);
  assign Y = ~A;
endmodule

// 缓冲�?: 端口 A, Y
module buf_1 (input A, output X);
  assign X = A;
endmodule

// 2输入与非�?: 端口 A, B, Y
module nand2_1 (input A, B, output Y);
  assign Y = ~(A & B);
endmodule

// 3输入与非�?: 端口 A, B, C, Y
module nand3_1 (input A, B, C, output Y);
  assign Y = ~(A & B & C);
endmodule

// 2输入或非�?: 端口 A, B, Y
module nor2_1 (input A, B, output Y);
  assign Y = ~(A | B);
endmodule

// 3输入或非�?: 端口 A, B, C, Y
module nor3_1 (input A, B, C, output Y);
  assign Y = ~(A | B | C);
endmodule

// 2输入异或�?: 端口 A, B, X (注意网表�? XOR 通常输出�? X)
module xor2_1 (input A, B, output X);
  assign X = A ^ B;
endmodule

// --- 带取反输入的�? (B后缀) ---

// 端口 A_N (取反), B, Y
module nand2b_1 (input A_N, B, output Y);
  assign Y = ~( (~A_N) & B );
endmodule

// 端口 A_N (取反), B, C, Y
module nand3b_1 (input A_N, B, C, output Y);
  assign Y = ~( (~A_N) & B & C );
endmodule

// --- 复合逻辑 (AOI/OAI) ---

// a21oi: 端口 A1, A2, B1, Y
module a21oi_1 (input A1, A2, B1, output Y);
  assign Y = ~((A1 & A2) | B1);
endmodule

// a22oi: 端口 A1, A2, B1, B2, Y
module a22oi_1 (input A1, A2, B1, B2, output Y);
  assign Y = ~((A1 & A2) | (B1 & B2));
endmodule

// a31oi: 端口 A1, A2, A3, B1, Y
module a31oi_1 (input A1, A2, A3, B1, output Y);
  assign Y = ~((A1 & A2 & A3) | B1);
endmodule

// a211oi: 端口 A1, A2, B1, C1, Y
module a211oi_1 (input A1, A2, B1, C1, output Y);
  assign Y = ~((A1 & A2) | B1 | C1);
endmodule

// o21ai: 端口 A1, A2, B1, Y
module o21ai_1 (input A1, A2, B1, output Y);
  assign Y = ~((A1 | A2) & B1);
endmodule

// o21a: 端口 A1, A2, B1, X (非反相输�?)
module o21a_1 (input A1, A2, B1, output X);
  assign X = (A1 | A2) & B1;
endmodule

// --- 选择�? ---

// mux2: 端口 A0, A1, S, X
module mux2 (input A0, A1, S, output X);
  assign X = S ? A1 : A0;
endmodule

// mux2i: 端口 A0, A1, S, Y (反相输出)
module mux2i (input A0, A1, S, output Y);
  assign Y = ~(S ? A1 : A0);
endmodule

// --- 时序单元 ---

// dfxtp: 端口 CLK, D, Q
module dfxtp (
  input CLK,
  input D,
  output reg Q
);
  // 仿真初始化，防止 X 态传�?
  initial Q = 1'b0; 

  always @(posedge CLK) begin
    Q <= D;
  end
endmodule