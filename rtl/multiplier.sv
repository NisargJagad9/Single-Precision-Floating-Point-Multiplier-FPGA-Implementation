`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CDAC
// Engineer: Nisarg and Shravani
// 
// Create Date: 29.10.2025 07:46:44
// Design Name: 
// Module Name: outdata
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

module pmultiplier(
    input wire [31:0] A, B,
    input wire clk, rst, DV,
    output reg [31:0] Z,
    output reg exception, underflow, overflow,
    output reg done                     // NEW: done flag
);

    reg sign_Z, normalized, rounded, zero, guard, round, sticky, round_up;
    reg [8:0] exp_prod;
    reg [23:0] operand_A, operand_B;
    reg [47:0] product, product_normed;
    reg [8:0] exp_adjust;
    reg [5:0] lz_count;

    // Fix: Function cannot contain `disable` in synthesizable code
    // We'll compute leading zeros in combinational logic instead
    reg [47:0] product_shifted;
    reg need_normalize;
    integer i;
    
    reg [1:0] state;
    
    localparam IDLE = 3'b000;
    localparam COMPUTE = 3'b001;
    localparam CHECKNORM = 3'b010;
    localparam NORMALISE = 3'b011;
    localparam EXPC = 3'b100;
    localparam EXPF = 3'b101;
    localparam WRITE = 3'b110;
   
    
    

    
    always @(*) begin
        // Leading zero count logic (combinational)
        lz_count = 6'd48;
        for (i = 47; i >= 0; i = i - 1) begin : lup
            if (product[i]) begin
                lz_count = 47 - i;
                disable lup ;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Z <= 32'b0;
            exception <= 1'b0;
            underflow <= 1'b0;
            overflow  <= 1'b0;
            done      <= 1'b0;

            sign_Z <= 1'b0;
            operand_A <= 24'b0;
            operand_B <= 24'b0;
            product <= 48'b0;
            product_normed <= 48'b0;
            exp_adjust <= 9'b0;
            exp_prod <= 9'b0;
            guard <= 1'b0;
            round <= 1'b0;
            sticky <= 1'b0;
            round_up <= 1'b0;
            zero <= 1'b0;
            rounded <= 1'b0;
        end else begin
            case(state)
            // Default done low
            IDLE : begin
                   done <= 1'b0;
                   if(DV)
                   begin
                    // Sign bit
                    sign_Z <= A[31] ^ B[31];

                    // Exception: Inf or NaN
                    exception <= (&A[30:23] || &B[30:23]);
        
                    // Implicit bit
                    operand_A <= (|A[30:23]) ? {1'b1, A[22:0]} : {1'b0, A[22:0]};
                    operand_B <= (|B[30:23]) ? {1'b1, B[22:0]} : {1'b0, B[22:0]};
                    
                    state <= COMPUTE;
                    end
                    end
            COMPUTE : begin
                    // Multiply mantissas
                    product <= operand_A * operand_B;
                    state <= CHECKNORM;
                      end
            CHECKNORM : begin
                        // Determine if we need to normalize left ( leading 1 not at [47] )
                        need_normalize <= (product != 0) && !product[47];
                        state <= NORMALISE;
                        end   
            // Normalize
           NORMALISE: begin
                         state <= EXPC;
                         if (need_normalize)
                            product_normed <= product << lz_count;
                        else
                            product_normed <= product >> 1;  // Denormalize if overflow in product
            
                        // Exponent adjustment
                        if (need_normalize)
                            exp_adjust <= $signed({3'b000, lz_count}) - 1;
                        else if (product == 0)
                            exp_adjust <= 9'b0;
                        else
                            exp_adjust <= 9'b1;
                        end
            EXPC : begin
            // Exponent sum with bias
            exp_prod <= A[30:23] + B[30:23] - 8'd127 + exp_adjust;

            // Round bits (from normalized product)
            guard  <= product_normed[22];
            round  <= product_normed[21];
            sticky <= |product_normed[20:0];
            round_up <= guard & (round | sticky);
            state <= EXPF;
                     end
            // Overflow / Underflow
            EXPF: begin
                         overflow  <= (!exp_prod[8] && exp_prod > 9'd255);
                         underflow <= (exp_prod[8] || exp_prod < 9'd1);
                         state <= WRITE;
                    end
            WRITE : begin
            // Final output
            if (exception)
                Z <= 32'b0;
            else if (zero)
                Z <= {sign_Z, 31'b0};
            else if (overflow)
                Z <= {sign_Z, 8'hFF, 23'b0};
            else if (underflow)
                Z <= {sign_Z, 31'b0};
            else
                Z <= {sign_Z, exp_prod[7:0], (product_normed[46:24] + round_up)};

            // Assert done when computation is complete
            done <= 1'b1;  // Result is valid this cycle
           end
           default : state <= IDLE;
           endcase
        end
    end

endmodule
