module ChipInterface(

	input bit PS2_KBCLK,
	input bit PS2_KBDAT,
	input bit CLOCK_50,
	input bit KEY[0],
	output bit [17:0] LEDR);

	bit[7:0] led_reg;
	bit parity_error_reg;
	bit rdy_reg;
	bit rst_l;

	assign rst_l = KEY[0];

	keyboard(.clk_k(PS2_KBCLK), .data(PS2_KBDAT), .led(led_reg), 
			.parity_error(parity_error_reg), .rdy(rdy_reg));

	always_ff @(posedge CLOCK_50, negedge rst_l) begin
		if (~rst_l) begin
			LEDR <= 18'b0;
		end
		else begin
			LEDR[7:0] <= led_reg;
			LEDR[16] <= parity_error_reg;
			LEDR[17] <= rdy_reg;
		end
	end

endmodule