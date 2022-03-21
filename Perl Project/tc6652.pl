#!/usr/bin/perl
#
# Strict and warnings are recommended.
#

=begin
EEEE-722 Complex Digital Systems Verification
Spring 2022
Professor: Mark. A. Indovina
Author: Tommy Choephel
=cut

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);   #used to check if input is decimal for reset
use Getopt::Long;



my $param = "";  #input file name must be a text file. any order is fine, read up on opening file in Perl

my $help;   #for help input, display the usage of the input option, how?

my $width;  #anything between 1-64 bits

my $stages; #2-128

my $reset; #decimal or hexademical (read perl docs for catching both) max is what decimal/hex a 64-bit binary can hold (2^64-1)

my $outfile; #just output users "input.v"

my $outfileTB; #verilog TB 

my $msb; #most significant bit

my $mss; #most significant stage

GetOptions ("param=s" => \$param,        #string for input file name, wont have the dashes before commands
            "width=i" => \$width,       #integer, make sure the int is in proper range
            "stages=i" => \$stages,   #integer
            "help"  => \$help,          #flag
            "reset=s" => \$reset,         #reset value in hex or decimal
            "outfile=s" => \$outfile)     #output file name with .v extension
or die("Error in command line arguments. For help, type --help\n");

 
#Prompt for --help
if( defined $help){
print <<EOF;

--param (input text filename with extension containing all design parameters; mutually exclusive with all other commands)

--width (input the width of the register(s); must be 1 to 64 decimal value)

--stages (input the number of pipeline stages; must be 2 to 128 decimal value)

--reset (input the register reset value in decimal or hexadecimal; value must not exceed register width capacity)

--outfile (input the output module file name with extension)

--help  input this command for help on command line options

EOF
exit 1; #exit the program with (1) to show that there has been an "error"
} 

#Check that only param or other options are invoked
if($param && ($width || $stages || $reset || $outfile)){
    die "ERROR: You must use either --param OR all individual design options, but not both simultaneously."
}

if(length($param) > 0) {   #If param file is given...
#Read from param file
open(FH, '<', $param) or die("ERROR: Unable to open $param file.");
#Regular Expression Operators:   (\s) = match any amount of space, (\d) = match digit, (a*) = match a 0 or more times, (a+) = match a 1 or more, (^$) = begin and end 
while (<FH>){
    if ($_ =~ /^\s*width\s*=\s*(\d+)\s*;\s*$/){ 
        $width = $1; #must enclose \d+ in () as shown for $width to take the digit value
        print "From the param file, the following parameters are obtained:\n";
        print "width = $width\n";
    }  
    elsif ($_ =~ /^\s*stages\s*=\s*(\d+)\s*;\s*$/){
        $stages = $1;
        print "stages = $stages\n";
    }
    elsif ($_ =~ /^\s*reset\s*=\s*(\d+)\s*;\s*$/){
        $reset = $1;
        print "reset = $reset\n";
    }
    elsif ($_ =~ /^\s*reset\s*=\s*0x(\w+)\s*;\s*$/){   #(\w+) = match one or more alphabets or decimal digits or _
        $reset = hex($1);                           #hex() function converts hex to decimal
        print "reset = $reset\n";
    } 
    elsif ($_ =~ /^\s*outfile\s*=\s*(\w+.\w)\s*;\s*$/){   #(\w+.\w) because of the period in the .v in extension
        $outfile = ($1);                                #now $outfile contains the .v extension                 
        print "outfile = $outfile\n"; 
    }            
}
}

#Check that all design parameters are fed
unless((defined $width) && (defined $reset) && (defined $stages) && (defined $outfile)){
    die "ERROR: You must define all the design parameters: width, stages, reset, and outfile. For help, type --help\n"
}

$msb = $width-1; #adjusting for 0 index
$mss = $stages-1; #adjusting for 0 stage

#Check width
unless(($width > 0) && ($width < 65)){
    die "ERROR: Width is not between 1 and 64.\n"
}

#Checking for reset and width match
if (looks_like_number($reset)) {
    unless(($reset <= (2**$width)) && ($reset >= 0)){
        die "ERROR: Yout reset value exceeds width capacity.\nYour reset value = $reset and your width capacity = $width bits or ", (2**$width), ".\n"
        }
} 
elsif ($reset =~ /^\s*0x\w+/){
    $reset = hex($reset);
    unless(($reset <= (2**$width)) && ($reset >= 0)){
        die "ERROR: Yout reset value exceeds width capacity.\nYour reset value = $reset and your width capacity = $width bits or ", (2**$width), ".\n"
        }
}
else {
        die "ERROR: Your reset value must be in decimal, or hexadecimal with '0x' prefix.\n"
}

#check stages limit
unless(($stages > 1) && ($stages < 129)){
    die "ERROR: Number of stages is not between 2 and 128.\n" 
}

unless ($outfile =~ /^\w+.\w+$/){                                          
        die "Your outfile $outfile must not contain illegal characters.\n"; 
    }            


#use open() fucntion to create the outfile,     > for writng, < for reading, >> for appending, (.v is accounted for)
open(Vfile, '>', $outfile) or die "ERROR: Unable to create $outfile.\n"; 

#process outfile name to remove extension
chop($outfile); #remove the "v"
chop($outfile); #remove the "."

#------------------------Create Verilog File---------------------------------------------
print Vfile<<"EOF";

module $outfile (clk, reset, scan_en, test_mode, scan_in0, shift_in, scan_out0, shift_out);

input clk, reset, scan_en, test_mode, scan_in0;
input wire [$msb:0] shift_in;
EOF

for (my $i = 0; $i < $stages; $i++){
    print Vfile "reg [$msb:0] s$i;\n";
}

print Vfile<<"EOF";
output scan_out0;
output wire [$msb:0] shift_out;

assign shift_out = s$mss; //continuous assignment with assign, can't be in always block because of shift_out is wire type

always @(posedge clk or posedge reset) 
begin

if (reset) begin 
 //reset to the reset value (bitwidth'decimal_value)
 //ron-blocking ( <= ) yields sequential whereas blocking yields combinational logic
EOF

for (my $i = 0; $i < $stages; $i++){
    print Vfile "    s$i <= $width", "'d", "$reset;\n";
}

print Vfile<<"EOF";
    end

else begin
EOF

for(my $j = $mss; $j > 0; $j--){
    print Vfile "    s$j <= s",$j-1, ";\n"
}

print Vfile<<"EOF";
    s0 <= shift_in;
    end

end
endmodule
EOF
close(Vfile);

print "Verilog file successfully written.\n";


#------------------------CREATE TESTBENCH-------------------------------------------------------

$outfileTB = $outfile."_test.v";

#use open() fucntion to create the outfile,     > for writng, < for reading, >> for appending, (.v is accounted for)
open(VTBfile, '>', $outfileTB) or die "ERROR: Unable to create $outfileTB.\n"; 

print VTBfile<<"EOF";

module test;

wire  scan_out0;
reg  clk, reset;
reg  scan_in0, scan_en, test_mode;
reg [$msb:0] shift_in;      //Inputs to DUT
wire [$msb:0] shift_out;    //Outputs from DUT are wire type
reg [$msb:0] internalreg [(($stages*100)+$stages):0]; //keep track of random values (first width, then stages *100)
integer hundredstages;
integer shcnt, ircnt, h, i;
reg flag;

//instantiate $outfile as DUT called 'top'
$outfile top(
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
    hundredstages = $stages*100;
    flag = 0;


    //Check reset sequence
    reset = 1'b1;
    
    \@(negedge clk)
    begin
    for (h = 0; h < $stages; h = h+1)
        begin
            \@(negedge clk);
            begin
            if (shift_out != $reset)
            \$display("[ERROR]: Reset sequence value is not properly set for stage [\%d]; time: \%d ns.", ($stages-1-h), \$time);
            else 
            \$display("[PASSED]: Reset sequence sequence passed for stage [\%d]; time: \%d ns.", ($stages-1-h), \$time);
            end
            reset = 1'b0;
        end
        flag = 1'b1; // Active sequence starts now

    //check the active sequence
    
            for (i = 0; i < (hundredstages+$stages); i = i+1) //added extra stage count to accomodate full shift out checking
                begin
                \@(negedge clk);
                shift_in <=  {\$random,\$random};
                internalreg[i] <= shift_in;
                shcnt <= shcnt+1;
                if (shcnt >= ($stages-1)) //shifting in more than the # of stages in this system, so must check shift out
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
EOF

close(VTBfile);

print "Verilog testbench file successfully written.\n";

#------------------------Perl POD Manual--------------------------------------------------------

=head1 USER MANUAL

=head2 SYNOPSIS 

    This scrips generates Verilog RTL code for parallel shift registers based on given design parameters.
    Here are the commands and their usage explanation. 

--param (input text filename with extension containing all design parameters; mutually exclusive with all other commands)
    
    A sample text file's content may look like this:

    width = 16;
    stages = 8;
    reset = 0xFFF;
    outfile = chkrpl.v;

--width (input the width of the register(s); must be 1 to 64 decimal value)

--stages (input the number of pipeline stages; must be 2 to 128 decimal value)

--reset (input the register reset value in decimal or hexadecimal; value must not exceed register width capacity)

--outfile (input the output module file name with extension)

--help  input this command for help on command line options

=cut

=begin
man mv  :for manual, give example of the param file
=cut