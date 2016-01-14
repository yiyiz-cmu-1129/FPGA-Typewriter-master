/* Build18 keyboard controller *
 * Date Created: 1/11/15       *
 * Data last edit: 1/11/15     */

module keyboard(
  input bit clk_k, //clk of the keyboard
  input bit data, //data from the keyboard 
  output bit [7:0] led, //printing data from led
  output bit parity_error, //check for parity error
  output bit rdy); // ready signal 

  reg [9:0] register; 
  bit [3:0] counter; 

  assign led = register[9:2];
  assign parity = register[1];

  always_ff@(negedge clk_k)
    begin
      register <= {register[8:0], data};
      if(counter == 4'b1011)
        counter <= 4'b0000; 
      else 
        counter <= counter + 4'b1;  
    end     

  always_ff@(posedge clk_k)
    begin
      if(counter == 4'b1011) 
        if(!parity == ^led)
          rdy <= 1'b1;
        else 
          parity_error <= 1'b1;
      else begin
        rdy <= 1'b0;
        parity_error <= 1'b0; 
      end 
    end 

endmodule 



