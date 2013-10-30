#!/usr/bin/perl

#use utf8;                  # Source code is UTF-8

use strict;
use Storable;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my %verbLexWithFrames   = %{ retrieve("VerbLex") };

		# main verb frames:
		print STDOUT "mA11,mA12,mA13,mA21,mA22,mA23,mA31,mA32,mA33,mA34,mA35,mB11,mB12,mB21,mB22,mB23,mC11,mC21,mC31,mC41,mC42,mD11,mD21,mD31,";
		
		# main verb morphology
		print STDOUT "mType,mTense,mMod,";
		
		# subordinated verb frames:
		print STDOUT "sA11,sA12,sA13,sA21,sA22,sA23,sA31,sA32,sA33,sA34,sA35,sB11,sB12,sB21,sB22,sB23,sC11,sC21,sC31,sC41,sC42,sD11,sD21,sD31,";
		
		# subordinated verb morphology
		print STDOUT "sType,sTense,smMod,";
		
		# last row: class
		print STDOUT "linker,form\n";
		
while(<>){
	if($_ !~ /^\%/ and $_ !~ /^\s*$/ ){ 
		chomp;
		my ($main,$sub,$linker,$form) = split(',');
		my $mainFrames = $verbLexWithFrames{$main};
		my $subFrames = $verbLexWithFrames{$sub};
		#print "$main   ";
		#print "$sub   ";
		my %mainLabels = map { $_ => 0; } qw(mA11 mA12 mA13 mA21 mA22 mA23 mA31 mA32 mA33 mA34 mA35 mB11 mB12 mB21 mB22 mB23 mC11 mC21 mC31 mC41 mC42 mD11 mD21 mD31);
		my %subLabels = map { $_ => 0; } qw(sA11 sA12 sA13 sA21 sA22 sA23 sA31 sA32 sA33 sA34 sA35 sB11 sB12 sB21 sB22 sB23 sC11 sC21 sC31 sC41 sC42 sD11 sD21 sD31);
		
		#main verb
		if($mainFrames){
			#print "main: $main ";
			foreach my $f (@$mainFrames){
				my ($label) = ($f =~ m/^(.\d\d)/);
				# some errors in Ancora dix! skip those... (e.g. 'dar' has a frame 'a3'?!)
				unless($label eq ''){
					$label = "m".$label;
					#print "$label  $f\n";
					$mainLabels{$label}=1;
				}
			}
		}
		
		foreach my $key ( sort keys %mainLabels) {
			#print STDERR "$key: ".$mainLabels{$key}." ";
			print "$mainLabels{$key},";
		} 
		print "$main:mType,mTense,mMod,";
		 # sub verb
		if($subFrames){
			foreach my $f (@$subFrames){
				my ($label) = ($f =~ m/^(.\d\d)/);
				# some errors in Ancora dix! skip those... (e.g. 'dar' has a frame 'a3'?!)
				unless($label eq ''){
					$label = "s".$label;
					#print "$label  $f\n";
					$subLabels{$label}=1;
				}
			}
		}
		
		foreach my $key ( sort keys %subLabels) {
			#print STDERR "$key: ".$subLabels{$key}." ";
			print "$subLabels{$key},";
		}
		print "$sub:sType,sTense,sMod,";
		
		print "$linker,$form\n";
	}
	else
	{
		print $_;
	}
	
	
}