#!/usr/bin/perl


use strict;
use utf8;
binmode STDIN, ':utf8';
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $newSent =1;
my $wordCount;

while(<>){
	if(/^\s*$/){
         print "\n";
         $newSent=1;
    }
    else
    {
    	if($newSent==1){
    		$wordCount = 1;
    		$newSent =0;
    	}
    	else{
    		$wordCount++;
    	}
    	# print word number
    	print "$wordCount\t";
    	my @rows = split('\t');
    	
    	   	#print dates:
    	if (@rows[-1] =~ /^W/)
    	{	#   dates: 24_de_junio     [??:24/6/??:??.??:??] -> 
			# 6	24	24	w	w	_	3	cc	_	_
			# 7	de	de	s	sp	gen=c|num=c|for=s	6	CONCAT	_	_
			# 8	junio	junio	n	nc	gen=m|num=s	7	CONCAT	_	_
	        my $date = @rows[0];
	        my @tokens = split(/\_/,$date);
	  		
	  		if(scalar(@tokens)>1){
		  		foreach my $token (@tokens)
		  		{
		  			if($token eq @tokens[0]){
		  				#print "$token\tFILL_IN\n";
		  				&printDateToken($token);
		  			}
		  			else{
		  				$wordCount++;
		  				#print "$wordCount\t$token\tFILL_IN\n";
		  				print "$wordCount\t";
		  				&printDateToken($token);
		  			}
		  		}
	  		}
	  		else{
	  			print "$date\t$date\tw\tw\t_\t_\t_\t_\t_\n";
	  		}
		}
		else
		{
	    	# print word form
	    	if(@rows[1] eq 'uc'){
	    		print ucfirst(@rows[0])."\t";
	    	}
	    	else{
	    		print @rows[0]."\t";
	    	}
	    	# print lemma
	    	# get lemma(s) associated with tag (to the left of correct tag)
	    	my $tag = @rows[-1];
	    	chomp($tag);
	    	my @indexes = grep { $rows[$_] eq $tag } 0..18;
	    	# if exactly one lemma associated with this tag, print it (at index-1 in rows)
	    	if(scalar(@indexes) == 1){
	    		# if lemma is 'estar' -> print form instead of lemma (weird feature in parser model)
	    		if($rows[@indexes[0]-1] eq 'estar'){
	    			print @rows[0]."\t";
	    		}
	    		else{
	    			print $rows[@indexes[0]-1]."\t";
	    		}
	    	}
	    	elsif(scalar(@indexes)>1){
	    		foreach my $i (@indexes){
	    			if($i == @indexes[-1]){
	    				print @rows[$i-1]."\t";
	    			}
	    			else{
	    				print @rows[$i-1]."/"; 
	    			}
	    		}
	    	}
	    	# if no index -> wapiti assigned a tag that wasn't suggested by freeling -> number or proper name, should only have one lemma
	    	# -> @rows[4] should be ZZZ, if not: don't know which lemma...
	    	else{
	    		if(@rows[4] eq 'ZZZ'){
	    			print "@rows[2]\t";
	    		}
	    		else{
	    			# if number or date mismatch
	    			if($tag =~ /^DN|^W$/){
	    				@indexes = grep { $rows[$_] eq 'Z' } 0..18;
	    			}
	    			elsif($tag eq 'Z'){
	    				@indexes = grep { $rows[$_] eq 'W' } 0..18;
	    			}
	    			# if proper name/common noun mismatch
	    			if($tag =~ /^NP/){
	    				@indexes = grep { $rows[$_] =~ 'NC' } 0..18;
	    			}
	    			elsif($tag =~ /^NC/){
	    				@indexes = grep { $rows[$_] =~ /^NC/ } 0..18;
	    			}
	    			# if exactly one lemma associated with this tag, print it (at index-1 in rows)
			    	if(scalar(@indexes) == 1){
			    		print $rows[@indexes[0]-1]."\t";
			    	}
			    	elsif(scalar(@indexes)>1){
			    		foreach my $i (@indexes){
			    			if($i == @indexes[-1]){
			    				print @rows[$i-1]."\t";
			    			}
			    			else{
			    				print @rows[$i-1]."/"; 
			    			}
			    		}
			    	}
			    	# should not happen! (TODO: locuciones -> let Freeling decide!)
	    			else{
	    				print "UNKNOWN!!\t";
	    			}
	    		}
	    	}
	    	# print cpos and short pos
	    	my $cpos = lc(substr($tag, 0, 1));
	    	my $shortpos = lc(substr($tag, 0, 2));
	    	
	    	if($cpos =~ /^z|^f/){
	    		#$shortpos = ucfirst($shortpos);
	    		$shortpos = $tag;
	    		$cpos = uc($cpos);
	    		
	    	}
	    	if($shortpos eq 'np'){$shortpos = "nc";}
	    	print "$cpos\t$shortpos\t";
	    	
	    	
	    	# print morphology
	    	my $features;
	    	my $gen, my $num, my $fun, my $pno, my $per, my $type, my $semclass, my $mod, my $ten, my $cas, my $form;
	    	$tag = lc($tag);
	    	if ($cpos eq 'a') #Adjectives => 4:gen,5:num[,6:fun]
	 		{
	  			$gen = substr($tag,3,1);
	  		 	$num = substr($tag,4,1);
	   		 	$fun = substr($tag,5,1);
	  		  	$features = "gen=".$gen."|num=".$num;
	   			if ($fun eq "p"){
	     		 $features.="|fun=".$fun;
	    		}
	  		}
		   elsif($cpos eq 'd')	# Determiners => 4:gen,5:num[,3:per[,6:pno]]
		   {
			    $gen = substr($tag,3,1);
			    $num = substr($tag,4,1);
			    $per = substr($tag,2,1);
			    $pno = substr($tag,5,1);
			    $features= "gen=".$gen."|num=".$num;
			    if ($per ne "0")
			    {
			      $features .= "|per=".$per;
			      if ($pno ne "0"){
			        $features.="|pno=".$pno;
			      }
			    }
		    }
	       elsif ($cpos eq "n")	# Nouns => 3:gen,4:num, special case, proper nouns: give them pos=nc, but mark as np in morph column (np=SP,O0,G0,V0)-> delete, desr can't handle this
		   {
			    $gen = substr($tag,2,1);
			    if ($gen eq "0"){
			      $gen = "c";
			    }
			    $num = substr($tag,3,1);
			    if ($num eq "0") {
			      $num = "c";
			    }
			    $type = substr($tag,1,1);
			    # TODO: set type of proper name with freeling
			    #if proper noun, add type to morph
			    if($type eq "p")
			    {
			       $semclass = substr($tag,4,2);
			       $features = "gen=".$gen."|num=".$num."|np=".$semclass;  
			    }
			    else
			    {
			      $features="gen=".$gen."|num=".$num;
			    }
			}
		    elsif ($cpos eq "v")	# Verbs => 7:gen,6:num[,5:per],3:mod[,4:ten]
	        {
			    $gen = substr($tag,6,1);
			    if ($gen eq "0"){
			      $gen = "c";
			    }
			    $num = substr($tag,5,1);
			    if ($num eq "0"){
			      $num = "c";
			    }
			    $features="gen=".$gen."|num=".$num;
			    $per = substr($tag, 4,1);
			    $mod = substr($tag,2,1);
			    $ten = substr($tag,3,1);
			    if ($per ne "0"){
			      $features.="|per=".$per;
			    }
			    $features.="|mod=".$mod;
			    if ($ten ne "0")
			    {
			      $features.="|ten=".$ten;
			    }
		    }
		    elsif ($cpos eq "p")	# Pronouns => 4:gen,5:num[,3:per][,6:cas]
	 		{
			    $gen = substr($tag,3,1);
			    $num = substr($tag,4,1);
			    if ((substr($tag,0,2) eq "pr")){
				      $gen = "0";
				      if ($num eq "n"){
				        $num = "c";
				      }
				}
			    else{ 
			      if ($gen eq "0"){
			        $gen = "c";
			      }
			      if ($num eq "0" || $num eq "n"){
			        $num = "c";
			      }
			    }
	    		$features= "gen=".$gen."|num=".$num;
	    		# special case 'se' FL: P00CN000, should be -> gen=c|num=c|per=3 (not p0!, per=3)
			    $per = substr($tag,2,1);
			    if($per eq "0" && substr($tag,0,2) eq "p0" ){
			      $features.="|per=3";
			    }
			    elsif ($per ne "0"){
			      $features.="|per=".$per;
			    }
			    $cas = substr($tag,5,1);
			    if ($cas ne "0"){
			      $features.="|cas=".$cas;
			    }
			 }
			 elsif ($cpos eq "s")	# Prepositions => 4:gen,5:num,3:for
			 {
			    $gen = substr($tag,3,1);
			    if ($gen eq "0"){
					$gen = "c";
			    }
			    $num = substr($tag,4,1);
			    if ($num eq "0"){
			      $num = "c";
			    }
			    $form = substr($tag,2,1);
			    $features="gen=".$gen."|num=".$num."|for=".$form;
			 }  
	 		 else # if (cpos == L"r") c|f|i|r|y|w|z
	  		 {
	   			 $features="_";
	 		 }
	  		$features.="\t_\t_\t_\t_";
		
		  	print "$features";
	        print "\n";
	     } 
    }
}

sub printDateToken{
	my $date = $_[0];
	
	if($date =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre|lunes|martes|miércoles|jueves|viernes|sábado|domingo|día|mes|año|siglo/){
		print "$date\t$date\tn\tnc\tgen=m|num=s\t_\t_\t_\t_\n";
	}
	elsif($date eq 'de'){
		print "de\tde\ts\tsp\tgen=c|num=c|for=s\t_\t_\t_\t_\n";
	}
	elsif($date eq 'del'){
		print "de\tde\ts\tsp\tgen=m|num=s|for=c\t_\t_\t_\t_\n";
	}
	elsif($date =~ /^\d+$|^[xivXIV]+$/){
		print "$date\t$date\tw\tw\t_\t_\t_\t_\t_\n";
	}
	else{
		print "$date\tFILL_IN\n";
	}
}