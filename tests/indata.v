`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CDAC
// Engineer: Nisarg and Shravani
// 
// Create Date: 28.10.2025 09:12:56
// Design Name: 
// Module Name: indata
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


module indata(
    input wire DataValid,
    input wire clk,rst,
    input wire [7:0] data,
    output reg [31:0] A,
    output reg [31:0] B,
    output reg DVO
    );
    
    
    reg [3:0] NumBytes;
    
    reg [7:0] AB [0:7];
    reg state;
    
    localparam READ = 1'b0;
    localparam WRITE = 1'b1;
    
    
    always@(posedge clk or posedge rst)
    if(rst)
    begin 
        DVO <= 1'b0;
        state <= READ;
         NumBytes <= 0;
    end
    else
    case(state)
    READ : begin
               DVO <= 1'b0;
               if(DataValid)
               begin
               if(NumBytes < 8)
               begin
                   AB[NumBytes] <= data;
               end
               NumBytes <= NumBytes + 1;
               end
               if(NumBytes == 4'b1000)
               begin
                   NumBytes <= 4'b0;
                   state <= WRITE;
               end
           end
    WRITE : begin
                 A <= {AB[0],AB[1],AB[2],AB[3]};
                 B <= {AB[4],AB[5],AB[6],AB[7]};
                 DVO <= 1'b1;
                 state <= READ;
            end   
    default : state <= READ;
    endcase
  
endmodule
