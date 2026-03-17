`timescale 1ns / 1ps

module summator_tb #(parameter int SIZE=32
    );
    logic [SIZE-1:0] a, b, s;
    logic overflow;
    
    // === Вспомогательные сигналы для референс-модели ===
    logic [SIZE:0] ia, ib, expected_sum, abs_sum;
    logic [SIZE-2:0] max_mag;
    logic [SIZE-1:0] expected_s;
    logic expected_overflow;
    logic pass;
    summator #(.SIZE(SIZE)) dut(
        .a(a),
        .b(b),
        .s(s),
        .overflow(overflow));
    
    localparam int NTEST = 36;

    logic [SIZE-1:0] a_vec[NTEST];
    logic [SIZE-1:0] b_vec[NTEST];
    
    int pass_count = 0;
    int fail_count = 0;

    // =========================================================================
    // 4. РЕФЕРЕНС-МОДЕЛЬ (ПОЛНОСТЬЮ ПАРАМЕТРИЗУЕМАЯ)
    // =========================================================================
    
    // Конвертация Sign-Magnitude → вектор (с расширением на 1 бит для знака)
    function automatic logic [SIZE:0] sm_to_signed(input logic [SIZE-1:0] sm);
    logic [SIZE-1:0] mag;
    mag = {1'b0, sm[SIZE-2:0]};  // Zero-extend magnitude
    
    if (sm[SIZE-1] == 1'b0) begin
        return {1'b0, mag};  // Positive
    end else begin
        return -mag;  // ✅ Negative: two's complement negation
    end
endfunction

    // Конвертация вектор → Sign-Magnitude (с нормализацией)
    function automatic logic [SIZE-1:0] signed_to_sm(input logic [SIZE:0] val);
    logic [SIZE-2:0] mag;
    logic sign;
    logic [SIZE:0] abs_val;
    
    if (val[SIZE] == 1'b1) begin  // Negative in two's complement
        sign = 1'b1;
        abs_val = -val;  // ✅ Get absolute value via two's complement
    end else begin
        sign = 1'b0;
        abs_val = val;
    end
    
    mag = abs_val[SIZE-2:0];
    
    // Normalize zero
    if (mag == '0) sign = 1'b0;
    
    return {sign, mag};
endfunction
    initial begin
        a_vec[0]={SIZE{1'b0}};          b_vec[0]={SIZE{1'b0}}; //два нуля+
        a_vec[1]={1'b0,{SIZE-1{1'b0}}}; b_vec[1]={1'b0,{SIZE-1{1'b0}}}; //два нуля-
        
        a_vec[2] = {1'b0,{SIZE-2{1'b0}},1'b1};      b_vec[2] = {1'b1,{SIZE-2{1'b0}},1'b1}; //1+(-1)=0+
        a_vec[3] = {1'b1,{SIZE-2{1'b0}},1'b1};      b_vec[3] = {1'b0,{SIZE-2{1'b0}},1'b1}; //-1+1=0+
        
        a_vec[4] = {1'b0,{SIZE-2{1'b0}},1'b1};      b_vec[4] = {SIZE{1'b0}}; //1+0=0+
        a_vec[5] = {1'b0,{SIZE-2{1'b0}},1'b1};      b_vec[5] = {1'b0,{SIZE-1{1'b0}}}; //1+(-0)=0+
        a_vec[6] = {1'b1,{SIZE-2{1'b0}},1'b1};      b_vec[6] = {SIZE{1'b0}}; //-1+0=0+
        a_vec[7] = {1'b1,{SIZE-2{1'b0}},1'b1};      b_vec[7] = {1'b0,{SIZE-1{1'b0}}}; //-1+(-0)=0+

        a_vec[8] = {1'b0,{SIZE-1{1'b1}}};           b_vec[8] = {{SIZE-1{1'b0}},1'b1}; //MAX_SIZE+1=OVERFLOW
        a_vec[9] = {SIZE{1'b1}};                    b_vec[9] = {1'b1,{SIZE-2{1'b0}},1'b1}; //-MAX_SIZE-1=OVERFLOW        
        
        a_vec[10] = {1'b0,{SIZE-1{1'b1}}};          b_vec[10] = {1'b0,{SIZE-1{1'b1}}}; //MAX_SIZE+MAX_SIZE=OVERFLOW
        a_vec[11] = {1'b1,{SIZE-1{1'b1}}};          b_vec[11] = {1'b1,{SIZE-1{1'b1}}}; //-MAX_SIZE+(-MAX_SIZE)=OVERFLOW
        
        a_vec[12] = {1'b0,1'b1,{SIZE-2{1'b0}}};     b_vec[12] = {1'b0,1'b1,{SIZE-2{1'b0}}}; //Сложение в старшем бите=OVERFLOW
        a_vec[13] = {1'b1,1'b1,{SIZE-2{1'b0}}};     b_vec[13] = {1'b1,1'b1,{SIZE-2{1'b0}}}; //Сложение в старшем бите=OVERFLOW (с минусом)
        
        a_vec[14] = {1'b0,{SIZE-2{1'b0}},1'b1};     b_vec[14] = {1'b0,{SIZE-2{1'b0}},1'b1}; //1+1=2
        a_vec[15] = {1'b1,{SIZE-2{1'b0}},1'b1};     b_vec[15] = {1'b1,{SIZE-2{1'b0}},1'b1}; //-1+(-1)=-2
        
        a_vec[16] = {1'b0,{SIZE-3{1'b0}},1'b1,1'b0};     b_vec[16] = {1'b0,{SIZE-2{1'b0}},1'b1}; //2+1=3
        a_vec[17] = {1'b0,{SIZE-2{1'b0}},1'b1};          b_vec[17] = {1'b0,{SIZE-3{1'b0}},1'b1,1'b0}; //1+2=3

        a_vec[18] = {1'b1,{SIZE-3{1'b0}},1'b1,1'b0};     b_vec[18] = {1'b1,{SIZE-2{1'b0}},1'b1}; //-2+(-1)=-3
        a_vec[19] = {1'b1,{SIZE-2{1'b0}},1'b1};     b_vec[19] = {1'b1,{SIZE-3{1'b0}},1'b1,1'b0}; //-1+(-2)=-3

        a_vec[20]={1'b0,{SIZE-7{1'b0}},6'd50};     b_vec[20]={1'b0,{SIZE-7{1'b0}},6'd50}; //50+50=100
        a_vec[21]={1'b1,{SIZE-7{1'b0}},6'd50};     b_vec[21]={1'b1,{SIZE-7{1'b0}},6'd50}; //-50+(-50)=-100
        
        a_vec[22]={1'b0,{SIZE-8{1'b0}},7'd100};     b_vec[22]={1'b0,{SIZE-8{1'b0}},7'd100}; //100+100=200
        a_vec[23]={1'b1,{SIZE-8{1'b0}},7'd100};     b_vec[23]={1'b1,{SIZE-8{1'b0}},7'd100}; //-100+(-100)=-200
        
        a_vec[24]={1'b0,{SIZE-9{1'b0}},8'd39};     b_vec[24]={1'b0,{SIZE-8{1'b0}},8'd74}; //39+74=113
        a_vec[25]={1'b0,{SIZE-9{1'b0}},8'd39};     b_vec[25]={1'b1,{SIZE-8{1'b0}},8'd74}; //39-74=-35

        a_vec[26]={1'b0,{SIZE-17{1'b0}},16'd1576};     b_vec[26]={1'b0,{SIZE-17{1'b0}},16'd567}; //1576+567=2143
        a_vec[27]={1'b1,{SIZE-17{1'b0}},16'd323};     b_vec[27]={1'b0,{SIZE-17{1'b0}},16'd908}; //-323+908=585
        a_vec[28]={1'b0,{SIZE-17{1'b0}},16'd12670};     b_vec[28]={1'b1,{SIZE-17{1'b0}},16'd1908}; //12670-1908=10762
        a_vec[29]={1'b1,{SIZE-17{1'b0}},16'd7};     b_vec[29]={1'b0,{SIZE-17{1'b0}},16'd2239}; //-7+2239=2231
        
        a_vec[30] = {1'b0,{SIZE-21{1'b0}}, 20'd654321};    b_vec[30] = {1'b0, {SIZE-21{1'b0}}, 20'd123456}; //654321+123456=777_777
        a_vec[31] = {1'b0,{SIZE-21{1'b0}}, 20'd654321};    b_vec[31] = {1'b1, {SIZE-21{1'b0}}, 20'd123456}; //654321-123456=530865
        a_vec[32] = {1'b0,{SIZE-29{1'b0}},28'hFFFFFF};    b_vec[32] = {1'b0,{SIZE-29{1'b0}},28'hFFFFFF}; //FFFFFF+FFFFFF=1FFFFFFE
        a_vec[33] = {1'b0,{SIZE-29{1'b0}},28'h5555555};    b_vec[33] = {1'b0,{SIZE-29{1'b0}},28'hAAAAAAA}; //0101...+1010...=1111...
        a_vec[34] = {32'hDEAD_BEEF};    b_vec[34] = {32'hDEAD_BEEF}; //DEAD_BEEF+DEAD_BEEF=OVERFLOW
        a_vec[35] = {1'b0,31'hBADF00D};    b_vec[35] = {1'b1,31'hBADF00D}; //BADF00D+(-BADF00D)=0+ 
    end
   initial begin
    // Печатаем заголовок таблицы
    $display("--------------------------------------------------------------------------------");
    $display(" Test |      A       |      B       |      S       | Overflow | Expected S | Status");
    $display("--------------------------------------------------------------------------------");
     for (int i = 0; i < NTEST; i++) begin
            a = a_vec[i];
            b = b_vec[i];
            #10;
            
            // Считаем ожидаемый результат через референс-модель
            ia = sm_to_signed(a);
            ib = sm_to_signed(b);
            expected_sum = ia + ib;
            
            // Вычисляем ожидаемый флаг переполнения
            expected_overflow = 1'b0;

// Получаем абсолютное значение суммы (используем уже объявленный abs_sum)
if (expected_sum[SIZE] == 1'b1) begin  // Отрицательная
    abs_sum = -expected_sum;  // Two's complement negation
end else begin
    abs_sum = expected_sum;   // Положительная - как есть
end

// ✅ Переполнение: если бит [SIZE-1] абсолютного значения = 1
// Это значит, модуль >= 2^(SIZE-1), не помещается в SIZE-1 бит
if (abs_sum[SIZE-1] == 1'b1) begin
    expected_overflow = 1'b1;
end
            
            expected_s = signed_to_sm(expected_sum);
            
            // Сравниваем с реальным выходом DUT
            pass = (s == expected_s) && (overflow == expected_overflow);
            
            if (pass) pass_count++;
            else      fail_count++;
            
            $display(" %4d | %10h | %10h | %10h | %b  |    %b   | %s",
                     i, a, b, s, overflow, expected_s,
                     pass ? "PASS" : "FAIL");
    
    end
    $display("--------------------------------------------------------------------------------");
    $display(" TOTAL: PASS=%0d, FAIL=%0d", pass_count, fail_count);
    $finish;
end   
endmodule
