
#!/usr/bin/perl

use strict;
use open ':utf8';
binmode ':utf8';


my @words;
my $newWord=1;
my $index=1;
my $linecount=0;
my $s_count=1;

while(<>)
{
	$linecount++;
	if (/^$/)
	{
		$newWord=1;
	}
	elsif($_ =~ /#EOS/){
		print "$index\tVROOT\t_\t_\t_\t_\n\n";
		$index=1;
		$s_count++;
	}
	elsif($newWord ) 
	{	
		my ($form, $analysis) = split(/\t/);
		#print $analysis;
		
		chomp($analysis);
		
		#if no analysis: print with _
		if($_ =~ /\t\+\?/){
			my ($word, @rest) = split(/\t/,$_);
			print STDOUT "$index\t$word\t_\t_\t_\t_\n";
		}
		
		else
		{
			my (@DBs) = split(/\[\^DB\]/, $analysis);
			
			foreach my $db (@DBs)
			{
				my ($roottag) = $db =~ m/\[(ALFS|AdvES|ConjES|PrepES|CARD|FLM|NP|NRoot|NRootNUM|NRootES|NRootCMP|VRoot|VRootES|PrnDem|PrnInterr|PrnPers(\+Lim)?\+[123]\.(Sg|Pl)(\.Incl|\.Excl)?|SP|\$.|AdvES|PrepES|ConjES|Part_Affir|Part_Cond|Part_Conec|Part_Contr|Part_Disc|Part_Neg|Part_Neg_Imp|Part_Sim).?\]/ ;
				my ($rootstring) = $db =~ m/^([^\[]+)/g;
	
				my ($trans) = $db =~ m/\[=([^\]]+)\]/;
				
				
				my @morphtags =  $db =~ m/\[(\+.+?)\]/g ;
				my @morphtypes =  $db =~ m/\[(Amb|NDeriv|VDeriv|NS|VS|Cas|Tns|Num|Asp|Mod|NPers|VPers|Tns\_VPers)\]/g ;
				my @morphstrings = $db =~ m/\[--\]([^\[]+)/g;
			
			
				my $morphtype_string;
				#print STDERR "root tag: $roottag\n";
				
				if($roottag ne '' ){
					$morphtype_string = "Root";
					for(my $i=0;$i<scalar(@morphtypes);$i++){
						$morphtype_string .= "_".@morphtypes[$i];
					}
				}
				else{
					$morphtype_string = @morphtypes[0];
					for(my $i=1;$i<scalar(@morphtypes);$i++){
						$morphtype_string .= "_".@morphtypes[$i];
					}
				}
	
				
				my $db_string = $rootstring;
				foreach my $morphstring (@morphstrings){
					$db_string .= $morphstring;
				}
				
				if ($db =~ /^\[--\]/){
					$db_string = "-".$db_string;
				}
		    	#print db
				
					
				
				my $db_morphs;
				if($roottag ne '' ){
					$db_morphs="Root=$roottag";
				}
				
				if(scalar(@morphtags) == scalar(@morphtypes)){
					for(my $i=0;$i<scalar(@morphtags);$i++ ){
						$db_morphs.= "|".@morphtypes[$i]."=".@morphtags[$i];
					}
				}
				else{
					print STDERR "different number of morph tags and types in line $linecount in sentence $s_count, cannot convert!\n";
					exit(0);
				}
				
				# special cases:
				
				# for roots: add translation
				if($roottag ne ''&& $trans ne ''){
					$db_morphs .= "|trans=".$trans;
				}
		    
		    	# delete leading '|' if no root in db
		    	$db_morphs =~ s/^\|//;
		    	#punctuation
		    	if( $roottag =~ /^\$/){
		    		$db_morphs= "_";
		    	 	$morphtype_string = $roottag;
		    	}
		    	
		    	# AdvES, ConjES, PrepES -> SP
		    	if($roottag =~ /^AdvES|ConjES|PrepES$/){
		    		$roottag = 'SP';
		    	}
		    	
		    	# SP -> db_morphs = SP, no root
		    	if($roottag =~ /^SP|CARD|ALFS|FLM$/){
		    		$db_morphs = "_";
		    		$morphtype_string = $roottag;
		    	}
		    	
		    	
		    	#print "$index\t$db_string\t_\t$morphtype_string\t$morphtype_string\t$db_morphs\t_\t_\t_\t_\n";
		    	print "$index\t$db_string\t_\t$morphtype_string\t$morphtype_string\t$db_morphs\n";
			}
		}
		$index++;
	 }
	 #no new word: another analysis still left for this word -> dump
	 else{
	 	next;
	 }
	
}

  

 