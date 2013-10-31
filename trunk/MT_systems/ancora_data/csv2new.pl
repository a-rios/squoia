#!/usr/bin/perl

#use utf8;                  # Source code is UTF-8

use strict;
use Storable;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my %verbLexWithFrames   = %{ retrieve("VerbLex") };
my %verbLemClasses =  %{ retrieve("verbLemClasses") };


        # print main verb lemma and senses (wordnet)
        print STDOUT "mLem,mSem29,mSem30,mSem31,mSem32,mSem33,mSem34,mSem35,mSem36,mSem37,mSem38,mSem39,mSem40,mSem41,mSem42,mSem43,";
		# main verb frames:
		print STDOUT "mA11,mA12,mA13,mA21,mA22,mA23,mA31,mA32,mA33,mA34,mA35,mB11,mB12,mB21,mB22,mB23,mC11,mC21,mC31,mC41,mC42,mD11,mD21,mD31,";
		
		# main verb morphology
		print STDOUT "mTense,mMod,mPers,mNum,";
		
		# print subordinated verb lemma and senses (wordnet)
        print STDOUT "sLem,sSem29,sSem30,sSem31,sSem32,sSem33,sSem34,sSem35,sSem36,sSem37,sSem38,sSem39,sSem40,sSem41,sSem42,sSem43,";
        
		# subordinated verb frames:
		print STDOUT "sA11,sA12,sA13,sA21,sA22,sA23,sA31,sA32,sA33,sA34,sA35,sB11,sB12,sB21,sB22,sB23,sC11,sC21,sC31,sC41,sC42,sD11,sD21,sD31,";
		
		# subordinated verb morphology
		print STDOUT "sTense,smMod,sPers,sNum,";
		
		# last row: class
		print STDOUT "linker,form\n";
		
while(<>){
	if($_ !~ /^\%/ and $_ !~ /^\s*$/ ){ 
		chomp;
		my ($main,$sub,$linker,$form,$mPos,$sPos) = split(',');
		my $mainFrames = $verbLexWithFrames{$main};
		my $subFrames = $verbLexWithFrames{$sub};
		#print "$main   ";
		#print "$sub   ";
		my %mainClasses = map { $_ => 0; } qw(mSem29 mSem30 mSem31 mSem32 mSem33 mSem34 mSem35 mSem36 mSem37 mSem38 mSem39 mSem40 mSem41 mSem42 mSem43);
		my %subClasses =  map { $_ => 0; } qw(sSem29 sSem30 sSem31 sSem32 sSem33 sSem34 sSem35 sSem36 sSem37 sSem38 sSem39 sSem40 sSem41 sSem42 sSem43);
		my %mainLabels = map { $_ => 0; } qw(mA11 mA12 mA13 mA21 mA22 mA23 mA31 mA32 mA33 mA34 mA35 mB11 mB12 mB21 mB22 mB23 mC11 mC21 mC31 mC41 mC42 mD11 mD21 mD31);
		my %subLabels = map { $_ => 0; } qw(sA11 sA12 sA13 sA21 sA22 sA23 sA31 sA32 sA33 sA34 sA35 sB11 sB12 sB21 sB22 sB23 sC11 sC21 sC31 sC41 sC42 sD11 sD21 sD31);

		print "$main,";
		# print semantic class(es)
		if($verbLemClasses{$main}){
			foreach my $class (keys %{$verbLemClasses{$main}}){
				#print STDERR "$main: $class ".$verbLemClasses{$main}{$class}."\n";
				my $mclass = "mSem".$class;
				$mainClasses{$mclass}= $verbLemClasses{$main}{$class};
			}
		}
		foreach my $key ( sort keys %mainClasses) {
			#print STDERR "$key: ".$mainClasses{$key}."\n";
			#print "$mainClasses{$key},";
			if($mainClasses{$key}>0){
				print "1,";
			}
			else{
				print "0,";
			}
		}
		
		# print frames
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
			#print STDERR "$key: ".$mainLabels{$key}."\n";
			print "$mainLabels{$key},";
		} 
		
		my $mTense = substr($mPos,3,1);
		my $mMod = substr($mPos,2,1);
		my $mPers = substr($mPos,4,1);
		my $mNum = substr($mPos,5,1);
		#print "$mPos: tns:$mTense, mod:$mMod, prs:$mPers, num:$mNum";
		print "$mTense,$mMod,$mPers,$mNum,";
		
		###### subordinated verb ########
		print "$sub,";
		
		
		# print semantic class(es)
		if($verbLemClasses{$sub}){
			foreach my $class (keys %{$verbLemClasses{$sub}}){
				#print STDERR "$sub: $class ".$verbLemClasses{$sub}{$class}."\n";
				my $sclass = "sSem".$class;
				$subClasses{$sclass}= $verbLemClasses{$sub}{$class};
			}
		}
		foreach my $key ( sort keys %subClasses) {
			#print STDERR "$key: ".$subClasses{$key}."\n";
			#print "$subClasses{$key},";
			if($subClasses{$key}>0){
				print "1,";
			}
			else{
				print "0,";
			}
		}
		
		
		# print sub verb frames
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
		my $sTense = substr($sPos,3,1);
		my $sMod = substr($sPos,2,1);
		my $sPers = substr($sPos,4,1);
		my $sNum = substr($sPos,5,1);
		
		print "$sTense,$sMod,$sPers,$sNum,";
		
		print "$linker,$form\n";
	}
	else
	{
		print $_;
	}
	
	
}