#!/usr/bin/perl

package squoia::crf2conll;

use strict;
#use utf8;
#use utf8;
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
#binmode STDERR, ':utf8';


my %mapMonthsDays = ( 
	'enero' => "[??:??/01/??:??.??]",
	'febrero' => "[??:??/02/??:??.??]",
	'marzo' => "[??:??/03/??:??.??]",
	'abril' => "[??:??/04/??:??.??]",
	'mayo' => "[??:??/05/??:??.??]",
	'junio' => "[??:??/06/??:??.??]",
	'julio' => "[??:??/07/??:??.??]",
	'agosto' => "[??:??/08/??:??.??]",
	'septiembre' => "[??:??/09/??:??.??]",
	'octubre' => "[??:??/10/??:??.??]",
	'noviembre' => "[??:??/11/??:??.??]",
	'diciembre' => "[??:??/12/??:??.??]",
	'lunes' => "[lunes:??/??/??:??.??]",
	'martes' => "[martes:??/??/??:??.??]",
	'miércoles' => "[miércoles:??/??/??:??.??]",
	'jueves' => "[jueves:??/??/??:??.??]",
	'viernes' => "[viernes:??/??/??:??.??]",
	'sábado' => "[sábado:??/??/??:??.??]",
	'domingo' => "[domingo:??/??/??:??.??]"
);

sub main{
	my $inputLines = $_[0];
	my $verbose = $_[1];

	print STDERR "#VERBOSE ". (caller(0))[3]."\n" if $verbose;

	my @outputLines;
	my $newSent =1;
	my $wordCount;
	
	
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
		        my $date = @rows[0];
		        my @tokens = split(/\_/,$date);

	  		if(scalar(@tokens)>1){
	  			my $dateOutlines = &printDateToken(\@tokens,$wordCount);
#		  		foreach my $token (@tokens)
#		  		{
#		  			if($token eq @tokens[0]){
#		  				#print "$token\tFILL_IN\n";
#		  				$outLine .= &printDateToken($token);
#		  				print STDERR "printed first date token $token, $outLine\n" if $verbose;
#		  			}
#		  			else{
#		  				$wordCount++;
#		  				#print "$wordCount\t$token\tFILL_IN\n";
#		  				#print "$wordCount\t";
#		  				$outLine .= "$wordCount\t";
#		  				$outLine .= &printDateToken($token);
#		  				print STDERR "printed date token $token, $outLine\n" if $verbose;
#		  			}
#		  		}
			  	push(@outputLines, @$dateOutlines);
			  	$wordCount += scalar(@tokens)-1;
	  		}
	  		else{
	  			push(@outputLines, "$wordCount\t$date\t$date\tw\tW\t_\n");
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
		    		#print $rows[@indexes[0]-1]."\t";
		    		$outLine .=$rows[@indexes[0]-1]."\t";
		    		#print STDERR "heeeere: $outLine\n";  		
		    	}
		    	elsif(scalar(@indexes)>1){
		    		# if more than one lemma associated with this tag: write lemma1/lemma2 (but check if they're the same!)
		    		# if one lemma is a digit and the other is a word (1,uno) -> if form is word, use form, if form is digit, use digit
		    		my $printedLems = '';
		    		my $lemmastring='';
		    		foreach my $i (@indexes){
		    			#last lemma
				    	if($i == @indexes[-1])
				    	{
				    		my $lem = @rows[$i-1];
				    		if($printedLems =~ /#\Q$lem\E#/){
				    			$lemmastring .= "\t";
				    		}
				    		else{
				    			$lemmastring .= "##".$lem."\t";
				    			#print "/".$lem."\t";
				    		}
				    	}
				    	#first lemma
				    	elsif($i == @indexes[0]){
				    		my $lem = @rows[$i-1];
		    				unless($printedLems =~ /#\Q$lem\E#/){
		    					$printedLems .= "#$lem#";
		    					$lemmastring .= $lem;
		    				}
				    	}
				    	else{
				    		my $lem = @rows[$i-1];
		    				unless($printedLems =~ /#\Q$lem\E#/){
		    					$printedLems .= "#$lem#";
		    					$lemmastring .= "##".$lem;
		    				}
				    	}
		    		}
		    		if($lemmastring =~ /\d+##\w/){
		    			my ($digit, $numberword) = ($lemmastring =~ m/(\d+)##(.+)/);
		    			$lemmastring = (@rows[0] =~ /\d+/) ? $digit."\t" : $numberword;
		    		}
		    		$outLine .= $lemmastring;
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
		    				# get all lemmas, if they're all the same: set this, else: set form
		    				my $lem = @rows[2];
		    				for(my $i=4;$i<=8;$i+=2){
		    					if(@rows[$i] ne $lem && @rows[$i] ne 'ZZZ'){
		    						# print form as lemma
		    						$lem = @rows[0];
		    						last;
		    					}
		    				}
		    				$outLine .= "$lem\t";
		    				#$outLine .= "UNKNOWN!!\t";
		    			}
		    		}
		    	}
		    	# print cpos and short pos
		    	my $cpos = lc(substr($tag, 0, 1));
		    	my $shortpos = substr($tag, 0, 2);
		    	
		    	if($cpos =~ /^f/){
		    		#$shortpos = ucfirst($shortpos);
		    		$shortpos = $tag;
		    		$cpos = uc($cpos);
		    		
		    	}
		    	
		    	elsif($cpos eq 'z'){
		    		$shortpos = ucfirst($shortpos);
		    		#$shortpos = "Z" ;
		    		
		    	}
		    	
		    	#if($shortpos eq 'np'){$shortpos = "nc";}
		    	#print "$cpos\t$shortpos\t";
		    	$outLine .= "$cpos\t$shortpos\t";
		    	
		    	# print morphology
		    	my $features = &eaglesToMorph($tag);
		    	
		  		#$features.="\t_\t_\t_\t_";
			  	$outLine .= "$features\n";
			  	push(@outputLines, $outLine);
		     } 
	    }
	}
#	foreach my $line (@outputLines){
#		print $line;
#	}
	return \@outputLines;
}

#		  		foreach my $token (@tokens)
#		  		{
#		  			if($token eq @tokens[0]){
#		  				#print "$token\tFILL_IN\n";
#		  				$outLine .= &printDateToken($token);
#		  				print STDERR "printed first date token $token, $outLine\n" if $verbose;
#		  			}
#		  			else{
#		  				$wordCount++;
#		  				#print "$wordCount\t$token\tFILL_IN\n";
#		  				#print "$wordCount\t";
#		  				$outLine .= "$wordCount\t";
#		  				$outLine .= &printDateToken($token);
#		  				print STDERR "printed date token $token, $outLine\n" if $verbose;
#		  			}
#		  		}

sub printDateToken{
	my $dateTokens = $_[0];
	my $actualWordCount = $_[1];
	my @dateOutlines;
	
	

	
	for (my $i=0;$i<scalar(@$dateTokens);$i++)
	{
		my $date = @$dateTokens[$i];
		my $subOutLine = "$actualWordCount\t";
		if(lc($date) =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre|lunes|martes|miércoles|jueves|viernes|sábado|domingo/){
			$subOutLine .= "$date\t".$mapMonthsDays{lc($date)}."\tw\tW\tne=date|eagles=W\n";
		}
		elsif(lc($date) =~ /día|mes|año|siglo/){
			$subOutLine .= "$date\t".lc($date)."\tn\tNC\tgen=m|num=s|postype=common|eagles=NCMS000\n";
		}
		elsif(lc($date) =~ /^de$|^a$/){
			$subOutLine .=  "$date\t$date\ts\tSP\tpostype=preposition|eagles=SPS00\n";
		}
		elsif(lc($date) eq 'del'){
			$subOutLine .=  "$date\tde\ts\tSP\tgen=c|num=m|postype=preposition|contracted=yes|eagles=SPCMS\n";
		}
		elsif(lc($date) =~ /madrugada|mañana|tarde|noche|hora|media/){
			$subOutLine .=  "$date\t".lc($date)."\tn\tNC\tgen=f|num=s|postype=common|eagles=NCFS000\n";
		}
		elsif(lc($date) =~ /^el$/){
			$subOutLine .= "$date\tel\td\tDA\tgen=m|num=s|postype=article|eagles=DA0MS0\n";
		}
		elsif(lc($date) =~ /^los$/){
			$subOutLine .=  "$date\tel\td\tDA\tgen=m|num=p|postype=article|eagles=DA0MP0\n";
		}
		elsif(lc($date) =~ /^la$/){
			$subOutLine .=  "$date\tel\td\tDA\tgen=f|num=s|postype=article|eagles=DA0FS0\n";
		}
		elsif(lc($date) =~ /^las$/){
			$subOutLine .=  "$date\tel\td\tDA\tgen=f|num=p|postype=article|eagles=DA0FP0\n";
		}
		elsif(lc($date) =~ /^por$/){
			$subOutLine .=  "$date\tpor\ts\tSP\tpostype=preposition|eagles=SPS00\n";
		}
		elsif(lc($date) =~ /^\d+$|^[0-2]?\d[:\.][0-5]\d$|^[xivXIV]+$|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|veinte|treinta/){
			if(lc(@$dateTokens[$i-1]) =~ /^año/){
				$subOutLine .=  "$date\t$date\tw\tW\tne=date|eagles=W\n";
			}
			elsif(lc(@$dateTokens[$i-2]) =~ /^enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre/ && lc(@$dateTokens[$i-1]) =~ /^de/ ){
				$subOutLine .=  "$date\t$date\tw\tW\tne=date|eagles=W\n";
			}
			else{
				$subOutLine .=  "$date\t$date\tz\tZ\tne=number|eagles=Z\n";
			}
		}
		elsif(lc($date) eq 'y'){
			$subOutLine .=  "$date\ty\tc\tCC\tpostype=coordinating|eagles=CC\n";
		}
		elsif(lc($date) eq 'menos'){
			$subOutLine .=  "$date\tmenos\tr\tRG\t_\n";
		}
		elsif(lc($date) =~ /pasado|próximo/){
			$subOutLine .=  "$date\t".lc($date)."\ta\tAQ\tgen=m|num=s|postype=qualificative|eagles=AQ0MSP\n";
		}
		else{
			$subOutLine .=  "$date\tFILL_IN\n";
		}
		
		push(@dateOutlines, $subOutLine);
		$actualWordCount++;
	}
	return \@dateOutlines;
}

sub eaglesToMorph{
	my $eaglesTag = $_[0];
	my $morphstring ="";
	
	#adjectives
	#AQ0CS0	gen=c|num=s|postype=qualificative
	if($eaglesTag =~ /^A/){
		my $postype = "postype=qualificative" if($eaglesTag =~ /^AQ/);
		$postype = "postype=ordinal" if($eaglesTag =~ /^AO/);
		my $gender = substr($eaglesTag,3,1);
		my $number = substr($eaglesTag,4,1);
		$morphstring = "gen=".lc($gender)."|num=".lc($number)."|".$postype;
		
	}
	#determiners
	#DA0FP0	gen=f|num=p|postype=article
	#DP3CP0	gen=c|num=p|postype=possessive|person=3
	elsif($eaglesTag =~ /^D/){
		my $postype = "postype=article" if($eaglesTag =~ /^DA/);
		$postype = "postype=possessive" if($eaglesTag =~ /^DP/);
		$postype = "postype=demonstrative" if($eaglesTag =~ /^DD/);
		$postype = "postype=indefinite" if($eaglesTag =~ /^DI/);
		$postype = "postype=exclamative" if($eaglesTag =~ /^DE/);
		$postype = "postype=interrogative" if($eaglesTag =~ /^DT/);
		$postype = "postype=numeral" if($eaglesTag =~ /^DN/);
		
		my $person = substr($eaglesTag,2,1);
		my $gender = substr($eaglesTag,3,1);
		my $number = substr($eaglesTag,4,1);
		my $possessor = substr($eaglesTag,5,1);
		
		$morphstring = "gen=".lc($gender)."|num=".lc($number)."|".$postype;
		if($postype =~ /possessive/){
			$morphstring .="|person=".$person;
		}
		

	}
	# proper nouns
	elsif($eaglesTag =~ /^NP/){
		my $postype = "postype=proper";
		my $type = "ne=organization" if($eaglesTag =~ /O0.$/);
		$type = "ne=location" if($eaglesTag =~ /G0.$/);
		$type = "ne=person" if($eaglesTag =~ /SP.$/);
		$type = "ne=other" if($eaglesTag =~ /V0.$/);
		$morphstring = $postype."|".$type;
		
	}
	# common nouns
	elsif($eaglesTag =~ /^NC/){
		 #gen=f|num=s|postype=common
		 # note: no grade in ancora
		 my $postype = "postype=common";
		 my $gender = substr($eaglesTag,2,1);
		 my $number = substr($eaglesTag,3,1);
		 $morphstring = "gen=".lc($gender)."|num=".lc($number)."|".$postype;
	}
	
	
	# verbs
	#VMSI3S0 num=s|postype=main|person=3|mood=subjunctive|tense=imperfect
	elsif($eaglesTag =~ /^V/){
		my $postype = "postype=main" if($eaglesTag =~ /^VM/);
		$postype = "postype=semiauxiliary" if($eaglesTag =~ /^VS/);
		$postype = "postype=auxiliary" if($eaglesTag =~ /^VA/);
		
		my $mood = "mood=indicative" if($eaglesTag =~ /^V.I/);
		$mood = "mood=subjunctive" if($eaglesTag =~ /^V.S/);
		$mood = "mood=imperative" if($eaglesTag =~ /^V.M/);
		$mood = "mood=infinitive" if($eaglesTag =~ /^V.N/);
		$mood = "mood=gerund" if($eaglesTag =~ /^V.G/);
		$mood = "mood=participle" if($eaglesTag =~ /^V.P/);
		
		
		my $tense = "tense=future" if($eaglesTag =~ /^V..F/);
		$tense = "tense=present" if($eaglesTag =~ /^V..P/);
		$tense = "tense=imperfect" if($eaglesTag =~ /^V..I/);
		$tense = "tense=past" if($eaglesTag =~ /^V..S/);
		$tense = "tense=conditional" if($eaglesTag =~ /^V..C/);
		
		my $person = substr($eaglesTag,4,1);
		my $number = substr($eaglesTag,5,1);
		my $gender = substr($eaglesTag,6,1);
		
		# infinitives,gerunds: postype=main|mood=infinitive, VMG0000	postype=main|mood=gerund
		$morphstring = $postype."|".$mood if ($mood =~ /infinitive|gerund/);
		# participles: VMP00SF	gen=f|num=s|postype=main|mood=participle
		$morphstring = "gen=".lc($gender)."|num=".lc($number)."|".$postype."|".$mood if ($mood =~ /participle/);
		# imperatives: VSM03S0	num=s|postype=semiauxiliary|person=3|mood=imperative
		$morphstring = "num=".lc($number)."|".$postype."|person=".$person."|".$mood if ($mood =~ /imperative/);
		# subjunctives: VMSP3S0	num=s|postype=main|person=3|mood=subjunctive|tense=present
		# indicatives: VMIP3S0	num=s|postype=main|person=3|mood=indicative|tense=present
		$morphstring = "num=".lc($number)."|".$postype."|person=".$person."|".$mood."|".$tense if ($mood =~ /subjunctive|indicative/);
		
	}
	# pronouns
	elsif($eaglesTag =~ /^P/){
		my $postype = "postype=personal" if ($eaglesTag =~ /^PP/);
		$postype = "postype=demonstrative" if ($eaglesTag =~ /^PD/);
		$postype = "postype=possessive" if ($eaglesTag =~ /^PX/);
		$postype = "postype=indefinite" if ($eaglesTag =~ /^PI/);
		$postype = "postype=interrogative" if ($eaglesTag =~ /^PT/);
		$postype = "postype=relative" if ($eaglesTag =~ /^PR/);
		$postype = "postype=exclamative" if ($eaglesTag =~ /^PE/);
		
		my $person = substr($eaglesTag,2,1);
		my $gender = substr($eaglesTag,3,1);
		my $number = substr($eaglesTag,4,1);
		my $caseLetter = substr($eaglesTag,5,1);
		my $possessornum = substr($eaglesTag,6,1);
		my $politeness = substr($eaglesTag,7,1);
		
		my $case = "case=accusative" if ($caseLetter eq 'A');
		$case = "case=dative" if ($caseLetter eq 'D');
		$case = "case=nominative" if ($caseLetter eq 'N');
		$case = "case=olique" if ($caseLetter eq 'O');
		
		# personal pronouns: PP3MSA00	gen=m|num=s|postype=personal|person=3|case=accusative
		$morphstring = "gen=".lc($gender)."|num=".lc($number)."|".$postype."|person=".$person."|".$case if ($postype =~ /personal/);
		# demonstrative pronouns: PD0CS000	gen=c|num=s|postype=demonstrative
		# & indefinite: PI0MS000	gen=m|num=s|postype=indefinite
		# & interrogative: PT0CS000	gen=c|num=s|postype=interrogative
		# & relative: PR0CC000	gen=c|num=c|postype=relative
		# & exclamative: PE0CC000	gen=c|num=c|postype=exclamative
		$morphstring = "gen=".lc($gender)."|num=".lc($number)."|".$postype if ($postype =~ /demonstrative|indefinite|interrogative|relative|exclamative/);
		# possessive pronoun: 
		#PX1FS0P0	gen=f|num=s|postype=possessive|person=1|possessornum=p
		#PX3FS000	gen=f|num=s|postype=possessive|person=3
		$morphstring = "gen=".lc($gender)."|num=".lc($number)."|".$postype."|person=".$person."|possessornum=".lc($possessornum) if ($possessornum ne '0');
		$morphstring = "gen=".lc($gender)."|num=".lc($number)."|".$postype."|person=".$person if ($possessornum eq '0');
	
	}
	#conjunctions
	elsif($eaglesTag =~ /^C/){
		# CS	postype=subordinating
		# CC	postype=coordinating
		$morphstring = "postype=subordinating" if($eaglesTag eq 'CS');
		$morphstring = "postype=coordinating" if($eaglesTag eq 'CC');
	}
	#adverbs
	elsif($eaglesTag =~ /^R/){
		$morphstring = "postype=negative" if ($eaglesTag eq 'RN');
		$morphstring = "_" if ($eaglesTag eq 'RG');
	}
	#prepositions
	elsif($eaglesTag =~ /^S/){
		# SPS00	postype=preposition
		# SPCMS	gen=m|num=s|postype=preposition|contracted=yes
		$morphstring = "postype=preposition" if ($eaglesTag =~ /^SPS/);
		my $gender = substr($eaglesTag,2,1);
		my $number = substr($eaglesTag,3,1);
		
		$morphstring = "gen=".lc($gender)."|num=".lc($number)."|postype=preposition|contracted=yes" if ($eaglesTag =~ /^SPC/);
	}
	# punctuation
	elsif($eaglesTag =~ /^F/){
		# ¡	Faa, !	Fat: punct=exclamationmark
		$morphstring = "punct=exclamationmark" if ($eaglesTag =~ /^Fa(a|t)/);
		# ,	Fc: punct=comma
		$morphstring = "punct=comma" if ($eaglesTag eq 'Fc');
		# :	Fd: punct=colon
		$morphstring = "punct=colon" if ($eaglesTag eq 'Fd');
		# "	Fe: punct=quotation
		$morphstring = "punct=quotation" if ($eaglesTag eq 'Fe');
		# -	Fg: punct=hyphen
		$morphstring = "punct=hyphen" if ($eaglesTag eq 'Fg');
		# /	Fh: punct=slash
		$morphstring = "punct=slash" if ($eaglesTag eq 'Fh');
		# ¿	Fia, ?	Fit: punct=questionmark
		$morphstring = "punct=questionmark" if ($eaglesTag =~ /^Fi(a|t)/);
		# .	Fp: punct=period
		$morphstring = "punct=period" if ($eaglesTag eq 'Fp');
		# (	Fpa, )	Fpt: punct=bracket
		$morphstring = "punct=bracket" if ($eaglesTag eq 'Fpt' or $eaglesTag eq 'Fpa');
		#	...	Fs: punct=etc
		$morphstring = "punct=etc" if ($eaglesTag eq 'Fs');
		#	;	Fx: punct=semicolon
		$morphstring = "punct=semicolon" if ($eaglesTag eq 'Fx');
		#	_	Fz, +	Fz,=	Fz: punct=mathsign
		# doesnt occur: [	Fca, ]	Fct, {	Fla, }	Flt,«	Fra,»	Frc,%	Ft
		if($morphstring eq ""){
			$morphstring = '_';
		}
	}
	# interjections (no morph)
	elsif($eaglesTag eq 'I'){
		$morphstring = "_";
	}
	# numbers
	elsif($eaglesTag =~ /^Z/){
		# Z	ne=number
		# Zp	postype=percentage|ne=number
		# Zm	postype=currency|ne=number
		# Zu (unidad) and Zd (partitivo) 
		$morphstring = "ne=number" if ($eaglesTag eq 'Z');
		$morphstring = "postype=percentage|ne=number" if ($eaglesTag eq 'Zp');
		$morphstring = "postype=currency|ne=number" if ($eaglesTag eq 'Zm');
		$morphstring = "postype=partitive|ne=number" if ($eaglesTag eq 'Zd');
		$morphstring = "postype=unit|ne=number" if ($eaglesTag eq 'Zu');
	}
	# dates
	elsif($eaglesTag eq 'W'){
		$morphstring = "ne=date";
	}
	
	unless($morphstring eq '_' or $morphstring eq ""){
		# undefined number can be 0, N or C in eagles tag.. in morph always c
		$morphstring =~ s/num=(0|n)/num=c/g;
		$morphstring =~ s/gen=(0|n)/gen=c/g;
		$morphstring .= "|eagles=".$eaglesTag;
	}
	# check if every tag has a morphstring:
	if($morphstring eq ""){
		#print  "no morphstring assigned to tag: $eaglesTag\n";
		$morphstring = "_";
	}
	
	#print STDERR "heeere $eaglesTag, $morphstring\n";
	return $morphstring;
	
	
}

1;
