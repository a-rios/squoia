#!/usr/bin/perl


use strict;
use utf8;
use open ':utf8';
binmode STDERR, ':utf8';
use XML::LibXML;

my $num_args = $#ARGV + 1;
if ($num_args != 2) {
  print "\nUsage: perl wapitiTagged2xml.pl es.tagged book_id \n";
  exit;
  }

my $file = $ARGV[0];
my $bookID = $ARGV[1];
open (TAGGED, "<", $file)  or die "Can't open input file \"$file\": $!\n";
;

my $abs_sentence_count=1; # absolute sentence number, needed because of Intertext..
my $sentence_count = 1;
my $article_count = 0;
my $token_count =1;
my $sentence = XML::LibXML::Element->new( 's' ); # actual sentence
my $article; # actual chapter

my $dom = XML::LibXML->createDocument ('1.0', 'UTF-8');
my $book = $dom->createElementNS( "", "book" );
$book->setAttribute('id', $bookID);
$dom->setDocumentElement( $book );
my $allInOneChapter =1;

while(<TAGGED>){
	#if(/^([xiv]+\tuc)/){ # for chapters in gregorio..
	#if(/newChapter/){ # other texts
	if($allInOneChapter){ # texts with no chapter
		$article = XML::LibXML::Element->new( 'article' );
		$book->appendChild($article);
		#undef $article;
		$article_count++;
		$article->setAttribute('n',$article_count);
		my $tocEntry = XML::LibXML::Element->new( 'tocEntry' );
		my ($toc) = ($_ =~ /^([xiv]+)/);
		if($toc){
			$tocEntry->setAttribute('title', $toc);
			$article->appendChild($tocEntry);
		}
		$sentence_count=1;
		$allInOneChapter =0; # texts without chapters -> treat all as same chapter
		
	}
	# empty line = sentence end
	elsif(/^\s*$/ ){
		 # append prev sentence
	      $article->appendChild($sentence);
	      $sentence->setAttribute('n', $article_count."-".$sentence_count);
	      $sentence->setAttribute('Intertext_id', '1:'.$abs_sentence_count);
	      $sentence->setAttribute('lang', 'es');
	      # reset $sentence
	      undef $sentence;
	      $sentence = XML::LibXML::Element->new( 's' );
	      $sentence_count++;
	      $abs_sentence_count++;
	      $token_count=0;
	      
	}
	else{
		$token_count++;
		my ($lc_form, $case, @rest) = split('\t');
		my $pos = @rest[-1];
		chomp($pos);
		my $t = XML::LibXML::Element->new( 't' );
		$t->setAttribute('n', $article_count."-".$sentence_count."-".$token_count);
		#split dates
		if($pos eq 'W'){
			$token_count = &insertDateTokens($lc_form,$sentence,$token_count,$article_count."-".$sentence_count,$case);
		}
		else{
			$t->setAttribute('pos', $pos);
			my $lem = &getLemma($pos,$_);
			$t->setAttribute('lemma', $lem);
			my $form = ($case eq 'uc') ? ucfirst($lc_form) : $lc_form;
			$t->appendText($form);
			$sentence->appendChild($t);
		}
		
		# if end of file: append sentence
		if(eof){
		  $article->appendChild($sentence);
	      $sentence->setAttribute('n', $article_count."-".$sentence_count);
	      $sentence->setAttribute('lang', 'es');
		}
		
	}
}

close(TAGGED);
my $docstring = $dom->toString(3);
print STDOUT $docstring;


sub getLemma{
	my $tag = $_[0];
	my $line = $_[1];
	my @rows = split('\t',$line);
	my @indexes = grep { $rows[$_] eq $tag } 0..18;
	my $lemma;
	
	# if exactly one lemma associated with this tag, print it (at index-1 in rows)
	if(scalar(@indexes) == 1){
		   #print $rows[@indexes[0]-1]."\t";
		   $lemma = $rows[@indexes[0]-1];
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
					$lemmastring .= "##".$lem;
					#print "/".$lem."\t";
					 
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
		    $lemma = $lemmastring;
	 }
	 # if no index -> wapiti assigned a tag that wasn't suggested by freeling -> number or proper name, should only have one lemma
	 # -> @rows[4] should be ZZZ, if not: don't know which lemma...
	 else{
		   			if(@rows[4] eq 'ZZZ'){
		    			#print "@rows[2]\t";
		    			$lemma = "@rows[2]\t";
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
				    		$lemma = $rows[@indexes[0]-1];
				    	}
				    	elsif(scalar(@indexes)>1)
				    	{
				    		# if more than one lemma associated with this tag: write lemma1/lemma2 (but check if they're the same!)
		    				my $printedLems = '';
		    				my $lemmastring='';
				    		foreach my $i (@indexes)
				    		{  
				    			 #last lemma
								if($i == @indexes[-1])
								{
								    my $lem = @rows[$i-1];
									$lemmastring .= "##".$lem;
									#print "/".$lem."\t";
									 
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
		    				$lemma = $lem;
		    				#$outLine .= "UNKNOWN!!\t";
		    			}
		    		}
		    	}
		return $lemma;
}



sub insertDateTokens{
	my $datestring = $_[0];
	my $sentence = $_[1];
	my $token_count = $_[2];
	my $sentence_id = $_[3];
	my $case = $_[4];
	my @dates = split('_', $datestring);
	
	for(my $i=0;$i<scalar(@dates);$i++) {
		my $date = @dates[$i];
		my $t;
		my $lem;
		my $form;
		$t = XML::LibXML::Element->new( 't' );
		$t->setAttribute('n', $sentence_id."-".$token_count);
		my $form = ($case eq 'uc' ) ? ucfirst($date) : $date;
		$t->appendText($form);
		if($date =~ /enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre|lunes|martes|miércoles|jueves|viernes|sábado|domingo|día|mes|año|siglo/)
		{	
			$t->setAttribute('pos', 'NCMS000');
			($lem) = ($date =~ /(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre|lunes|martes|miércoles|jueves|viernes|sábado|domingo|día|mes|año|siglo)/ );
			if($lem){
				$t->setAttribute('lemma', $lem);
			}
		}
		elsif($date =~ /^de$|^a$/){
			$t->setAttribute('pos', 'SPS00');
			$t->setAttribute('lemma', $date);
		}
		elsif($date eq 'del'){
			$t->setAttribute('pos', 'SPCMS');
			$t->setAttribute('lemma', $date);
		}
		elsif($date =~ /madrugada|mañana|tarde|noche/){
			$t->setAttribute('pos', 'NCFS000');
			$t->setAttribute('lemma', $date);
		}
		elsif($date =~ /^el$/){
			$t->setAttribute('pos', 'DA0MS0');
			$t->setAttribute('lemma', $date);
		}
		elsif($date =~ /^los$/){
			$t->setAttribute('pos', 'DA0MP0');
			$t->setAttribute('lemma', 'el');
		}
		elsif($date =~ /^la$/){
			$t->setAttribute('pos', 'DA0FS0');
			$t->setAttribute('lemma', 'el');
		}
		elsif($date =~ /^las$/){
			$t->setAttribute('pos', 'DA0FP0');
			$t->setAttribute('lemma', 'el');
		}
		elsif($date =~ /^\d+$|^[0-2]?\d:[0-5]\d$|^[xivXIV]+$|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|veinte|treinta|^(y|menos)$/){
			$t->setAttribute('lemma', $date);
			$t->setAttribute('pos', 'Z');
		}
		elsif($date =~ /pasado|próximo/){
			$t->setAttribute('lemma', $date);
			$t->setAttribute('pos', 'AQ0MS0');
		}
		# en los (años) cincuenta/ochenta..
		elsif($date =~ /veinte|treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa/){
			$t->setAttribute('lemma', $date);
			$t->setAttribute('pos', 'Z');
			#print STDERR $t->toString()."\n";
		}
		else{
			 die "could not convert date! $date \n";
		}
		$sentence->appendChild($t);
		$token_count++;
	}
	return $token_count;
}