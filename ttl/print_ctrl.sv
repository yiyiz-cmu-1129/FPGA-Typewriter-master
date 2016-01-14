/*
 * print_ctrl.sv
 *
 * Author: Kais Kudrolli
 *
 * Description: Module that controls printer. 
 */

`define BAUD_NUM 13'd2604 // Number of cycles at 50 MHz to achieve a baud 
                          // of 19200 bps
`define IDLE  1'b1
`define START 1'b0
`define STOP  1'b0

`define SEC_DELAY 26'd50000000
`define WAKE 8'd255

module print_ctrl (
    input  logic       clk, rst_l, rdy, rx,
    input  logic [7:0] char,
    output logic       tx, gnd, done);

    logic [7:0] trans_byte_in;
    logic       trans_done, trans_set_byte;

    assign gnd = 0; 

    proto_fsm pfsm (.clk(clk), .rst_l(rst_l), .trans_done(trans_done), 
                    .recv_rdy(rdy), .recv_byte_in(char), .trans_byte_in(trans_byte_in),
                    .trans_set_byte(trans_set_byte), recv_done(done));
    
    trans_fsm tfsm (.clk(clk), .rst_l(rst_l), .set_byte(trans_set_byte),
                    .byte_in(trans_byte_in), .tx(tx), .done(trans_done));

endmodule: print_ctrl

module proto_fsm (
    input  logic       clk, rst_l, trans_done, recv_rdy,
    input  logic [7:0] recv_byte_in,
    output logic [7:0] trans_byte_in,
    output logic       trans_set_byte, recv_done);

    enum logic {s_init, s_char} cs, ns;

    logic [25:0] delay_count;
    logic inc_delay;


    always_ff @(posedge clk, negedge rst_l) begin
        if (~rst_l) begin
            cs <= s_init;
            delay_count <= 26'd0;
        end 
        else begin
            cs <= ns;
            delay_count <= (inc_delay) ? delay_count + 26'd1 : delay_count;
        end
    end

    always_comb begin
        ns = s_char;
        trans_byte_in = 8'd0;
        trans_set_byte = 1'b0;
        recv_done = 1'b0;
        inc_delay = 1'b0;

        case (cs) 
            s_delay: begin
                ns = (delay_count == `SEC_DELAY) ? s_init : s_delay;
                inc_delay = 1'b1;
            end
            s_init: begin
                ns = (trans_done) ? s_char : s_init;
                trans_byte_in = `WAKE; 
                trans_set_byte = ~trans_done;
            end
            s_char: begin
                ns = s_char;
                trans_byte_in = recv_byte_in;
                trans_set_byte = ~trans_done && recv_rdy;
                recv_done = trans_done;
            end
        endcase
    end

endmodule: proto_fsm

// Sends one TTL frame - one byte of data.
module trans_fsm (
    input  logic       clk, rst_l, set_byte,
    input  logic [7:0] byte_in,
    output logic       tx, done);

    enum logic [1:0] {s_idle, s_start, s_trans, s_stop} cs, ns;

    logic [12:0] sample_count;
    logic [3:0]  bit_count;
    logic [7:0]  trans_byte;
    logic        clr_bit, inc_bit, clr_sample, inc_sample;
    logic        clr_byte, shift;

    always_ff @(posedge clk, negedge rst_l) begin
        if (~rst_l) begin
            cs <= s_idle;
            sample_count <= 'd0;
            bit_count <= 'd0;
            trans_byte <= 8'd0;
        end 
        else begin
            cs <= ns;
            sample_count <= (clr_sample) ? 'd0 : 
                            ((inc_sample) ? sample_count + 'd1 : sample_count);
            bit_count <= (clr_bit) ? 'd0 : 
                         ((inc_bit) ? bit_count + 'd1 : bit_count);
            trans_byte <= (clr_byte) ? 'd0 :
                          ((shift) ? {1'b0, trans_byte[7:1]} :
                          ((set_byte) ? byte_in : trans_byte));
        end
    end

    always_comb begin
        ns = s_idle;
        inc_bit = 1'b0;
        clr_bit = 1'b0;
        inc_sample = 1'b0;
        clr_sample = 1'b0;
        clr_byte = 1'b0;
        shift = 1'b0;
        tx = `IDLE;
        done = 1'b0;

        case (cs)
            s_idle: begin
                ns = (set_byte) ? s_start : s_idle; 
                tx = `IDLE;
            end
            s_start: begin
                ns = (sample_count == `BAUD_NUM) ? s_trans : s_start;
                tx = `START;
                inc_sample = 1'b1;
                clr_sample = (sample_count == `BAUD_NUM);
            end
            s_trans: begin
                ns = (bit_count == 4'd8) ? s_stop : s_trans;
                tx = trans_byte[0];
                shift = (sample_count == `BAUD_NUM);
                inc_bit = (sample_count == `BAUD_NUM);
                inc_sample = 1'b1;
                clr_sample = (sample_count == `BAUD_NUM);
                clr_bit = (sample_count == `BAUD_NUM);
            end
            s_stop: begin
                ns = (sample_count == `BAUD_NUM) ? s_idle : s_stop;
                tx = `STOP;
                clr_byte = (sample_count == `BAUD_NUM);
                inc_sample = 1'b1;
                clr_sample = (sample_count == `BAUD_NUM);
                done = (sample_count == `BAUD_NUM);
            end
        endcase

    end

endmodule: trans_fsm
