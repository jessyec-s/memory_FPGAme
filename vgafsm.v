`timescale 1ns / 1ns
module vgafsm(
					input start,
					input clock,resetn,
					input [3:0]card_displayed,
					input show_game_over_screen,
					output vga_enable,
					output [8:0]colour,
					output [7:0]x_plot,
					output [6:0]y_plot
			

					);
	// signals
	wire enable_game_over_count,game_over_done,background_done, card_done,display_card,load_done,start_movement, plot_screen, plot_card,reset_count;
	wire [3:0] choosecolour;
	

	controlvga vgawow(
	//input
		.start(start), 				// from switch/ key from main
		.background_done(background_done),	//from datapath once entire screen drawn
		.card_done(card_done),
		.game_over(game_over),			//signal determined from mem game top, base on user input
		.card_displayed(card_displayed), //this is card[10] or whatever
		.load_done(load_done), 		//card done being loaded
		.show_game_over_screen(show_game_over_screen),		//user made mistake, from top, gameover signal to call screen
		.game_over_done(game_over_done),		//count to have game over screen, and then switch to start
		//output
		.choosecolour(choosecolour), //output to datapath colour case select
		.enable_game_over_count(enable_game_over_count),	//signal to start count down of game over screen
		.display_card(display_card),
		.clock(clock),
		.resetn(resetn),
		.start_movement(start_movement),	//start sliding card across screen
		.plot_screen(plot_screen),		//signal to start draw background
		.plot_card(plot_card),			//signal to start drawing card
		.reset_count(reset_count),
		.vga_enable(vga_enable)			//make obj display on vga
	);
	
	
	datapathvga vgaaww(
	//input
		//for colour choose case select
		.enable_game_over_count(enable_game_over_count),
		.display_card(display_card),
		.select(choosecolour),
		.clock(clock),
		.resetn(resetn),
		.start_movement(start_movement),
		.plot_screen(plot_screen),
		.plot_card(plot_card),
		.reset_count(reset_count),
		.show_game_over_screen(show_game_over_screen),
		//
	//output
		.game_over_done(game_over_done),
		.colour(colour[8:0]), //colour selected
		.x_plot(x_plot),
		.y_plot(y_plot),
		.background_done(background_done),
		.card_done(card_done),
		.load_done(load_done)
	);
endmodule


module controlvga(
    // inputs
	input game_over_done,
  	input start, 				// from switch/ key
	input background_done,
	input clock,
	input load_done,
	input resetn,
	input card_done,
	input show_game_over_screen,
	input game_over,
	input [3:0]card_displayed,
  	
	output reg enable_game_over_count,
	output reg [3:0]choosecolour,
	output reg display_card,
	output reg start_movement,
	output reg plot_screen,
	output reg plot_card,
	output reg reset_count,
	output reg vga_enable
  	// outputs
    );
  reg [3:0] current_state, next_state; 
    
    localparam  
    // define states 
    		START_SCREEN 	= 3'd0,	
		WAIT_BACKGROUND = 3'd1,
  		BACKGROUND   	= 3'd2,
		CARD_LOAD	= 3'd3,
		CARD_MOVE	= 3'd4,
		WAIT_CARD	= 3'd5,
  		GAME_OVER	= 3'd6;
		
    
    // Next state logic aka our state table
    always@(*)
    begin: state_table 
		case (current_state)
			// define state transitions
				
			//when user clicks start key, signal goes from top to vga control, moves to wait, else stays on start screen
			START_SCREEN: next_state= start ? WAIT_BACKGROUND : START_SCREEN;
				
			//if not gamo-over, draw game background
			WAIT_BACKGROUND: 
				if(show_game_over_screen)
					next_state=GAME_OVER;
				else 
				next_state=BACKGROUND;
				
			//if done drawing bckgrnd, draw card, else draw the bkgrnd
			BACKGROUND: begin
			
				if(show_game_over_screen)
					next_state=GAME_OVER;
				else if (background_done)
					next_state= CARD_LOAD;
				else next_state=BACKGROUND;
			end
				
			//draw card, once done, move card based on counter
			CARD_LOAD: begin
				if(show_game_over_screen)
					next_state=GAME_OVER;
				else if ( load_done)
					next_state = CARD_MOVE;
				else 
					next_state=CARD_LOAD;
			end

			//once card redrawn for moving one px, redraw background (and repeat redraw card and move again)
			CARD_MOVE:begin
				if(show_game_over_screen)
					next_state=GAME_OVER;
				else if(card_done)
					next_state=WAIT_BACKGROUND;
				else next_state=CARD_MOVE;
			end
			
			//state where user input evaluated, if wrong, game over, else redraw playing background and card cycle
			WAIT_CARD: next_state =  show_game_over_screen ? GAME_OVER : BACKGROUND;

			//if game over, wait for gamepver timer to go down, if done go to start, else keep counting down
			GAME_OVER: next_state = game_over_done ? START_SCREEN : GAME_OVER;

			//by default, go to start screen
			default:	next_state=START_SCREEN;
		endcase
    end
   

    always @(*)
    begin: enable_signals
        // By default make all our signals 0
			enable_game_over_count=1'b0;
			display_card=1'b0;
			start_movement=1'b0;
			plot_screen = 1'b0;		//draw screen
			plot_card = 1'b0;		//draw card
			reset_count=1'b0;
			vga_enable=1'b0;		//draw something
		
			
        case (current_state)
    			// what ahppens in all the states
          START_SCREEN:begin
          // will dispay start screen when visuals are added
					enable_game_over_count=1'b0;
					choosecolour = 4'b0;
					plot_screen = 1'b1;
					vga_enable=1'b1;

			 end
			 
			 WAIT_BACKGROUND: begin
				reset_count=1'b1;
				vga_enable=1'b0;
			 end
			 
			 BACKGROUND: begin
				reset_count=1'b0;
				plot_screen = 1'b1;
				choosecolour = 4'b1000;
				vga_enable=1'b1;
				
			end

          CARD_LOAD:begin
			 
				 display_card=1'b1;
				 plot_screen = 1'b0;
				 plot_card = 1'b1;
				 choosecolour= {1'b0,card_displayed}; 
				 vga_enable=1'b1;
				 
          end
			 CARD_MOVE: begin
				 display_card=1'b0;
				 start_movement=1'b1;
				 plot_card = 1'b0;
				 vga_enable=1'b0;
			 
			 end
			 
			 WAIT_CARD:begin
			  start_movement=1'b0;
			  plot_screen = 1'b0;
			  plot_card = 1'b0;
			  reset_count=1'b1;
			  vga_enable=1'b0;
			  
          end
			 
			 GAME_OVER:begin
				enable_game_over_count=1'b1;
				vga_enable=1'b1;
				reset_count=1'b0;
				choosecolour=4'b1001;
				plot_screen = 1'b1;
				plot_card = 1'b0;

			 end
			 
			 
        endcase
    end // enable_signals
   
    // current_state registers
    always@(posedge clock)
    begin: state_FFs
			if(!resetn)
            current_state <= START_SCREEN;
        else
            current_state <= next_state;
    end 
	 
endmodule

module datapathvga (
		input display_card,
		input clock,
		input enable_game_over_count,
		input [3:0]select,
		input resetn,
		input reset_count,
		input start_movement,
		input plot_screen,
		input plot_card,
		input show_game_over_screen,
		output reg game_over_done,
		output reg [7:0] x_plot,
		output reg [6:0]y_plot, 
		output reg background_done,
		output reg card_done,
		output reg [8:0]colour,
		output reg load_done

) ;
		reg [27:0]g_o_timer;
		reg [7:0] x;
		reg [6:0] y;
		wire [7:0] x_screen;
		wire [6:0] y_screen;
		wire [7:0] x_card;
		wire [6:0] y_card;
		
		reg [7:0] count1x = 7'b0; 
		reg [6:0] count1y = 6'b0;

		reg [7:0] count2x = 8'b0; 
		reg [6:0] count2y = 7'b0; 	
		
		wire [14:0]address_screen;
		wire [9:0]address_card;
		assign x_screen = count1x;
		assign y_screen = count1y;
		
		assign address_screen= count1y*15'd160+count1x;
		assign address_card= count2y*5'd20+count2x;
		
		assign x_card = x + count2x;
		assign y_card = y + count2y;
		
		//moving card
		wire [19:0] movement_max;
		assign movement_max = 'd10000500;
		
		wire [8:0]startscreencolour,card1colour, card2colour, card3colour, card4colour, card5colour, card6colour, card7colour, backgroundcolour, gameovercolour;

		reg [19:0] movement_count;
		
		//instantiations for game screen modules
		start_screen displayA(
			.address(address_screen),
			.clock(clock),
			.data(2'b0),
			.wren(1'b0),
			.q(startscreencolour));
			
		game_over displayB(
				.address(address_screen),
				.clock(clock),
				.data(0),
				.wren(0),
				.q(gameovercolour));
				
		card_1 displayC(
				.address(address_card),
				.clock(clock),
				.data(0),
				.wren(0),
				.q(card1colour));
				
		card_2 displayD(
				.address(address_card),
				.clock(clock),
				.data(0),
				.wren(0),
				.q(card2colour));
				
				
		card_3 displayE(
				.address(address_card),
				.clock(clock),
				.data(0),
				.wren(0),
				.q(card3colour));
				
				
		card_4 displayF(
				.address(address_card),
				.clock(clock),
				.data(0),
				.wren(0),
				.q(card4colour));
				
		card_5 displayG(
				.address(address_card),
				.clock(clock),
				.data(0),
				.wren(0),
				.q(card5colour));
				
		card_6 displayH(
				.address(address_card),
				.clock(clock),
				.data(0),
				.wren(0),
				.q(card6colour));
				
		card_7 displayI(
				.address(address_card),
				.clock(clock),
				.data(0),
				.wren(0),
				.q(card7colour));
				
		game_background displayJ(
				.address(address_screen),
				.clock(clock),
				.data(0),
				.wren(0),
				.q(backgroundcolour));
			 
		//select of what image to display
		always @(*)
			
			case (select)
				4'b0000: colour = startscreencolour;
				4'b0001: colour = card1colour;
				4'b0010: colour = card2colour;
				4'b0011: colour = card3colour;
				4'b0100: colour = card4colour;
				4'b0101: colour = card5colour;
				4'b0110: colour = card6colour;
				4'b0111: colour = card7colour;
				4'b1000: colour = backgroundcolour;
				4'b1001: colour = gameovercolour;
				default : colour = startscreencolour;
			endcase

		//timer for gameover screen, count down when gameover signal received, and send done signal to control for start screen
		always@ (posedge clock)
			begin
				if(enable_game_over_count)begin
					if(g_o_timer==0)begin
						g_o_timer<='d249999999;
						game_over_done<=1'b1;
					end
					else begin
						g_o_timer<=g_o_timer-1;
						game_over_done<=1'b0;
					end
				end
				else begin
					g_o_timer<='d249999999;
					game_over_done<=1'b0;
				end
			end
			
		// plot entire screen
		
			always@ (posedge clock)
				begin
				if(!resetn|reset_count) begin
					count1x<=0; 
					count1y <=0;
				 end
				
				if(plot_screen) begin
				
					if(count1x == 'd159)begin
					
					count1x <= 0;
					count1y <= count1y + 1;
					background_done <= 1'b0;
					end
					else if(count1y == 'd119)begin
						count1y<= 0;
						count1x<=0;
						background_done <= 1'b1;
					end
									
				else begin
					count1x <=  count1x + 1;
					background_done <= 1'b0;
					end
				end
				end
		
		
		
		// plot card
		always@ (posedge clock)
				begin
					if (!resetn) begin
					count2x<=0; 
					count2y <=0;
					load_done=1'b0;
				 end
				
				if(plot_card) begin
				 
					if(count2y == 'd39 && count2x == 'd19)begin
						count2y <= 0;
						count2x<=0;
						load_done=1'b1;
					end	
					else if (count2x == 'd19)begin
						count2x <= 0;
						count2y <= count2y + 1;
						load_done=1'b0;
					end					
					else begin
						count2x <=  count2x + 1;
						load_done=1'b0;
					end
				end
			end
		
		// choose wich coordinate to display -- card or entire screen	
		always@ (*)
		
			if (display_card)begin
				x_plot<=x_card;
				y_plot<=y_card;
			end
			else begin
				x_plot<=x_screen;
				y_plot<=y_screen;
			end
			
		// counter for moving card smoothly	
		always@ (posedge clock)
		begin
				if(!resetn) begin
					x <= 0;
					y <= 'd40;
					movement_count<=movement_max;
					card_done<=1'b0;
				end	
			if (start_movement)begin
				 if(x=='d159)begin
					x<=0;
					y<='d40;
					card_done<=1'b0;
				 end
				 if (movement_count=='d0)begin
						movement_count<=movement_max;// reset count
						card_done<=1'b1;// go to the next card
						x<=x+1;
					end
				else begin
					movement_count <= movement_count-1; // decrement count
					card_done<=1'b0; // do not go to the next card yet
			  end
			end
		end
	endmodule

