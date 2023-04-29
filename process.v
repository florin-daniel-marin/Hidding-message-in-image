
`timescale 1ns / 1ps

module process (
        input                clk,		    	// clock 
        input  [23:0]        in_pix,	        // valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
        input  [8*512-1:0]   hiding_string,     // sirul care trebuie codat
        output [6-1:0]       row, col, 	        // selecteaza un rand si o coloana din imagine
        output 		        out_we, 		    // activeaza scrierea pentru imaginea de iesire (write enable)
        output [23:0]        out_pix,	        // valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
        output   reg         gray_done,		    // semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
        output   reg         compress_done,		// semnaleaza terminarea actiunii de compresie (activ pe 1)
        output   reg         encode_done        // semnaleaza terminarea actiunii de codare (activ pe 1)
    );	
    
    //TODO - instantiate base2_to_base3 here
	parameter M = 4;
	`define START 0
   `define CONVERSION 1
	`define CONVERSION_MED 2
	`define CONVERSION_WRITE 3
   `define CONVERSION_WAIT 4
	`define READ_BLOCK 5
	`define COMPRESION_SUM 6
	`define READ_WAIT 7
   `define COMPRESION_AMBTC 8
	`define COMPRESION_LmHm 9
	`define A 10
	`define COMPRESION_RECONST2 11
	`define COMPRESION_LOOP 12
	`define BLOCK_LOOP 13
   `define ENCAPSULATION_READ 14
   `define ENCAPSULATION_BASE2BASE3 15
   `define ENCAPSULATION_EMBEDDING 16
   `define FINISH 17
	`define COMPRESION_AMBTC_AVG 18
	`define COMPRESION_RECONST_WAIT 19
	`define COMPRESION_var 20
	`define DONE_GRAY 21
	`define DONE_COMPR 22

	wire [31:0] base3_no;
	wire [15:0] base2_no;
	reg done;
	wire done1;
	wire en_b2_3;

    reg[31:0] base_3_no;
	reg[15:0] base_2_no;
	reg en;
	 
    reg [4:0] state = `START;
    reg [5:0] i;
	 reg [5:0] j;
	 reg [5:0] k;
	 reg [5:0] l;
	 reg [5:0] x;
	 reg [5:0] y;
	reg [7:0] s;
	 reg [4:0] b;
	 reg [23:0] out_pix_aux;
	 
	 reg we;
	 reg [7:0] max;
	 reg [7:0] min;
	 reg [7:0] med;
	 
	 reg [15:0] sum;
	 reg [15:0] dif;
	 reg [7:0] AVG;
	 reg [7:0] var;
	 reg [7:0] beta;
	 reg [7:0] Hm;
	 reg [7:0] Lm;
	 
	 reg [23:0] in_block [3:0][3:0];

    base2_to_base3 b2_to_b3(.base3_no(base3_no),
				.base2_no(base2_no), 
				.done(done1),
            	.en(en_b2_3),
				.clk(clk));
					
    //TODO - build your FSM here
	 assign out_pix = out_pix_aux;
	 assign out_we = we;
	 assign row = j;
	 assign col = i;

	 always @(*) begin
	 	base_3_no = base3_no;
	 	base_2_no = base2_no;
	 	en = en_b2_3;
	 end

    //initializam variabilele:
	initial begin
		gray_done = 0;
		compress_done = 0;
		encode_done = 0;
		we = 0;
		i = 0; //col matrice 64x64
		j = 0; // row matrice 64x64
		k = 0; // col block MxM
		l = 0; // row block MxM
		x = 0; // col block MxM din matricea 16Mx16M
		y = 0; //row block MxM din matricea 16Mx16M
		b = 0; // nr.bit din base_3_no
		s = 0; // nr. of 2*bytes din hiding_string
		sum = 0;
		dif = 0;
		beta = 0;
	end
	 
    always @(posedge clk) begin
		case (state)
			`START: begin
				done <= 0;
				state <= `CONVERSION;
			end
	
	
        `CONVERSION: begin
				// maximul dintre cele 3 culori
				if ((in_pix[23:16] >= in_pix[15:8])&&(in_pix[23:16] > in_pix[7:0]))
					max <= in_pix[23:16];
				else if ((in_pix[15:8] > in_pix[23:16])&&(in_pix[15:8] > in_pix[7:0]))
					max <= in_pix[15:8];
				else
					max <= in_pix[7:0];
					
				// minimul dintre cele 3 culori
				if ((in_pix[23:16] <= in_pix[15:8])&&(in_pix[23:16] < in_pix[7:0]))
					min <= in_pix[23:16];
				else if ((in_pix[15:8] < in_pix[23:16])&&(in_pix[15:8] < in_pix[7:0]))
					min <= in_pix[15:8];
				else
					min <= in_pix[7:0];
	
				//scrierea in pixel - grayscale (media min, max -> canalul G)		
				state <= `CONVERSION_MED;				
        end
		  
		  
		  `CONVERSION_MED: begin
				med <= (min + max)/2;
				state <= `CONVERSION_WRITE;
		  end
		  
		  `CONVERSION_WRITE: begin
				we <= 1;
				out_pix_aux <= {8'b0, med, 8'b0};	
				state <= `CONVERSION_WAIT;
		  end


        `CONVERSION_WAIT: begin 
		we <= 0;
		//incrementare (parcurgere pixel cu pixel)
		i <= i + 1;
		if ((i == 63)&&(j == 63)) begin
			i <= 0;
			j <= 0;
			gray_done <= 0;
			state <= `READ_BLOCK;
			gray_done <= 1;
		end 
		else if ((i == 63)&&(j != 63)) begin
			i <= 0;
			j <= j + 1;
			state <= `CONVERSION;
		end
		else state <= `CONVERSION;
			end

		`DONE_GRAY: begin
			gray_done <= 0;
			state <= `READ_BLOCK;
		end

        `READ_BLOCK: begin //citesc cate un block de 4X4 din imaginea grayscale
				//impartire in blocuri de cate 4					
				in_block[k][l] <= in_pix;
				state <= `COMPRESION_SUM;
			end
		  
		  `COMPRESION_SUM: begin
				sum <= sum + in_block[k][l][15:8];			
				//state <= `READ_WAIT;
				k <= k + 1;
				if ((k == 3)&&(l == 3)) begin
					k <= 0;
					l <= 0;
					state <= `COMPRESION_AMBTC_AVG;
				end
				else if ((k == 3)&&(l != 3)) begin
					k <= 0;
					l <= l + 1;
					state <= `READ_WAIT;
				end
				else begin
					k <= k + 1;
					state <= `READ_WAIT;
				end
			end
			
		  `READ_WAIT: begin
		  	i <= k+4*x;
			j <= l+4*y;
			state <= `READ_BLOCK;
		  end


        `COMPRESION_AMBTC_AVG: begin
				//implementare metoda AMBTC pentru blockul [y][x]
				AVG <= sum/(M*M);
				state <= `COMPRESION_AMBTC;
			end
				
		  `COMPRESION_AMBTC: begin
				if (in_block[k][l][15:8] >= AVG) begin
					dif <= dif + (in_block[k][l][15:8] - AVG);
					beta <= beta + 1;
				end else
					dif <= dif + (AVG - in_block[k][l][15:8]);

				if ((k == 3)&&(l == 3)) begin
					k <= 0;
					l <= 0;
					state <= `COMPRESION_var;
				end
				else if ((k == 3)&&(l != 3)) begin
					k <= 0;
					l <= l + 1;
					state <= `COMPRESION_AMBTC;
				end 
				else begin
					k <= k + 1;
					state <= `COMPRESION_AMBTC;
				end
			end
			
			
			`COMPRESION_var: begin		
				var <= dif/(M*M);	
				state <= `COMPRESION_LmHm;
			end
			
			
			`COMPRESION_LmHm: begin
				Lm <= AVG - (M*M*var)/(2*(M*M-beta));
				Hm <= AVG + (M*M*var)/(2*beta);	
				state <= `COMPRESION_RECONST2;
			end
			
			
			`COMPRESION_RECONST2: begin
				i <= k+4*x;
				j <= l+4*y;
				if (in_block[k][l][15:8] >= AVG)
					out_pix_aux <= {8'b0, Hm, 8'b0};
				else
					out_pix_aux <= {8'b0, Lm, 8'b0};
				we <= 1;	
				state <= `COMPRESION_LOOP;
			end
			
			
			`COMPRESION_RECONST_WAIT: begin
				//we <= 1;
				state <= `COMPRESION_LOOP;
			end
			
			
			`COMPRESION_LOOP: begin
				we <= 0;
				k <= k + 1;
				if ((k == 3)&&(l == 3)) begin
					k <= 0;
					l <= 0;
					state <= `BLOCK_LOOP;
				end
				else if ((k == 3)&&(l != 3)) begin
					k <= 0;
					l <= l + 1;
					state <= `COMPRESION_RECONST2;
				end
				else begin
					k <= k + 1;
					state <= `COMPRESION_RECONST2;
				end
		  	end
			
			
			`BLOCK_LOOP: begin
				sum <= 0;
				dif <= 0;
				beta <= 0;
				//incrementare (parcurgere block cu block)

				if ((x == 15)&&(y == 15)) begin
					i <= 0;
					j <= 0;
					k<= 0;
					l<=0;
					x <= 0;
					y <= 0;
					s <= 0;
					compress_done <= 1;
					state <= `ENCAPSULATION_BASE2BASE3;
				end
				else if ((x == 15)&&(y != 15)) begin
					x <= 0;
					y <= y + 1;
					state <= `READ_WAIT;
				end
				else begin
					x <= x + 1;
					state <= `READ_WAIT;
				end
			end

        //-----------third step: ENCAPSULATION------------

		//--read the hiding string 2 chars by 2 chars (16 bits)
        `ENCAPSULATION_READ: begin
        	s <= s + 1;
            state <= `ENCAPSULATION_BASE2BASE3;
        end

        //--change from base 2 to base 3 [16 bits] -> [32 bits]
        `ENCAPSULATION_BASE2BASE3: begin
        	base_2_no[15:0] <= hiding_string[s*16+:15];
        	en <= 1;

        	state <= `A;
        end

        `A: begin
        	en <= 0;
        	i <= k+4*x;
			j <= l+4*y;
			state <= `DONE_COMPR;
		end

        `DONE_COMPR: begin

			if (base_3_no[b] == 2) begin
				out_pix_aux <= in_pix - 1;
			end
			else if (base_3_no[b] == 1) begin
				out_pix_aux <= in_pix + 1;
			end

			we <= 1;
			state <= `ENCAPSULATION_EMBEDDING;
		end

        //read matrix of img block of sizeM by block of sizeM
        `ENCAPSULATION_EMBEDDING: begin
        	we <= 0;

        	//----------Citire pixeli din bloc------------ 
            if ((k == 3)&&(l == 3)) begin
				k <= 0;
				l <= 0;
				b <= 0;

				//--------Citire blocuri din matrice-------
					if ((x == 15)&&(y == 15)) begin
						i <= 0;
						j <= 0;
						encode_done <= 1;
						state <= `FINISH;
					end
					else if ((x == 15)&&(y != 15)) begin
						x <= 0;
						y <= y + 1;
					end
					else begin
						x <= x + 1;
					end	
				state <= `ENCAPSULATION_READ;
			end
			else if ((k == 3)&&(l != 3)) begin
				k <= 0;
				l <= l + 1;
				b <= b + 1;
				state <= `A;
			end 
			else if (((k == 0)||(k == 2))&&(l == 0)) begin
				k <= k + 1;
				b <= b + 1;
				state <= `ENCAPSULATION_EMBEDDING;
			end
			else begin
				k <= k + 1;
				b <= b + 1;
				state <= `A;
			end
        end

        //-----------case finish------------
        `FINISH: begin
			done <= 1;
			encode_done <= 1;
            //state = `START;
        end

    endcase
	end	 

	
endmodule
