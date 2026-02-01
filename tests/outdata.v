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


module outdata
  #(parameter CLKS_PER_BIT = 100)
  (
   input             i_Clock,
   input             i_Tx_Start,        // Start transmission of 32-bit data
   input      [31:0] i_Tx_Data_32bit,   // 32-bit data to send
   output            o_Tx_Active,       // High when transmitting
   output            o_Tx_Serial,       // Serial output line
   output            o_Tx_Done          // Pulse when all 4 bytes sent
   );

  // Internal signals
  reg [1:0]  byte_index;               // Tracks which byte (0 to 3) to send
  reg [7:0]  current_byte;             // Current 8-bit byte to send
  reg        tx_dv;                    // Data valid to uart_tx
  wire       tx_done;                  // Done signal from uart_tx
  wire       tx_active;                // Active signal from uart_tx

  // State machine states
  localparam IDLE    = 2'b00;
  localparam SEND    = 2'b01;
  localparam WAIT    = 2'b10;
  localparam DONE    = 2'b11;

  reg [1:0]  state;

  // Instantiate the 8-bit UART transmitter
  uart_tx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) uart_inst (
    .i_Clock(i_Clock),
    .i_Tx_DV(tx_dv),
    .i_Tx_Byte(current_byte),
    .o_Tx_Active(tx_active),
    .o_Tx_Serial(o_Tx_Serial),
    .o_Tx_Done(tx_done)
  );

////////////////////////////////////////////////////////////////////

reg [19:0] debounce_cnt;
reg btn_stable;

always @(posedge i_Clock) begin
  if (i_Tx_Start != btn_stable) begin
    debounce_cnt <= debounce_cnt + 1;
    if (debounce_cnt == 20'd1_000_000) begin  // 10 ms
      btn_stable <= i_Tx_Start;
      debounce_cnt <= 0;
    end
  end else begin
    debounce_cnt <= 0;
  end
end



//////////////////////////////////////////////////////////////////
  // Assign outputs
  assign o_Tx_Active = (state != IDLE);  // Active during SEND and WAIT
  assign o_Tx_Done   = (state == DONE);

  always @(posedge i_Clock) begin
    case (state)
      IDLE: begin
        byte_index <= 0;
        tx_dv      <= 0;
        if (btn_stable) begin
          // Load first byte (LSB first or MSB first? Here: LSB first)
          current_byte <= i_Tx_Data_32bit[7:0];
          tx_dv        <= 1;
          state        <= SEND;
        end
      end

      SEND: begin
        tx_dv <= 0;  // Pulse tx_dv for one cycle
        state <= WAIT;
      end

      WAIT: begin
        if (tx_done) begin
          if (byte_index == 2'd3) begin
            state <= DONE;
          end else begin
            byte_index   <= byte_index + 1;
            case (byte_index)
              2'd0: current_byte <= i_Tx_Data_32bit[15:8];
              2'd1: current_byte <= i_Tx_Data_32bit[23:16];
              2'd2: current_byte <= i_Tx_Data_32bit[31:24];
            endcase
            tx_dv  <= 1;
            state  <= SEND;
          end
        end
      end

      DONE: begin
        state <= IDLE;
      end

      default: state <= IDLE;
    endcase
  end

endmodule