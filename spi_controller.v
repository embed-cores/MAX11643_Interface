// * ADC accepts input at Rising edge and puts output at Falling edge
// * MSB First DIN

module spi_controller(
	input ref_clk,
	input reset,
	input en,
	output reg cs,
	output reg sclk,
	output din,
	input dout,
	input wr,
	input [7:0] WR_DATA,
	output reg [7:0] DOUT,
	output reg done,
	output busy
    );
    
	localparam  [2:0]
			STATE_IDLE        = 3'd0,
			STATE_CLK_LOW     = 3'd1,
			STATE_CLK_HIGH    = 3'd2,
			STATE_CLK_PRE_LOW = 3'd3,
			STATE_CHECK_END   = 3'd4,
			STATE_DONE        = 3'd5;
			


	reg [2:0] NEXT_STATE;
	reg [3:0] NEXT_DLY_CNT;
	reg [2:0] NEXT_BIT_CNT;
	reg [7:0] NEXT_WR_SREG;
	reg next_cs;
	reg next_sclk;
	reg next_done;
	reg [7:0] NEXT_DOUT;
	
	
	reg [2:0] CUR_STATE;
	reg [3:0] CUR_DLY_CNT;
	reg [2:0] CUR_BIT_CNT;
	reg [7:0] CUR_WR_SREG;
	
	
	
	always @(posedge ref_clk)
	begin
		if(reset)
		begin
			CUR_STATE   <= STATE_IDLE;
			CUR_DLY_CNT <= 4'd0;
			CUR_BIT_CNT <= 3'd0;
			CUR_WR_SREG <= 8'd0;
			cs          <= 1'b1;
			sclk        <= 1'b0;
			done        <= 1'b0;
			DOUT        <= 8'd0;
		end
		else
		begin
			CUR_STATE   <= NEXT_STATE;
			CUR_DLY_CNT <= NEXT_DLY_CNT;
			CUR_BIT_CNT <= NEXT_BIT_CNT;
			CUR_WR_SREG <= NEXT_WR_SREG;
			cs          <= next_cs;
			sclk        <= next_sclk;
			done        <= next_done;
			DOUT        <= NEXT_DOUT;
		end
	end
	
	// ---------------
	
	always @(*)
	begin
		NEXT_STATE   = CUR_STATE;
		NEXT_DLY_CNT = CUR_DLY_CNT;
		NEXT_BIT_CNT = CUR_BIT_CNT;
		NEXT_WR_SREG = CUR_WR_SREG;
		next_cs      = cs;
		next_sclk    = sclk;
		next_done    = 1'b0;
		NEXT_DOUT    = DOUT;
		

		case(CUR_STATE) 
		
			STATE_IDLE :
			begin
				if(en & wr)
				begin
					NEXT_WR_SREG = WR_DATA;
					NEXT_DLY_CNT = 4'd0;
					NEXT_BIT_CNT = 3'd0;
					next_cs = 1'b0;
					NEXT_STATE = STATE_CLK_LOW;
				end
			end
			
			// *******************
			
			STATE_CLK_LOW :
			begin
				if(CUR_DLY_CNT == 4'd3)
				begin
					next_sclk = 1'b1;
					NEXT_STATE = STATE_CLK_HIGH;
				end	
				else
					NEXT_DLY_CNT = CUR_DLY_CNT + 4'd1;
			end
			
			// *******************
			
			STATE_CLK_HIGH :
			begin
				if(CUR_DLY_CNT == 4'd10)
				begin
					next_sclk = 1'b0;
					NEXT_STATE = STATE_CLK_PRE_LOW;
				end	
				else
					NEXT_DLY_CNT = CUR_DLY_CNT + 4'd1;
			end
			
			// *******************
			
			STATE_CLK_PRE_LOW :
			begin
				if(CUR_DLY_CNT == 4'd12)
				begin
					NEXT_DOUT = {DOUT[6:0], dout};
					NEXT_STATE = STATE_CHECK_END;
				end	
				else
					NEXT_DLY_CNT = CUR_DLY_CNT + 4'd1;
			end
			
			// *******************
			
			STATE_CHECK_END :
			begin
				if(CUR_BIT_CNT == 3'd7)
				begin
					next_cs = 1'b1;
					NEXT_STATE = STATE_DONE;
				end
				else
				begin
					NEXT_WR_SREG = {CUR_WR_SREG[6:0], 1'b0};
					NEXT_BIT_CNT = CUR_BIT_CNT + 3'd1;
					NEXT_DLY_CNT = 4'd0;
					NEXT_STATE = STATE_CLK_LOW;
				end
			end
			
			// *******************
			
			STATE_DONE :
			begin
				next_done = 1'b1;
				NEXT_STATE = STATE_IDLE;
			end
			
			// *******************
			
			default :
			begin
				NEXT_STATE = STATE_IDLE;
			end
			
		endcase
	end		
	
	// ---------------
	
	assign busy = (CUR_STATE != STATE_IDLE);
	assign din = CUR_WR_SREG[7];
    

endmodule
