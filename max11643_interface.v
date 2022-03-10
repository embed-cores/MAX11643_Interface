module max11643_interface(
	input ref_clk,
	input reset,
	input en,
	input [7:0] START_DELAY,
	output adc_sclk,		
	output adc_cs,
	output adc_din,
	input adc_dout,	
	output reg [7:0] ADC_DATA,
	output [8:0] ADC_RDY
    );

	wire spi_ctrl_done;
	wire spi_ctrl_busy;
	wire [7:0] SPI_CTRL_DOUT;
	
	
	// -----------------------
	
	localparam  [3:0]
			STATE_IDLE          = 4'd0,
			STATE_START         = 4'd1,
			STATE_SETUP         = 4'd2,
			STATE_AVG           = 4'd3,
			STATE_APPLY_CHANNEL = 4'd4,
			STATE_ALT_ZERO      = 4'd5,
			STATE_ALT_ZERO_2    = 4'd6,
			STATE_ADC_DATA      = 4'd7,
			STATE_DONE          = 4'd8,
			STATE_SPI_WRITE     = 4'd9;
			
			


	reg [3:0] NEXT_STATE;
	reg next_spi_ctrl_wr;
	reg [7:0] NEXT_SPI_CTRL_DIN;
	reg [7:0] NEXT_ADC_DATA;
	reg [3:0] NEXT_ADC_CH;
	reg [2:0] NEXT_STATE_STACK;
	reg [7:0] NEXT_CNT;
	reg next_nd;
	
	
	
	reg [3:0] CUR_STATE;
	reg spi_ctrl_wr;
	reg [7:0] SPI_CTRL_DIN;
	reg [2:0] CUR_STATE_STACK;
	reg [3:0] CUR_ADC_CH;
	reg [7:0] CUR_CNT;
	reg cur_nd;
	
	
	always @(posedge ref_clk)
	begin
		if(reset)
		begin
			CUR_STATE       <= STATE_IDLE;
			spi_ctrl_wr     <= 1'b0;
			SPI_CTRL_DIN    <= 8'd0;
			ADC_DATA        <= 8'd0;
			cur_nd          <= 1'b0;
			CUR_ADC_CH      <= 4'd0;
			CUR_CNT         <= 8'd0;
			CUR_STATE_STACK <= STATE_IDLE;
		end
		else
		begin
			CUR_STATE       <= NEXT_STATE;
			spi_ctrl_wr     <= next_spi_ctrl_wr;
			SPI_CTRL_DIN    <= NEXT_SPI_CTRL_DIN;
			ADC_DATA        <= NEXT_ADC_DATA;
			cur_nd          <= next_nd;
			CUR_ADC_CH      <= NEXT_ADC_CH;
			CUR_CNT         <= NEXT_CNT;
			CUR_STATE_STACK <= NEXT_STATE_STACK;
			
		end
	end
	
	// ---------------
	
	always @(*)
	begin
		NEXT_STATE        = CUR_STATE;
		next_spi_ctrl_wr  = 1'b0;
		NEXT_SPI_CTRL_DIN = SPI_CTRL_DIN;
		NEXT_ADC_DATA     = ADC_DATA;
		next_nd           = 1'b0;
		NEXT_ADC_CH       = CUR_ADC_CH;
		NEXT_STATE_STACK  = CUR_STATE_STACK;
		NEXT_CNT          = CUR_CNT;
		
		
		
		case(CUR_STATE)
		
			STATE_IDLE :
			begin
				if(CUR_CNT < START_DELAY)
					NEXT_CNT = CUR_CNT + 8'd1;
				else
					NEXT_STATE = STATE_START;
			end
			
			// *******************
			
			STATE_START :
			begin
				if(~spi_ctrl_busy & en)
				begin
					NEXT_SPI_CTRL_DIN = 8'h78;		// Clock Mode 11 --- Inernal Reference Always On	
					NEXT_STATE_STACK = STATE_SETUP;
					NEXT_STATE = STATE_SPI_WRITE;
				end
			end
			
			// *******************
			
			STATE_SETUP :
			begin
				if(spi_ctrl_done)
				begin
					NEXT_SPI_CTRL_DIN = 8'h20;		// Averaging Off
					NEXT_STATE_STACK = STATE_AVG;
					NEXT_STATE = STATE_SPI_WRITE;
				end
			end
			
			// *******************
			
			STATE_AVG :
			begin
				if(spi_ctrl_done)
				begin
					NEXT_ADC_CH = 4'd0;
					NEXT_STATE = STATE_APPLY_CHANNEL;
				end
			end
			
			// *******************
			
			STATE_APPLY_CHANNEL :
			begin
				NEXT_SPI_CTRL_DIN = {1'b1, CUR_ADC_CH, 3'b111};	// No Scan - Read Channel at once
				NEXT_STATE_STACK = STATE_ALT_ZERO;
				NEXT_STATE = STATE_SPI_WRITE;
			end
			
			// *******************
			
			STATE_ALT_ZERO :
			begin
				if(spi_ctrl_done)
				begin
					NEXT_SPI_CTRL_DIN = 8'd0;
					NEXT_STATE_STACK = STATE_ALT_ZERO_2;
					NEXT_STATE = STATE_SPI_WRITE;
				end
			end
			
			// *******************
			
			STATE_ALT_ZERO_2 :
			begin
				if(spi_ctrl_done)
				begin
					NEXT_ADC_DATA[7:4] = SPI_CTRL_DOUT[3:0];
					NEXT_SPI_CTRL_DIN = 8'd0;
					NEXT_STATE_STACK = STATE_ADC_DATA;
					NEXT_STATE = STATE_SPI_WRITE;
				end
			end
			
			// *******************
			
			STATE_ADC_DATA :
			begin
				if(spi_ctrl_done)
				begin
					NEXT_ADC_DATA[3:0] = SPI_CTRL_DOUT[7:4];
					NEXT_STATE = STATE_DONE;
				end	
			end
			
			// *******************
			
			STATE_DONE :
			begin
				next_nd = 1'b1;
				
				if(CUR_ADC_CH == 4'd8)
					NEXT_ADC_CH = 4'd0;
				else	
					NEXT_ADC_CH = CUR_ADC_CH + 4'd1;
				
				if(en)
					NEXT_STATE = STATE_APPLY_CHANNEL;	
				else	
				begin
					NEXT_CNT = 8'd0;
					NEXT_STATE = STATE_IDLE;
				end	
			end
			
			// *******************
			
			STATE_SPI_WRITE :
			begin
				next_spi_ctrl_wr = 1'b1;
				NEXT_STATE = CUR_STATE_STACK;
			end
			
			// *******************
			
			default :
			begin
				NEXT_CNT = 8'd0;
				NEXT_STATE = STATE_IDLE;
			end
			
			
		endcase
	end	

	// ---------------
	
	reg [8:0] BIT_MASK;
	
	always @(*)
	begin
		case(CUR_ADC_CH)
			4'd0    : begin BIT_MASK = 9'b000000001; end
			4'd1    : begin BIT_MASK = 9'b000000010; end
			4'd2    : begin BIT_MASK = 9'b000000100; end
			4'd3    : begin BIT_MASK = 9'b000001000; end
			4'd4    : begin BIT_MASK = 9'b000010000; end
			4'd5    : begin BIT_MASK = 9'b000100000; end
			4'd6    : begin BIT_MASK = 9'b001000000; end
			4'd7    : begin BIT_MASK = 9'b010000000; end
			4'd8    : begin BIT_MASK = 9'b100000000; end
			default : begin BIT_MASK = 9'b000000000; end
		endcase
	end
	
	assign ADC_RDY = (cur_nd) ? BIT_MASK : 9'd0;
	
	
	// ---------------

	spi_controller		blk_spi_ctrl	(
		.ref_clk(ref_clk),
		.reset(reset),
		.en(en),
		.cs(adc_cs),
		.sclk(adc_sclk),
		.din(adc_din),
		.dout(adc_dout),
		.wr(spi_ctrl_wr),
		.WR_DATA(SPI_CTRL_DIN),
		.DOUT(SPI_CTRL_DOUT),
		.done(spi_ctrl_done),
		.busy(spi_ctrl_busy)     );

endmodule
