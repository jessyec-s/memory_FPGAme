`timescale 1ns / 1ns
module memory_game(
	// top level module
	input [3:0]KEY,
	input CLOCK_50,
	output [6:0]HEX0,
	
			// The ports below are for the VGA output.  Do not change.
	output VGA_CLK,   				//	VGA Clock
	output VGA_HS,					//	VGA H_SYNC
	output VGA_VS,					//	VGA V_SYNC
	output VGA_BLANK_N,				//	VGA BLANK
	output VGA_SYNC_N,				//	VGA SYNC
	output [7:0]	VGA_R,				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output [7:0]	VGA_G,	 				//	VGA Green[7:0]
	output [7:0]	VGA_B  				//	VGA Blue[7:0]
 );
		wire [3:0] count_right;
		wire [8:0] colour;
		wire [7:0] x;
		wire [6:0] y;
		wire vga_enable;
		wire [3:0]current_card_top;
		
	// VGA logic
	vga_adapter VGA(
			.resetn(KEY[0]),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(vga_enable),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 3;
		defparam VGA.BACKGROUND_IMAGE = "start_game.mif";
		
		semi_top_memory_game call1 (
			// contains all our game logic
				//inputs from player 
				.resetn(KEY[0]),
				.right(~KEY[1]),
				.wrong(~KEY[2]),
				.start(~KEY[3]),
				.clk(CLOCK_50),
				//outputs to VGA and hex display
				.x(x),
				.y(y),
				.colour(colour[8:0]),
				.current_card_top(current_card_top),
				.vga_enable(vga_enable)
		);
		hex_decoder U2(current_card_top,HEX0); // display current card
		

 
endmodule


 module semi_top_memory_game(
 	// contains instantiations of modules controlling the monitor visuals and game logic respectively
		input resetn, right, wrong, start, clk, // from top level module 
		output [7:0]x, // x coorddinate for VGA display
		output [6:0]y, // y coordinate for VGA display
		output [8:0]colour, // colour for VGA display
		output [3:0]current_card_top, // card number for hex display
		output vga_enable // enable or dissable new VGA plotting 
	 );
	
		wire count;
		wire[3:0] current_card;
		assign current_card_top=current_card;
		wire show_game_over_screen; // output signal from project, input signal to vgafsm signifying game over 
	 
	 project M1(
	 	//inputs
	 .resetn(resetn),
	 .right(right),
	 .wrong(wrong),
	 .start(start),
	 .clk(clk),
	 //outputs
	 .current_card(current_card),// card currently on screen
	 .next_card_data_output(count), // signifies that next card should be displayed
	 .show_game_over_screen(show_game_over_screen)// signal to show game over screen -- input of vgafsm
	 );
	 
	 vgafsm vgayay(
	 	//inputs
		.start(start),
		.clock(clk),
		.resetn(resetn),
		.card_displayed(current_card), 
		.show_game_over_screen(show_game_over_screen),
		//outputs
		.colour(colour[8:0]),// colour to be displayed on vga
		.x_plot(x),// x coord for vga
		.y_plot(y), // y coord for vga
		.vga_enable(vga_enable) // enable vga plot

					);
endmodule

module project(
  input resetn,// active low reset
	input right, // 1 signifies right
	input wrong, // 1 signifies wrong
	input start, // start game
	input clk,
	output [3:0]current_card, // current card to display on vga
	output next_card_data_output, // signifies new card should be displayed  
	output show_game_over_screen // 1 -- show game over screen, 0 -- show current screen

  //outputs

  );
  
  // card numbers in sequence for display 
  wire[3:0] card_original_0,card_original_1,card_original_2,card_original_3,card_original_4,card_original_5;
  wire[3:0]card_original_6,card_original_7,card_original_8,card_original_9,card_original_10;

  wire [27:0]speed;// corresponds to 3 seconds
  wire game_over_internal;// output of data path input of control path 

  // card numbers 
  assign card_original_0='d1;
  assign card_original_1='d4;
  assign card_original_2='d4;
  assign card_original_3='d2;
  assign card_original_4='d3;
  assign card_original_5='d2;
  assign card_original_6='d2;
  assign card_original_7='d6;
  assign card_original_8='d5;
  assign card_original_9='d6;
  assign card_original_10='d7;
  
  wire[10:0] correctness_sequence; //sequence of values to check user input against
  //0 means no match; 1 -> match
  assign correctness_sequence[0]=0; //card 0 vs 1
  assign correctness_sequence[1]=1; //card 1 vs 2
  assign correctness_sequence[2]=0; //2v3
  assign correctness_sequence[3]=0; //3v4
  assign correctness_sequence[4]=0; //4v5
  assign correctness_sequence[5]=1; //5v6
  assign correctness_sequence[6]=0; //6v7
  assign correctness_sequence[7]=0; //7v8
  assign correctness_sequence[8]=0; //8v9
  assign correctness_sequence[9]=0; //9 v 10
  assign correctness_sequence[10]=0; //10v0
  
  assign speed = 'd64999999;// will count down to zero in 3 seconds;
  
  wire analyse,done_analysing; // begin analysing player's answer, done analysing player's answer
  wire next_card_control_output; // tell shift register in datapath to shift, outputing next card
  wire output_correct_answer; // tell shift register in control path to shift, outputting next 0/1 in correctness_sequence
  wire store_user_input;// 1 in time period when player could click a button

  control U1(
     // inputs
    .start(start), 											// from switch/ key
    .resetn(resetn),										// from switch/key
	.clk(clk),
	.done_analysing(done_analysing),
    .next_card(next_card_data_output), 						// input to control path from data oath
    .game_over(game_over_internal),							// from data path
    //outputs
    .output_correct_answer(output_correct_answer),  		// going to data path
    .next_card_output(next_card_control_output),			// going to data path from control path 
    .analyse(analyse),
	.store_user_input(store_user_input),
	.show_game_over_screen(show_game_over_screen)
	 // going to datapath
  );
    
  datapath U0(
    .card_original_0(card_original_0),					// origonal card sequence upon start of game
    .card_original_1(card_original_1),
    .card_original_2(card_original_2),
    .card_original_3(card_original_3),
    .card_original_4(card_original_4),
    .card_original_5(card_original_5),
    .card_original_6(card_original_6),
    .card_original_7(card_original_7),
    .card_original_8(card_original_8),
    .card_original_9(card_original_9),
    .card_original_10(card_original_10),
    .next_card(next_card_control_output), 				// from control path -- is 1'b1 when correct amount of time has gone by
    .speed(speed),										// from top level module, determining how fast the cards will change
    .wrong(wrong), 
    .right(right), 										// from top level module from keys  pressed by player
    .correctness_val(correctness_sequence),
    .output_correct_answer(output_correct_answer),		// signal from control path -same as next_card, excpet not enabled when the 1st card is shown
    .analyse(analyse),
	.clk(clk),											
	.resetn(resetn),
	.store_user_input(store_user_input),
		// outputs
    .card_10(current_card),								// card/number to be displayed on hex,
    .game_over(game_over_internal), 					// is 1'b1 when user does not input answer or they answer wrong
  	.next_card_output(next_card_data_output), 			// going to control path enabling the change of states btwn CARD_ONE and CARD_TWO
	.done_analysing(done_analysing)
	);
 
endmodule

// control path

module control(
    // inputs
  	input start, 						// from switch/ key
  	input resetn,						// from switch/key
	input clk,
	input done_analysing,				// from datapth -- logic has determined if player is right or wrong
  	input next_card, 					// from data path-- next card should be displayed as 3 sec have passed
  	input game_over,					// from data path -- player was wrong if 1
  	output reg output_correct_answer,  	// going to data path
  	output reg next_card_output,		// going to data path
  	output reg analyse,					// begin analysing in datapath
	output reg store_user_input,		// player can click button now
	output reg show_game_over_screen	// to vgafsm
  	// outputs
    );
  reg [3:0] current_state, next_state; 
    
    localparam  
    // define states 
    	START_GAME = 4'd0,		
  		CARD_ONE   = 4'd1,
		WAIT_1	  = 4'd2,
  		CARD_TWO   = 4'd3,
		WAIT_2	  = 4'd4,
  		ANALYZE    = 4'd5,
  		GAME_OVER_CHECK	  = 4'd6,
		RIGHT      = 4'd7,
  		WRONG      = 4'd8,
      FINISH 	  = 4'd9;
    
    // Next state logic aka our state table
    always@(*)
    begin: state_table 
		case (current_state)
			// define state transitions
			START_GAME: next_state= start ? WAIT_1 : START_GAME;
			WAIT_1: next_state=next_card ? CARD_TWO : WAIT_1; 
			CARD_TWO: next_state =  WAIT_2;// while next_card is 0 stay on card two
			WAIT_2: next_state = next_card ? ANALYZE: WAIT_2;
			ANALYZE: next_state = done_analysing ? GAME_OVER_CHECK: ANALYZE;
			GAME_OVER_CHECK:next_state=game_over ? FINISH: RIGHT;
			RIGHT: next_state = WAIT_1;
			FINISH: next_state= START_GAME; 
			default:	next_state=START_GAME;
		endcase
    end
   

    always @(*)
    begin: enable_signals
        // By default make all our signals 0
       
			output_correct_answer=1'b0;
			next_card_output=1'b0;
			analyse=1'b0;
			output_correct_answer=1'b0;
			store_user_input=1'b0;
			show_game_over_screen = 1'b0;
						
			
        case (current_state)
    			// what ahppens in all the states
          START_GAME:
				show_game_over_screen = 1'b0;
           
			 WAIT_1: begin
			 // show card for 3 seconds
				next_card_output=1'b0;
			end
          CARD_TWO:begin
				 store_user_input=1'b1; // continously take in values from keys 
				 next_card_output=1'b1;// output next card
				 output_correct_answer=1'b1;// output right answer
          end
			 
			 WAIT_2:begin
				store_user_input=1'b0;// player can no longer click keys
				next_card_output=1'b0;// do not output another card
				output_correct_answer=1'b0;// do not output another correct answer
			 end
			 
          ANALYZE:begin
			 // determine if the player made the right decision 
				analyse=1'b1;
          end
		  GAME_OVER_CHECK:begin
				analyse=1'b0;
		  end
          RIGHT:begin
          // in the future will keep track of number of right answers in a row with a counter
				analyse=1'b0;
				
          end
          FINISH:begin
				show_game_over_screen = 1'b1;
            // will disaply end of game screen before game restarts
          end
        endcase
    end 

    always@(posedge clk)
    begin: state_FFs
        if(!resetn)
            current_state <= START_GAME;
        else
            current_state <= next_state;
    end 
endmodule

module datapath(
  //inputs
  input[3:0]card_original_0, // orginal card sequence
         	card_original_1,
  			card_original_2,
  		   	card_original_3,
  			card_original_4,
  			card_original_5,
  			card_original_6,
  			card_original_7,
  			card_original_8,
  			card_original_9,
         	card_original_10,
  input next_card, // from control path -- is 1'b1 when correct amount of time has gone by
  input [27:0]speed, // from top level module, determining how fast the cards will change
  input store_user_input,
  input wrong, right, // from top level module from keys  pressed by player
  input [10:0]correctness_val,
  input output_correct_answer, // signal from control path -- same as next_card, excpet not enabled when the very first card is shown
  input analyse,// signal from control path which enables the process of determining if a player's choice is right or wrong
  input clk,
  input resetn,
  // outputs
  output reg [3:0]card_10,// card/number to be displayed on hex,
  output reg game_over, // is 1'b1 when user does not input answer or they answer wrong
  output reg next_card_output, // going to control path enabling the change of states btwn CARD_ONE and CARD_TWO
 output reg done_analysing
);
	reg [27:0] count,// 3 second next card counter
	reg [9:0]right_wrong_sequence;// right wrong answer key that is cycling
	reg right_wrong_current;// current right answer for comparison to player's move
	reg wrong_analyse,right_analyse;// inputs from wrong and right (keys from board)
	reg[3:0] card_0,card_1,card_2,card_3,card_4,card_5,card_6,card_7,card_8,card_9;// cards that are cycling

	
			
// counter for controlling time - enables next_card in control
  always@(posedge clk,negedge resetn)
   if (!resetn) begin
			count<=speed;
			next_card_output<=1'b0;
		end
			
    else if (count==28'b0)begin
			count<=speed;// reset count
			next_card_output=1'b1;// go to the next card
	end
	else begin
		count <= count-1; // decrement count
      next_card_output=1'b0; // do not go to the next card yet
  end

// shift registor to store values to be display on vga 
  always@(posedge clk)
		 if(!resetn)begin
			// set all cards to there orginal values
			card_0<=card_original_0;
			card_1<=card_original_1;
			card_2<=card_original_2;
			card_3<=card_original_3;
			card_4<=card_original_4;
			card_5<=card_original_5;
			card_6<=card_original_6;
			card_7<=card_original_7;
			card_8<=card_original_8;
			card_9<=card_original_9;
			card_10<=card_original_10;
			
		end
		 else if (next_card)begin
		  // shift all values by one-- all of these are inputs from the top level module
		  card_0<=card_10;
		  card_1<=card_0;
		  card_2<=card_1;
		  card_3<=card_2;
		  card_4<=card_3;
		  card_5<=card_4;
		  card_6<=card_5;
		  card_7<=card_6;
		  card_8<=card_7;
		  card_9<=card_8;
		  card_10<=card_9;
		  
		 
	end
// shift register to store values of wrong and right answers -- our sequence of 1s and 0s
  always@(posedge clk)
    if(!resetn) begin //set sequence to initial correctness val input
      right_wrong_sequence[0]<=correctness_val[0];
      right_wrong_sequence[1]<=correctness_val[1];
      right_wrong_sequence[2]<=correctness_val[2];
      right_wrong_sequence[3]<=correctness_val[3];
      right_wrong_sequence[4]<=correctness_val[4];
      right_wrong_sequence[5]<=correctness_val[5];
      right_wrong_sequence[6]<=correctness_val[6];
      right_wrong_sequence[7]<=correctness_val[7];
      right_wrong_sequence[8]<=correctness_val[8];
      right_wrong_sequence[9]<=correctness_val[9];
      right_wrong_current<=correctness_val[10];     
      
    end
    else if (output_correct_answer) begin //otherwise, shift correctness compared to the zero bit
      right_wrong_sequence[0] <= right_wrong_current;
		right_wrong_sequence[1] <= right_wrong_sequence[0];
      right_wrong_sequence[2] <= right_wrong_sequence[1];
      right_wrong_sequence[3] <= right_wrong_sequence[2];
      right_wrong_sequence[4] <= right_wrong_sequence[3];
      right_wrong_sequence[5] <= right_wrong_sequence[4];
      right_wrong_sequence[6] <= right_wrong_sequence[5];
      right_wrong_sequence[7] <= right_wrong_sequence[6];
      right_wrong_sequence[8] <= right_wrong_sequence[7];
      right_wrong_sequence[9] <= right_wrong_sequence[8];
      right_wrong_current<= right_wrong_sequence[9];
     
    end

// stores user input from right wrong keys when store_user_input is 1
always@(posedge clk)
        if(!resetn | store_user_input)begin // reset values every turn 
            right_analyse<= 1'b0;
			wrong_analyse<=1'b0;
		end
			 
		else if (right)begin// store player's respone as "right"
		  right_analyse<=1'b1;
		  wrong_analyse<=1'b0;
		end

		else if(wrong)begin // store player's response as "wrong"
		  wrong_analyse<=1'b1;
		  right_analyse<=1'b0;
		end
		
// always block to determine if user's answer matches correct answer		 
  always@(posedge clk)
    if(!resetn) begin
      game_over = 1'b0;
		done_analysing=1'b0;
    end
    else if (analyse)begin
		if (wrong_analyse==1'b1 && right_analyse==1'b0)begin
			if (right_wrong_current==1'b0)begin// player says wrong and it should be wrong
          game_over=1'b0;
			 done_analysing=1'b1;
		end
       else if (right_wrong_current==1'b1)begin// player says wrong and it should be right
          game_over=1'b1;
			 done_analysing=1'b1;
       end
		end
		else if (wrong_analyse==1'b0 && right_analyse == 1'b1)begin
        if (right_wrong_current==1'b0)begin// player says right and it should be wrong
          game_over=1'b1;
			 done_analysing=1'b1;
       end
        else if (right_wrong_current==1'b1)begin// player says right and it should be right
          game_over=1'b0; 
			 done_analysing=1'b1;
        end
		end
      else begin
		game_over= 1'b1;
		done_analysing=1'b1;
		end
	end
	else begin
	game_over=1'b0;
	done_analysing=1'b0;
	end

endmodule
   
module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule

