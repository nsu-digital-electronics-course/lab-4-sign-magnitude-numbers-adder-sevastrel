`timescale 1ns / 1ps
module summator #(parameter int SIZE = 32)
    (
    input logic [SIZE-1:0] a,
    input logic[SIZE-1:0] b,
    output logic [SIZE-1:0] s,
    output logic overflow
    );
    
    logic a_sign;
    logic b_sign;
    logic [SIZE-2:0] a_mod;
    logic [SIZE-2:0] b_mod;
    logic [SIZE-2:0] sum;
//    logic overflow;
    
    logic result_sign;
    
    assign a_mod=a[SIZE-2:0];
    assign b_mod=b[SIZE-2:0];
    assign a_sign = a[SIZE-1];
    assign b_sign = b[SIZE-1];
  
    always_comb begin
        overflow=1'b0;
        sum=0;
        result_sign=1'b0;
        if (a_sign==b_sign) begin
            {overflow,sum} = a_mod + b_mod;
            result_sign = a_sign;
        end else begin
            if (a_mod==b_mod) begin
                result_sign=1'b0;
                sum = 1'b0;
            end else if (a_mod>b_mod) begin
                result_sign=a_sign;
                sum = a_mod - b_mod;
            end else begin
                result_sign=b_sign;
                {overflow,sum} = b_mod- a_mod;
            end 
        end
        if (sum == '0) result_sign = 1'b0;
        s = {result_sign, sum}; 
    end
//    always_comb begin 
//        if (overflow) begin 
//            result_sign=1'b0;
//            sum=0;
//        end 
//    end
endmodule
