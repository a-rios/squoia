#!/usr/bin/perl

package squoia::crf2conll;

use strict;
use utf8;

sub main{
	my $inputLines = $_[0];
	my @outputLines;
	my $newSent =1;
	my $wordCount;
	
	#foreach my $line (@$inputLines){
	while(<$inputLines>){
		my $line = $_;
		if($line =~ /^\s*$/){
	         #print "\n";
	         push(@outputLines, "\n");
	         $newSent=1;
	    }
	    else
	    {
	    	my $outLine ="";
	    	if($newSent==1){
	    		$wordCount = 1;
	    		$newSent =0;
	    	}
	    	else{
	    		$wordCount++;
	    	}
	    	# print word number
	    	$outLine .= "$wordCount\t";
	    	my @rows = split('\t', $line);
	    	
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
			  				#print "$wordCount\t";
			  				$outLine .= "$wordCount\t";
			  				$outLine .= &printDateToken($token);
			  			}
			  		}
		  		}
		  		else{
		  			push(@outputLines, "$date\t$date\tw\tw\t_\t_\t_\t_\t_\n");
		  		}
			}
			else
			{
		    	# print word form
		    	if(@rows[1] eq 'uc'){
		    		#print ucfirst(@rows[0])."\t";
		    		$outLine .= ucfirst(@rows[0])."\t";
		    	}
		    	else{
		    		#print @rows[0]."\t";
		    		$outLine .=  @rows[0]."\t";
		    	}
		    	# print lemma
		    	# get lemma(s) associated with tag (to the left of correct tag)
		    	my $tag = @rows[-1];
		    	chomp($tag);
		    	if($tag =~ /^NP/){
		    		# prelabeled & classified by FL -> take second last as tag if there is one!
		    		if(@rows[-2] =~ /^NP/){
		    				$tag = @rows[-2];
		    		}
		    	}
		    	my @indexes = grep { $rows[$_] eq $tag } 0..18;
		    	# if exactly one lemma associated with this tag, print it (at index-1 in rows)
		    	if(scalar(@indexes) == 1){
		    		# if lemma is 'estar' -> print form instead of lemma (weird feature in parser model)
		    		if($rows[@indexes[0]-1] eq 'estar'){
		    			#print @rows[0]."\t";
		    			$outLine .= @rows[0]."\t";
		    		}
		    		else{
		    			#print $rows[@indexes[0]-1]."\t";
		    			$outLine .=$rows[@indexes[0]-1]."\t";
		    		}
		    	}
		    	elsif(scalar(@indexes)>1){
		    		# if more than one lemma associated with this tag: write lemma1/lemma2 (but check if they're the same!)
		    		my $printedLems = '';
		    		foreach my $i (@indexes){
		    			#last lemma
				    	if($i == @indexes[-1])
				    	{
				    		my $lem = @rows[$i-1];
				    		if($printedLems =~ /#\Q$lem\E#/){
				    			$outLine .= "\t";
				    		}
				    		else{
				    			$outLine .= "##".$lem."\t";
				    			#print "/".$lem."\t";
				    		}
				    	}
				    	#first lemma
				    	elsif($i == @indexes[0]){
				    		my $lem = @rows[$i-1];
		    				unless($printedLems =~ /#\Q$lem\E#/){
		    					$printedLems .= "#$lem#";
		    					$outLine .= $lem;
		    				}
				    	}
				    	else{
				    		my $lem = @rows[$i-1];
		    				unless($printedLems =~ /#\Q$lem\E#/){
		    					$printedLems .= "#$lem#";
		    					$outLine .= "##".$lem;
		    				}
				    	}
		    		}
		    	}
		    	# if no index -> wapiti assigned a tag that wasn't suggested by freeling -> number or proper name, should only have one lemma
		    	# -> @rows[4] should be ZZZ, if not: don't know which lemma...
		    	else{
		    		if(@rows[4] eq 'ZZZ'){
		    			#print "@rows[2]\t";
		    			$outLine .= "@rows[2]\t";
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
		    				# prelabeled & classified by FL -> take second last as tag if there is one!
		    				if(@rows[-2] =~ /^NP/){
		    					$tag = @rows[-2];
		    				}
		    				else{
		    					@indexes = grep { $rows[$_] =~ 'NC' } 0..18;
		    				}
		    			}
		    			elsif($tag =~ /^NC/){
		    				@indexes = grep { $rows[$_] =~ /^NC/ } 0..18;
		    			}
		    			# if exactly one lemma associated with this tag, print it (at index-1 in rows)
				    	if(scalar(@indexes) == 1){
				    		#print $rows[@indexes[0]-1]."\t";
				    		$outLine .= $rows[@indexes[0]-1]."\t";
				    	}
				    	elsif(scalar(@indexes)>1)
				    	{
				    		# if more than one lemma associated with this tag: write lemma1/lemma2 (but check if they're the same!)
		    				my $printedLems = '';
				    		foreach my $i (@indexes)
				    		{  
				    			#last lemma
				    			if($i == @indexes[-1])
				    			{
				    				my $lem = @rows[$i-1];
				    				if($printedLems =~ /#\Q$lem\E#/){
		    							$outLine .= "\t";
				    				}
				    				else{
				    					#print "/".$lem."\t";
				    					$outLine .= "/".$lem."\t";
				    				}
				    			}
				    			#first lemma
				    			elsif($i == @indexes[0]){
				    				my $lem = @rows[$i-1];
		    						unless($printedLems =~ /#\Q$lem\E#/){
		    							$printedLems .= "#$lem#";
		    							$outLine .= $lem;
		    						}
				    			}
				    			else{
				    				my $lem = @rows[$i-1];
		    						unless($printedLems =~ /#\Q$lem\E#/){
		    							$printedLems .= "#$lem#";
		    							#print "/".$lem;
		    							$outLine .= "/".$lem;
		    						}
				    			}
				    		}
				    	}
				    	# should not happen! (TODO: locuciones -> let Freeling decide!)
		    			else{
		    				$outLine .= "UNKNOWN!!\t";
		    			}
		    		}
		    	}
		    	# print cpos and short pos
		    	my $cpos = lc(substr($tag, 0, 1));
		    	my $shortpos = lc(substr($tag, 0, 2));
		    	
		    	if($cpos =~ /^f/){
		    		#$shortpos = ucfirst($shortpos);
		    		$shortpos = $tag;
		    		$cpos = uc($cpos);
		    		
		    	}
		    	
		    	elsif($cpos eq 'z'){
		    		$shortpos = ucfirst($shortpos);
		    		#$shortpos = "Z" ;
		    		
		    	}
		    	
		    	if($shortpos eq 'np'){$shortpos = "nc";}
		    	#print "$cpos\t$shortpos\t";
		    	$outLine .= "$cpos\t$shortpos\t";
		    	
		    	
		    	# print morphology
		    	my $features;
		    	my $gen, my $num, my $fun, my $pno, my $per, my $type, my $semclass, my $mod, my $ten, my $cas, my $form, my $polite;
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
				      # print STDERR "np class: $semclass $tag\n";
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
			    elsif ($cpos eq "p")	# Pronouns => 4:gen,5:num[,3:per][,6:cas][,7:polite]
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
				    $pno = substr($tag,6,1);
				    if ($pno ne "0"){
				      $features.="|pno=".$pno;
				    }
				    $polite = substr($tag,7,1);
				    if ($polite ne "0"){
				      $features.="|pol=".$polite;
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
			
			  	$outLine .= "$features\n";
			  	push(@outputLines, $outLine);
		     } 
	    }
	}
	return \@outputLines;
}

sub printDateToken{
	my $date = $_[0];
	my $subOutLine="";
	
	if($date =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre|lunes|martes|miércoles|jueves|viernes|sábado|domingo|día|mes|año|siglo/){
		$subOutLine .= "$date\t$date\tn\tnc\tgen=m|num=s\t_\t_\t_\t_\n";
	}
	elsif($date =~ /^de$|^a$/){
		$subOutLine .=  "de\tde\ts\tsp\tgen=c|num=c|for=s\t_\t_\t_\t_\n";
	}
	elsif($date eq 'del'){
		$subOutLine .=  "de\tde\ts\tsp\tgen=m|num=s|for=c\t_\t_\t_\t_\n";
	}
	elsif($date =~ /mañana|tarde|noche/){
		$subOutLine .=  "$date\t$date\tn\tnc\tgen=f|num=s\t_\t_\t_\t_\n";
	}
	elsif($date =~ /^el$/){
		$subOutLine .= "$date\tel\td\tda\tgen=m|num=s\t_\t_\t_\t_\n";
	}
	elsif($date =~ /^los$/){
		$subOutLine .=  "$date\tel\td\tda\tgen=m|num=s\t_\t_\t_\t_\n";
	}
	elsif($date =~ /^la$/){
		$subOutLine .=  "$date\tel\td\tda\tgen=f|num=s\t_\t_\t_\t_\n";
	}
	elsif($date =~ /^las$/){
		$subOutLine .=  "$date\tel\td\tda\tgen=f|num=p\t_\t_\t_\t_\n";
	}
	elsif($date =~ /^\d+$|^[xivXIV]+$|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|veinte|treinta/){
		$subOutLine .=  "$date\t$date\tw\tw\t_\t_\t_\t_\t_\n";
	}
	else{
		$subOutLine .=  "$date\tFILL_IN\n";
	}
	return $subOutLine;
}

1;