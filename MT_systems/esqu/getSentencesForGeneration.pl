#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
#binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use strict;
#use warnings;
use XML::LibXML;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/../util.pl";

#read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

my @verbchunksWithConjunction = $dom->findnodes('descendant::CHUNK[(@type="grup-verb" or @type="coor-v") and @conj]');
foreach my $vchunk (@verbchunksWithConjunction)
{

 				# if there's an attribute conj: find first child node and insert conj as attribute there
 				# if no children: print conj before verb(s)
 				my $firstchild = &getFirstChild($vchunk);
 				if($firstchild)
 				{
 					$firstchild->setAttribute('conj', $vchunk->getAttribute('conj'));
 					#print STDERR "attribute set: ".$firstchild->getAttribute('conj')."\n";
 				}
 				else
 				{
 					print STDOUT $vchunk->getAttribute('conj')."\n";
 				}

}
foreach my $sentence  ( $dom->getElementsByTagName('SENTENCE'))
{	
	# consider linear sequence in sentence; 
 	my @chunks = $sentence->findnodes('descendant::CHUNK');
 	
 	my %chunkSequence =();
 	
 	foreach my $chunk (@chunks)
 	{
 		# note: 'ord' 
 		my $idref = $chunk->getAttribute('ord');
 		$chunkSequence{$idref}= $chunk;
 	}

 	#iterate through verb chunks in their original sequence
 	foreach my $idref (sort {$a<=>$b} (keys (%chunkSequence))) 
 	{
 		my $chunk = $chunkSequence{$idref};
 		#if this is a verb chunk, get lemma and verbmi directly from chunk, no need to process the nodes
 		if($chunk->exists('self::CHUNK[@type="grup-verb" or @type="coor-v"]'))
 		{
 			
 			# if there's a node (e.g. interrogative pronoun) in verb chunk or
 			#if wrong analysis-> there might be a node in the verbchunk that doesn't belong here, extract that node
 			my @spareNodes = $chunk->findnodes('child::NODE[starts-with(@smi,"V")]/descendant::NODE[not(starts-with(@smi, "V") or starts-with(@smi, "C") or starts-with(@smi,"PR") )]');
 			foreach my $sparenode (@spareNodes)
 			{
				&printNode($sparenode);
				print STDOUT "\n";
 			}
 			
 			# if verb unknown, lem aleady contains the source lemma, in this, strip the final -r (from the Spanish infinitive))
 			my $lemma = $chunk->getAttribute('lem');
 			$lemma =~ s/r$//;
 			my $verbmi = $chunk->getAttribute('verbmi');
 			#in case an auxiliary needs to be generated, get that too
 			my $lemma2 = $chunk->getAttribute('lem2');
 			my $verbmi2 = $chunk->getAttribute('verbmi2');
 			my $chunkmi = $chunk->getAttribute('chunkmi');
 			
 			print STDOUT "$lemma:$verbmi";
 			if($chunkmi ne ''){print $chunkmi;}
 			if($lemma2 && $verbmi2)
 			{
 				print STDOUT "\n$lemma2:$verbmi2";
 			}
 			print STDOUT "\n";
 		}
 		# if this is a noun chunk, but NOT a pronoun (note, pronouns have an attribute  verbmi that has been copied to their verb,
 		# pronouns are realized as suffixes: we don't need to process them here)
 		elsif($chunk->exists('self::CHUNK[@type="sn" or @type="coor-n"]') && !$chunk->hasAttribute('verbmi') && !$chunk->exists('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@spform'))
 		{	
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			# find the noun (should be only one per chunk), ignore definite articles (and indefinite articles?), and also possessive pronouns (those are realized as suffixes) TODO
 			my $noun = @{$chunk->findnodes('child::NODE[not(starts-with(@smi,"DA") and not(starts-with(@smi,"DP")))]')}[0];
 			&printNode($noun);
 			# print possessive suffix, if there is any
 			if($chunk->hasAttribute('poss'))
 			{
 				print STDOUT $chunk->getAttribute('poss');	
 			}
 			# print case, if there is any
 			if($chunk->exists('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@nouncase'))
 			{
 				print $chunk->findvalue('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@nouncase');
 			}
 			elsif($chunk->exists('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@case'))
 			{
 				print $chunk->findvalue('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@case');
 			}
 			elsif($chunk->hasAttribute('case'))
 			{
 				print $chunk->getAttribute('case');
 			}
 			
 			# print content of chunkmi, if present
 			print STDOUT $chunk->getAttribute('chunkmi')."\n";
 				 
 		}
 		# pp-chunks:
 		# if the chunk contains an attribute spform: this contains the whole pp, just print this
 		elsif($chunk->exists('self::CHUNK[@type="grup-sp" or @type="coor-sp"]/@spform') )
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			print STDOUT $chunk->getAttribute('spform')."\n";
 			
 		} 
 		elsif($chunk->exists('self::CHUNK[@type="grup-sp" or @type="coor-sp"]') && !$chunk->exists('child::CHUNK[@type="sn"]/@verbmi') && $chunk->exists('child::NODE/@postpos') && !$chunk->hasAttribute('case') )
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $postpos = @{$chunk->findnodes('child::NODE[starts-with(@smi,"SP")]')}[0];
 			
 			&printNode($postpos);
 			print STDOUT "\n";
 		}
 		#punctuation: print as is
 		elsif($chunk->exists('self::CHUNK[@type="F-term"]') )
 		{
 			my $pmark = $chunk->findvalue('child::NODE/@slem');
 			
 			print STDOUT "$pmark\n";
 		}
 		# adverbs: RN 'no' -> print only if without 'nada,nunca or jamás', in those cases -> no is already contained in the suffix -chu in the verb chunk
 		elsif($chunk->exists('self::CHUNK[@type="sadv" or @type="coor-sadv"]') && !($chunk->exists('ancestor::CHUNK[@type="grup-verb" or @type="coor-v"]/descendant::NODE[@slem="nada" or @slem="nunca" or @slem="jamás"]') && $chunk->exists('child::NODE[@smi="RN"]') ) )      
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $adverb = @{$chunk->findnodes('child::NODE[@smi="RG" or @smi="RN" ]')}[0];
 			&printNode($adverb);
 			# if this is 'mana' and negation has scope over verb (note that this is always the case, 
 			# because lexical negation (nada - mana imapas) is already handled in the lexicon)
 			if($adverb->getAttribute('smi') eq 'RN')
 			{
 				print STDOUT "+DirE#mana:Part+IndE";
 			}
 			print STDOUT "\n";
 		}
 		# adjectives: print as is
 		elsif($chunk->exists('self::CHUNK[@type="sa" or @type="coor-sa"]') )
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $adjective = @{$chunk->findnodes('child::NODE[starts-with(@smi,"A")]')}[0];
 			&printNode($adjective);
 			print STDOUT "\n";
 		}
 		# dates: print as is (only numbers are in a date-chunk)
 		elsif($chunk->exists('self::CHUNK[@type="date"]') )
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $date = @{$chunk->findnodes('child::NODE[@smi="W"]')}[0];
 			&printNode($date);
 			print STDOUT "\n";
 		}
 		# determiner (demonstrative, indefinite, interrogative or exclamative)
 		elsif($chunk->exists('self::CHUNK[@type="det"]') )
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $det = @{$chunk->findnodes('child::NODE')}[0];
 			&printNode($det);
 			print STDOUT "\n";
 		}
 	}
 	# emtpy line between sentences
 	print STDOUT "\n";
}

# print new xml to stdout
#my $docstring = $dom->toString;
#print STDOUT $docstring;

sub printNode{
	my $node = $_[0];
	
	# if Spanish word in dictionary, but no translation: take source lemma + mi
 	if($node->getAttribute('lem') eq 'unspecified')
 	{
 		print STDOUT  $node->getAttribute('slem').":".$node->getAttribute('mi');
 	}
 	# else: if this is a postposition:
 	elsif($node->getAttribute('smi') =~ /^SP/)
 	{
 		print STDOUT $node->getAttribute('postpos');
 	}
 	
 	# else if word could be translated
 	elsif($node->getAttribute('lem') ne 'unspecified' && $node->getAttribute('unknown') ne 'transfer')
 	{
 		my $mi = $node->getAttribute('mi');
 		my $preform = $node->getAttribute('preform');
 		my $postform = $node->getAttribute('postform');
 		my $firstform = $node->getAttribute('firstform');
 		my $lem =  $node->getAttribute('lem');
 		my $replace_mi =  $node->getAttribute('replace_mi');
 		my $add_mi = $node->getAttribute('add_mi');
 		
 		if($firstform ne '') {print STDOUT "$firstform\n";}
 		if($preform ne '')
 		{
 			my @pfsWithEmtpyFields = split('#',$preform);
 			# remove empty fields resulted from split
 			my @pfs = grep {$_} @pfsWithEmtpyFields; 
 			for my $preword (@pfs){print STDOUT "$preword\n";}
 		}
 		# print lemma
 		print STDOUT $lem;
 		# print morphology:
 		if($replace_mi ne ''){print STDOUT ":$replace_mi";}
 		else
 		{
 			my ($root,$morph) = $mi =~ m/(NRootNUM|NRoot|Noun|VRoot|Copula|Part|PrnDem|PrnInterr|PrnPers)(.*)/ ;
 			#print STDERR "root: $root, morph: $morph\n";
 			#my @lems = split( '_',$node->getAttribute('lem'));
 		
 			if($add_mi ne '')
 			{ 
 			 	my ($correctroot,$addmorph) = $add_mi =~ m/(NRootNUM|NRoot|Noun|VRoot|Copula|Part|PrnDem|PrnInterr|PrnPers)(.*)/  ;
 				#print STDERR "add_mi: $add_mi, $correctroot,$addmorph"; 
 				if($correctroot ne '' )
 				{
 					print STDOUT ":$correctroot$addmorph$morph";
 				}
 				else
 				{
 					print STDOUT ":$root$addmorph$morph";
 				}
 			}
 			else
 			{
 				print STDOUT ":$root$morph";
 			}
 		}
 		if($postform ne '')
 		{
 			my @pfsWithEmtpyFields = split('#',$postform);
 			# remove empty fields resulted from split
 			my @pfs = grep {$_} @pfsWithEmtpyFields; 
 			for my $postword (@pfs){print STDOUT "\n$postword";}
 		}
 	}
 		
 		#print STDOUT $node->getAttribute('lem').":".$node->getAttribute('mi')."\n";
 	# else if word not contained in dictionary -> no lemma, no morphology
 	# -> take source lemma and try to generate morphological tags from source tag
 	else
 	{
 		#print STDOUT  $node->getAttribute('slem').": ";
 		&mapEaglesTagToQuechuaMorph($node);
 		#map to morf
 	}
 	
}



sub mapEaglesTagToQuechuaMorph{
	my $node = $_[0];
	my $eaglesTag = $node->getAttribute('smi');
	my $slem = $node->getAttribute('slem');
	
	#adjectives
	if($eaglesTag =~ /^A/)
	{
		my $type = substr($eaglesTag,1,1);
		my $grade = substr($eaglesTag,2,1);
		#my $number = substr($eaglesTag,4,1);
		
		# ordinal
		if($type eq 'O')
		{
			print  STDOUT "$slem ñiqin\n";
		}
		else
		{
			if($grade =~ /A|S/)
			{
					print  STDOUT "aswan $slem";
			}
			# diminutive
			else
			{
				print  STDOUT "$slem+Dim";
			}
		}
	}
	elsif($eaglesTag eq 'RG')
	{
		print  STDOUT "$slem:NRoot+Acc";
	}
#	# determiners, should all be in lexicon, TODO: check if complete
#	elsif($eaglesTag =~ /^D/)
#	{
#		my $type = substr($eaglesTag,1,1);
#		my $person = substr($eaglesTag,2,1);
#		my $number = substr($eaglesTag,4,1);
#		
#	}
	elsif($eaglesTag =~ /^N/)
	{
		my $type = substr($eaglesTag,1,1);
		my $number = substr($eaglesTag,3,1);
		my $grade = substr($eaglesTag,6,1);
		
		# note that proper names can contain several words in slem 'Juan_Perez', or 'Universidad_Nacional'
		#person
		if($eaglesTag =~ /SP/)
		{
			my (@words) = split('_',$slem);
			for(my $i=0;$i<scalar(@words)-1;$i++)
			{
				print STDOUT @words[$i]."\n";
			}
			print STDOUT @words[-1];
		}
		# other proper name
		elsif($type eq 'P')
		{
			my (@words) = split('_',$slem);
			for(my $i=0;$i<scalar(@words)-1;$i++)
			{
				print STDOUT @words[$i]."\n";
			}
			print STDOUT @words[-1]."\n";
			print STDOUT "ni:VRoot+Perf";
			if( $number eq 'P')
			{
				print STDOUT "+Pl";
			}
		}
		#common noun
		else
		{
			print STDOUT "$slem";
			if($grade eq 'A')
			{
				print STDOUT "+Aug";
			}
			if($grade eq 'D')
			{
				print STDOUT "+Dim";
			}
			if($number eq 'P')
			{
				print STDOUT "+Pl";
			}
		}
		print STDOUT $node->findvalue('parent::CHUNK[@type="sn" or @type="coor-n"]/@poss');
		print STDOUT $node->findvalue('parent::CHUNK[@type="sn" or @type="coor-n"]/@nouncase');
	}
	# note, this shouldn't be necessary under normal cirumstances, as all verb information is copied to the verb chunk
#	elsif($eaglesTag =~ /^V/)
#	{
#		my $mode = substr($eaglesTag,2,1);
#		my $tense = substr($eaglesTag,3,1);
#		my $person = substr($eaglesTag,4,2);
#	}
	# pronouns, should all be in the lexicon, TODO: check if complete
	#	elsif($eaglesTag =~ /^P/)
	
	#conjunctions, interjections,prepositions,dates
	elsif($eaglesTag =~ /^C|I|S|W/)
	{
		print STDOUT "$slem";
	}
}

sub getFirstChild{
	my $chunk = $_[0];
	
	if(!$chunk){return;}
	else
	{
		# consider linear sequence in sentence; 
 		my @childchunks = $chunk->findnodes('child::CHUNK');
 	
 		my %chunkSequence =();
 	
 		foreach my $child (@childchunks)
 		{
 			# note: 'ord' 
 			my $idref = $child->getAttribute('ord');
 			$chunkSequence{$idref}= $child;
 		}

 		#iterate through child chunks in their original sequence
 		my @sortedChildren = sort {$a<=>$b} (keys (%chunkSequence));
 		return $chunkSequence{@sortedChildren[0]};

 		
	}
}
