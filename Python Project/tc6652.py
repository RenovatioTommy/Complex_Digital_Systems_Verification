#!/usr/bin/python
#
import sys #from sys options
import getopt
import re #for regular expressions

"""
EEEE-722 Complex Digital Systems Verification
Spring 2022
Professor: Mark. A. Indovina
Author: Tommy Choephel
"""

def main():

	param = None
	help = False
	width = None
	stages = None
	reset = None
	outfile = None
	outfileTB = None
	msb = 0
	mss = 0

	argv = sys.argv[1:]

	try :
		options, args = getopt.getopt(argv, "p:hw:s:r:o:", ["param=", "help", "width=", "stages=", "reset=", "outfile="])

		for opt, arg in options: 
				if opt in ['-p', '--param']:
					param = arg
				elif opt in ['-h', '--help']:
					help = True
				elif opt in ['-w', '--width']:
					width = arg
				elif opt in ['-s', '--stages']:
					stages = arg
				elif opt in ['-r', '--reset']:
					reset = arg
				elif opt in ['-o', '--outfile']:
					outfile = arg
	except:
		print("ERROR: Type --help for help with usage.")

	if help == True:
		print(
			'''\
	--param (input text filename with extension containing all design parameters; mutually exclusive with all other commands)

	--width (input the width of the register(s); must be 1 to 64 decimal value)

	--stages (input the number of pipeline stages; must be 2 to 128 decimal value)

	--reset (input the register reset value in decimal or hexadecimal; value must not exceed register width capacity)

	--outfile (input the output module file name with extension)

	--help  input this command for help on command line options
			'''
			)
		sys.exit()

	if(param and (width or stages or reset or outfile)):
	    sys.exit("ERROR: You must use either --param OR all individual design options, but not both simultaneously.")

	if param:
		try:
	 		with open(param) as f: 
	 			line = f.read()
	 			while line:
	 				line = f.read()
	 				match1 = re.search("^\s*width\s*=\s*(\d+)\s*;\s*$", line)
					width = match1.group(1) if match1 else None
					if match1:
						print("From the param file, the following parameters are obtained:")
						print("width =", width) 
						#f {} is f-string and allows $variable-like function from Perl for Python 3.6+; ours is too old

					match2 = re.search("^\s*stages\s*=\s*(\d+)\s*;\s*$", line)
					stages = match2.group(1) if match2 else None
					if match2:
						print("stages =", stages)

					match3 = re.search("^\s*reset\s*=\s*(\d+)\s*;\s*$", line)
					reset = match3.group(1) if match3 else None
					if match3:
						print("reset =", reset)

					match4 = re.search("^\s*reset\s*=\s*0x(\w+)\s*;\s*$", line)
					hexa = match4.group(1) if match4 else None #Convert hexa to decimal
					reset = int(hexa, 16) #convert hex to int
					if match4:
						print("reset =", reset)

					match5= re.search("^\s*outfile\s*=\s*(\w+.\w)\s*;\s*$", line) 	#(\w+.\w) because of the period in the .v in extension
					outfile = match5.group(1) if match5 else None				#now outfile contains the .v extension 
					if match5:
						print("outfile =", outfile)

		except:
			print("Error: Unable to open " + param)
			sys.exit()

	#-----------------Check that all design parameters are fed---------------------------------------------------

	width = int(width)
	stages = int(stages)
	reset = int(reset)

	if not(width and reset and stages and outfile): #Check that all parameters are defined
		sys.exit("ERROR:  You must define all the design parameters: width, stages, reset, and outfile. For help, type --help")


	msb = width -1 #adjusting for 0 index
	mss = stages -1 #adjusting for 0 stage

	if not((width > 0) and (width < 65)):
		sys.exit("ERROR: Width is not between 1 and 64.")

	if type(reset) is int: #if reset value is console input as int
		if not((reset <= (2**width)) and (reset >= 0)): 	# ** is exponent operator
			sys.exit("""\ 
				ERROR: Yout reset value exceeds width capacity.
				Your reset value = %(reset)d and your width capacity = %(width)d bits.
				""" %locals()) #these %(reset)d = insert value of 'reset' which is (d)ecimal, %locals()) needs to be there just cause
	elif type(reset) is str: #if reset value is console input as hex
		reset = int(hexa, 16) #convert hex to int
		if not((reset <= (2**width)) and (reset >= 0)):

			sys.exit("""\
				ERROR: Yout reset value exceeds width capacity.
				Your reset value = %(reset)d and your width capacity = %(width)d bits.
				""" %locals()) #these %(reset)d = insert value of 'reset' which is (d)ecimal, %locals() needs to be there for f string
	else:
		sys.exit("ERROR: Your reset value must be in decimal, or hexadecimal with '0x' prefix.")

	if not((stages > 1) and (stages < 129)):
		sys.exit("ERROR: Number of stages is not between 2 and 128.")


	#Skipped checking for illegal characters in outfile

	outfile = outfile[:-2] #slices the .v extension from outfile

	#------------------------Create Verilog File---------------------------------------------
	try:
	 	with open(outfile) as f:
	 		f.write("""\
	module %(outfile)s (clk, reset, scan_en, test_mode, scan_in0, shift_in, scan_out0, shift_out);

	input clk, reset, scan_en, test_mode, scan_in0;
	input wire [%(msb)d:0] shift_in;
	 		""")

			for i in range(0, stages):
				f.write("reg [%(msb)d:0] s%(i)i;" % locals()) #Insert var values like $variable in Perl

			f.write("""\ 
	output scan_out0;
	output wire [%(msb)d:0] shift_out;

	assign shift_out = s%(mss)d; //continuous assignment with assign, can't be in always block because of shift_out is wire type

	always @(posedge clk or posedge reset) 
	begin

	if (reset) begin 
	 //reset to the reset value (bitwidth'decimal_value)
	 //ron-blocking ( <= ) yields sequential, whereas blocking yields combinational logic
				""" % locals())

			for i in range(0, stages):
				f.write("	s%(i)d <= %(width)d'd%(reset)d;" % locals())

			f.write("""
		end

	else begin
				""")

			for j in range(mss, 0, -1):
				f.write("	s" + (j) + "<= s" + (j-1) + ";") #Py has cluncky string printing with var operations embedded w/o f-string update

			f.write("""\
		s0 <= shift_in;
	    end

	end
	endmodule
				""")
			f.close()

		print("Verilog file successfully written.")

	except:
		print("Error: Unable to create", outfile)
		sys.exit()

	#-------------------------------CREATE TESTBENCH-------------------------------------------------------

	outfileTB = outfile + "_test.v" #sring concatenation

	try:
	 	with open(outfileTB) as f:
	 		f.write("""\
	module test;

	wire  scan_out0;
	reg  clk, reset;
	reg  scan_in0, scan_en, test_mode;
	reg [%(msb)d:0] shift_in;      //Inputs to DUT
	wire [%(msb)d:0] shift_out;    //Outputs from DUT are wire type
	reg [%(msb)d:0] internalreg [((%(stages)d*100)+%(stages)d:0]; //keep track of random values (first width, then stages *100)
	integer hundredstages;
	integer shcnt, ircnt, h, i;
	reg flag;


	//instantiate $outfile as DUT called 'top'
	%(outfile)s top(
	        .reset(reset),  //. for port name correspondence
	        .clk(clk),
	        .scan_in0(scan_in0),
	        .scan_en(scan_en),
	        .test_mode(test_mode),
	        .scan_out0(scan_out0),
	        .shift_in(shift_in),
	        .shift_out(shift_out)
	    );

	    // 50 MHz clock
	always
	    #10 clk = ~clk;

	initial
	begin
	    \$timeformat(-9,2,"ns", 16); // nanoscale, precision, ns suffix, 16 field width
	`ifdef SDFSCAN
	    \$sdf_annotate(\"sdf/$outfile\_tsmc18_scan.sdf\",test.top);
	`endif
	    clk = 1'b0;
	    reset = 1'b0;
	    scan_in0 = 1'b0;
	    scan_en = 1'b0;
	    test_mode = 1'b0;
	    shift_in = 0;
	    shcnt = 0;  //shift counter
	    ircnt = 0; //internal place counter
	    hundredstages = %(stages)d*100;
	    flag = 0;


	    //Check reset sequence
	    reset = 1'b1;
	    
	    \@(negedge clk)
	    begin
	    for (h = 0; h < $stages; h = h+1)
	        begin
	            \@(negedge clk);
	            begin
	            if (shift_out != %(reset)d)
	            \$display("[ERROR]: Reset sequence value is not properly set for stage [\%d]; time: \%d ns.", (%(stages)d-1-h), \$time);
	            else 
	            \$display("[PASSED]: Reset sequence sequence passed for stage [\%d]; time: \%d ns.", (%(stages)d-1-h), \$time);
	            end
	            reset = 1'b0;
	        end
	        flag = 1'b1; // Active sequence starts now

	    //check the active sequence
	    
	            for (i = 0; i < (hundredstages+%(stages)d); i = i+1) //added extra stage count to accomodate full shift out checking
	                begin
	                \@(negedge clk);
	                shift_in <=  {\$random,\$random};
	                internalreg[i] <= shift_in;
	                shcnt <= shcnt+1;
	                if (shcnt >= (%(stages)d-1)) //shifting in more than the # of stages in this system, so must check shift out
	                    begin
	                    if(shift_out != internalreg[ircnt]) 
	                    \$display ("[ERROR]: Active sequence shift_out[\%d] doesn't match internalreg[\%d]; time: \%d ns.", ircnt, ircnt, \$time);
	                    else 
	                    \$display("[PASSED]: Active sequence shift_out[\%d] matches internalreg[\%d]; time: \%d ns.", ircnt, ircnt, \$time);
	                    ircnt <= ircnt+1;   
	                    end
	                end
	    end

	    repeat (1000)
	    @(posedge clk) ;
	    \$finish;
	end
	endmodule 

	 		""" % locals())
	 		f.close()

		print("Verilog testbench file successfully written.")

	except:
		print("Error: Unable to create", outfileTB)
		sys.exit()

main()


