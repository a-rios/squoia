
#!/usr/bin/perl

use utf8;                  # Source code is UTF-8
#use open ':utf8';

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use strict;


# read in conll sentences

my %sents =();
my $count_sent=1;
my $count_word=1;

while(<>){
	if($_ =~ /^$/){
		$count_sent++;
		$count_word =1;
	}
	else{
		$sents{$count_sent}{$count_word} = $_;
		$count_word++;
	}
	
}



my $dev_set_size = 1000;
my $test_set_size = 1000;


my $range = scalar(keys %sents);
print "random range is $range, test set size : $test_set_size\n";

my %testset= ();
# get random test set
while(scalar(keys %testset) <= $test_set_size){
	my $randomSent = int(rand($range));
	$testset{$randomSent}=1;
	#print "random in test  was $randomSent\n";		
}

my %devset=();
# get random development set for optimization
while(scalar(keys %devset) <= $dev_set_size){
	my $randomSent = int(rand($range));
	unless(exists($testset{$randomSent})){
		$devset{$randomSent}=1;
	}
	#print "random in opt was $randomSent\n";		
}
		
# open test, opt-set and train file
my $test = "test.conll";
open (TEST, ">:encoding(UTF-8)", $test) or die "Can't open file $test: $!\n";

my $train = "train.conll";
open (TRAIN, ">:encoding(UTF-8)", $train) or die "Can't open file $train: $!\n";

my $dev = "dev.conll";
open (DEV, ">:encoding(UTF-8)", $dev) or die "Can't open file $dev: $!\n";
		 
foreach my $key (keys %sents){
	my $sent_lines = $sents{$key};
	# in test set
	if($testset{$key} ){
		 foreach my $linenr (sort {$a <=> $b} keys %{$sent_lines}){
				print TEST $sent_lines->{$linenr};
			}
		print TEST "\n";
	}
	elsif($devset{$key}){
		 foreach my $linenr (sort {$a <=> $b} keys %{$sent_lines}){
				print DEV $sent_lines->{$linenr};
			}
		print DEV "\n";
	}
	
	# in train set
	else{
		foreach my $linenr (sort {$a <=> $b} keys %{$sent_lines}){
				print TRAIN $sent_lines->{$linenr};
			}
			print TRAIN "\n";
	}

}

 #my $opt_set_size = 5000;
#my $test_set_size = 1000;
#
#
#my $range = scalar(keys %sents);
#print "random range is $range, test set size : $test_set_size\n";
#
#my %testset= ();
## get random test set
#while(scalar(keys %testset) <= $test_set_size){
#	my $randomSent = int(rand($range));
#	$testset{$randomSent}=1;
#	#print "random in test  was $randomSent\n";		
#}
#
#my %optset=();
## get random development set for optimization
#while(scalar(keys %optset) <= $opt_set_size){
#	my $randomSent = int(rand($range));
#	unless(exists($testset{$randomSent})){
#		$optset{$randomSent}=1;
#	}
#	#print "random in opt was $randomSent\n";		
#}
#		
## open test, opt-set and train file
#my $test = "test.conll";
#open (TEST, ">:encoding(UTF-8)", $test) or die "Can't open file $test: $!\n";
#
#my $train = "train.conll";
#open (TRAIN, ">:encoding(UTF-8)", $train) or die "Can't open file $train: $!\n";
#
#my $opt = "opt.conll";
#open (OPT, ">:encoding(UTF-8)", $opt) or die "Can't open file $opt: $!\n";
#		 
#foreach my $key (keys %sents){
#	my $sent_lines = $sents{$key};
#	# in test set
#	if($testset{$key} ){
#		 foreach my $linenr (sort {$a <=> $b} keys %{$sent_lines}){
#				print TEST $sent_lines->{$linenr};
#			}
#		print TEST "\n";
#	}
#	# in train set
#	else{
#		 if(!exists($optset{$key})) {
#		 	 foreach my $linenr (sort {$a <=> $b} keys %{$sent_lines}){
#					print TRAIN $sent_lines->{$linenr};
#				}
#				print TRAIN "\n";
#		 }
#		 else{
#			 foreach my $linenr (sort {$a <=> $b} keys %{$sent_lines}){
#						print TRAIN $sent_lines->{$linenr};
#						print OPT $sent_lines->{$linenr};
#					}
#					print TRAIN "\n";
#					print OPT "\n";
#			 	}
#	}
#
#}
 
