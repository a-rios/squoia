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


# use slots 1-20 for verbs
# 21 for nominalizers
# 22- for nominal morphology
# verbalizations are handled directly in the lexicon, no need to specify that here
my %mapTagsToSlots = (
	'+Perdur'		=> 1,
	'+Rem'			=> 1,
	'+Desesp'		=> 1,
	'+Int'			=> 1,
	'+Stat_Multi'	=> 1,
	'+Multi'		=> 1,
	'+Intrup'		=> 1,
	'+VCont'		=> 1,
	'+Vdim'			=> 1,
	'+Autotrs'		=> 1,
	'+MRep'			=> 1,
	'+Des'			=> 1,
	'+Ass'			=> 2,
	'+Rep'			=> 2,
	'+Aff'			=> 3,
	'+Inch'			=> 3,
	'+Rptn'			=> 4,
	'+Caus'			=> 5,
	'+Rzpr'			=> 6,
	'+Rptn'			=> 7,
	'+Rflx'			=> 8,
	'+Iprs'			=> 9,
	'+Cis'			=> 10,
	'+1.Sg.Obj'			=> 11,
	'+1.Obj'			=> 11,
	'+1.Pl.Incl.Obj'	=> 11,
	'+1.Pl.Excl.Obj'	=> 11,
	'+2.Sg.Obj'			=> 11,
	'+2.Pl.Obj'			=> 11,
	'+2.Obj'			=> 11,
	'+Prog'				=> 12,
	# here come the nominalizing Suffixes, if any
	'+Perf'		=> 20,
	'+SS'		=> 20,
	'+DS'		=> 20,
	'+SSsim'	=> 20,
	'+Inf'		=> 20,
	'+Char'		=> 20,
	'+Obl'		=> 20,
	'+Ag'		=> 20,
	'+Posi'		=> 20,
	# finite verb suffixes
	'+IPst'				=> 21,
	'+NPst'				=> 21,
	'+1.Sg.Subj'				=> 22,
	'+2.Sg.Subj'				=> 22,
	'+3.Sg.Subj'				=> 22,
	'+1.Pl.Incl.Subj'			=> 22,
	'+1.Pl.Excl.Subj'			=> 22,
	'+2.Pl.Subj'				=> 22,
	'+3.Pl.Subj'				=> 22,
	'+1.Sg.Subj.Fut'			=> 22,
	'+2.Sg.Subj.Fut'			=> 22,
	'+3.Sg.Subj.Fut'			=> 22,
	'+1.Pl.Incl.Subj.Fut'		=> 22,
	'+1.Pl.Excl.Subj.Fut'		=> 22,
	'+2.Pl.Subj.Fut'			=> 22,
	'+3.Pl.Subj.Fut'			=> 22,	
	'+1.Sg.Subj.Pot'			=> 22,
	'+2.Sg.Subj.Pot'			=> 22,
	'+3.Sg.Subj.Pot'			=> 22,
	'+1.Pl.Incl.Subj.Pot'		=> 22,
	'+1.Pl.Excl.Subj.Pot'		=> 22,
	'+2.Pl.Subj.Pot'			=> 22,
	'+3.Pl.Subj.Pot'			=> 22,	
	'+2.Sg.Subj.Imp'			=> 22,
	'+3.Sg.Subj.Imp'			=> 22,
	'+1.Pl.Incl.Subj.Imp'		=> 22,
	'+2.Pl.Subj.Imp'			=> 22,
	'+3.Pl.Subj.Imp'			=> 22,	
	'+3.Pl.Subj.Hab'			=> 22,
	'+Fut'						=> 23,
	'+Pot'						=> 23,
	# nominal suffixes
	'+Aug'				=> 30,
	'+Dim'				=> 30,
	'+MPoss'			=> 31,
	'+Abss'				=> 31,
	'+Poss'				=> 32,
	'+1.Sg.Poss'		=> 33,
	'+2.Sg.Poss'		=> 33,
	'+3.Sg.Poss'		=> 33,
	'+1.Pl.Incl.Poss'	=> 33,
	'+1.Pl.Excl.Poss'	=> 33,
	'+2.Pl.Poss'		=> 33,
	'+3.Pl.Poss'		=> 33,
	'+Pl'				=> 34,
	'+Iclsv'			=> 35,
	'+Intsoc'			=> 35,
	'+Distr'			=> 35,
	'+Aprx'				=> 35,
	'+Acc'				=> 36,
	'+Dat'				=> 36,
	'+Abl'				=> 36,
	'+Gen'				=> 36,
	'+Proloc'			=> 36,
	'+Ben'				=> 36,
	'+Loc'				=> 36,
	'+Term'				=> 37,
	'+Kaus'				=> 38,
	'+Soc'				=> 38,
	'+Instr'			=> 39,
	# independent suffixes
	'+Abtmp'			=> 40,
	'+Sim'				=> 41,
	'+Def'				=> 42,
	'+Cont'			=> 43,
	'+Disc'			=> 43,
	'+Add'			=> 44,
	'+Intr'			=> 45,
	'+Neg'			=> 46,
	'+DirE'			=> 47,
	'+IndE'			=> 47,
	'+Asmp'			=> 47,
	'+Top'			=> 47,
	'+QTop'			=> 47,
	'+Dub'			=> 47,
	'+Res'			=> 48,
	'+IndEemph'			=> 48,
	'+Asmpemph'			=> 48,
	'+DirEemph'			=> 48,
	'+Emph'				=> 48
	);


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
 					$vchunk->setAttribute('conjHere','yes')."\n";
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
 		if($chunk->exists('self::CHUNK[@type="grup-verb" or @type="coor-v"]') && !$chunk->hasAttribute('delete') )
 		{
 			# if there's a conjunction to be inserted and this verb chunk has no children chunks, print conjunction first
 			if($chunk->hasAttribute('conjHere'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			
 			# if there's a node (e.g. interrogative pronoun) in verb chunk or
 			#if wrong analysis-> there might be a node in the verbchunk that doesn't belong here, extract that node
 			my @spareNodes = $chunk->findnodes('child::NODE[starts-with(@smi,"V")]/descendant::NODE[not(starts-with(@smi, "V") or starts-with(@smi, "C") or starts-with(@smi,"PR") or starts-with(@smi,"S"))]');
 			foreach my $sparenode (@spareNodes)
 			{
				&printNode($sparenode,$chunk);
				print STDOUT "\n";
 			}
 			
 			my $verbmi = $chunk->getAttribute('verbmi');
 			my $addverbmi = $chunk->getAttribute('addverbmi');
 			$verbmi = $verbmi.$addverbmi;
 			# if verb unknown, lem aleady contains the source lemma, in this, strip the final -r (from the Spanish infinitive))
 			my $lemma = $chunk->getAttribute('lem');
 			if($chunk->exists('child::NODE[@lem="unspecified"]'))
 			{
 				$lemma =~ s/r$//;
 				if(!$chunk->hasAttribute('verbmi'))
 				{
 					# if this a participle without finite verb, use -sqa form
 					if($chunk->exists('child::NODE[starts-with(@smi,"VMP")]'))
 					{ 
 						$verbmi="VRoot+Perf";
 					}
 					# if this a gerund without finite verb, use -spa form
 					elsif($chunk->exists('child::NODE[starts-with(@smi,"VMG")]'))
 					{
 						$verbmi="VRoot+SS";
 					}
 				}
 			}
 			#in case an auxiliary needs to be generated, get that too
 			my $lemma2 = $chunk->getAttribute('lem2');
 			my $verbmi2 = $chunk->getAttribute('verbmi2');
 			# preverbs: quotation, nispa nin
 			my $lemma1 = $chunk->getAttribute('lem1');
 			my $verbmi1 = $chunk->getAttribute('verbmi1');
 			my $auxlem = $chunk->getAttribute('auxlem');
 			my $auxverbmi = $chunk->getAttribute('auxverbmi');
 			my $chunkmi = $chunk->getAttribute('chunkmi');
 			my ($verbprs) = ($verbmi =~ m/(\+[123]\.[PS][lg](\.Incl|\.Excl)?\.Subj)/ );
 			my ($subjprs,$inclExcl) = ($verbmi =~ m/\+([123]\.[PS][lg])(\.Incl|\.Excl)?\.Subj/ );
 			my ($objprs) = ($verbmi =~ m/\+([12]\.[PS][lg])(\.Incl|\.Excl)?\.Obj/ );
 			my ($subjprsPoss,$inclExclPoss) = ($verbmi =~ m/\+([123]\.[PS][lg])(\.Incl|\.Excl)?\.Poss/ );
 			#print STDERR "verbmi: $verbmi .......... poss subj: $subjprsPoss\n";
 			#print STDERR "verbmi: $verbmi .......... subj obj: $subjprs, $objprs\n";
 			
 			# nispa
 			if($lemma1 && $verbmi1)
 			{
 				print STDOUT "$lemma1:$verbmi1\n";
 			}
 			# check if subj and obj are same person, if so, change obj to reflexive
 			if($subjprs ne '' && $verbmi =~ $subjprs."Obj")
 			{
 				#my ($oldObj) = ($verbmi =~ m/\Q$subjprs\E()/ );
 				$verbmi =~ s/\Q$subjprs\E($inclExcl)?\.Obj/Rflx/g;
 				#print STDERR "replaced $subjprs: $verbmi\n";
 			}
 			# if this is a nominal (perfect or obligative) form, check if object and possessive suffix are same person
 			# -> if so, replace object suffix with reflexive
 			if($chunk->getAttribute('verbform') =~ /perfect|obligative/ && $subjprsPoss ne '' && $verbmi =~ $subjprs."Obj")
 			{
 				#my ($oldObj) = ($verbmi =~ m/\Q$subjprs\E()/ );
 				$verbmi =~ s/\Q$subjprsPoss\E($inclExcl)?\.Obj/Rflx/g;
 				#print STDERR "replaced $subjprs: $verbmi\n";
 			}
 			# if there was a new subject inserted during transfer, change that (e.g. in direct speech)
 			if($chunk->getAttribute('verbprs') ne '')
 			{
 				my $newverbprs = $chunk->getAttribute('verbprs');
 				
 				#print STDERR "old verb prs: $verbprs\n";
 				$verbmi =~ s/\Q$verbprs\E/$newverbprs/g;
 			}
 			# if original subject is an object in Quechua, change that (e.g. tengo hambre -> yarqanaya-wa-n)
 			# and introduce a 3rd person subject marker to the verb
 			if($chunk->hasAttribute('subjToObj'))
 			{
 				$verbmi =~ s/\Q$verbprs\E/\+3.Sg.Subj/g;
 				if($subjprs =~ /1|2/)
 				{
 					$verbmi = $verbmi."+".$subjprs.$inclExcl.".Obj";
 					#print STDERR "new verbmi: $verbmi\n";
 				}
 			}
 			# if verbmi empty but node.mi=infinitive, add VRoot+Inf
 			if($verbmi eq '' && $chunk->exists('child::NODE[@mi="infinitive"]'))
 				{
 					$verbmi=$verbmi."+Inf";
 				}
 			# if this is a nominal verb chunk with a case suffix
 			if( $chunk->hasAttribute('case'))
 				{
 					$verbmi=$verbmi.$chunk->getAttribute('case');
 				}
 			# clean up and adjust morphology tags
 			# if this is the last verb that needs to be generated in this chunk, insert chunkmi
 			if($lemma2 eq '' && $auxlem eq '' && $verbmi ne '')
 			{ 
 				my $sortedVerbmi = &adjustMorph($verbmi.$chunkmi,\%mapTagsToSlots);
 				print STDOUT "$lemma:$sortedVerbmi\n";
 			}
 			else
 			{
 				my $sortedVerbmi = &adjustMorph($verbmi,\%mapTagsToSlots);
 				print STDOUT "$lemma:$sortedVerbmi";
 				
 				if($lemma2 && $verbmi2)
 				{
 					print STDOUT "\n$lemma2:".&adjustMorph($verbmi2,\%mapTagsToSlots);
 				}
 				if($auxlem && $auxverbmi)
 				{
 					print STDOUT "\n$auxlem:".&adjustMorph($auxverbmi,\%mapTagsToSlots);
 				}
 				if($chunkmi ne ''){print STDOUT &adjustMorph($chunkmi,\%mapTagsToSlots);}
 				print STDOUT "\n";
 			}
 		}
 		# if this is a noun chunk, but NOT a pronoun (note, pronouns have an attribute  verbmi that has been copied to their verb,
 		# pronouns are realized as suffixes: we don't need to process them here)
 		elsif($chunk->exists('self::CHUNK[@type="sn" or @type="coor-n"]') && !$chunk->hasAttribute('verbmi') && !$chunk->exists('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@spform') && !$chunk->hasAttribute('delete') )
 		{	
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			# find the noun (should be only one per chunk), ignore definite articles (and indefinite articles?), and also possessive pronouns (those are realized as suffixes) TODO
 			my $noun = @{$chunk->findnodes('child::NODE[not(starts-with(@smi,"DA") and not(starts-with(@smi,"DP")))]')}[0];
 			&printNode($noun,$chunk);
 			print STDOUT "\n";	 
 		}
 		# pp-chunks:
 		# if the chunk contains an attribute spform: this contains the whole pp, just print this
 		elsif($chunk->exists('self::CHUNK[@type="grup-sp" or @type="coor-sp"]/@spform') && !$chunk->hasAttribute('delete') )
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			print STDOUT $chunk->getAttribute('spform')."\n";
 			
 		} 
 		elsif($chunk->exists('self::CHUNK[@type="grup-sp" or @type="coor-sp"]') && !$chunk->exists('child::CHUNK[@type="sn"]/@verbmi') && $chunk->exists('child::NODE/@postpos') && !$chunk->hasAttribute('case') && !$chunk->hasAttribute('delete')  )
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $postpos = @{$chunk->findnodes('child::NODE[starts-with(@smi,"SP")]')}[0];
 			
 			&printNode($postpos,$chunk);
 			print STDOUT "\n";
 		}
 		#punctuation: print as is
 		elsif($chunk->exists('self::CHUNK[@type="F-term"]') && $chunk->getAttribute('delete') ne 'yes'  )
 		{
 			# print mi with the punctuation ->  after morphological generation
 			# -> when printing out sentences, it's useful to know whether to attach punctuation to preceding or following word!!
 			my $pmark = $chunk->findvalue('child::NODE/@slem');
 			my $pmi = $chunk->findvalue('child::NODE/@smi');
 			
 			print STDOUT "$pmark-PUNC-$pmi\n";
 		}
 		# adverbs: RN 'no' -> print only if without 'nada,nunca or jamás', in those cases -> no is already contained in the suffix -chu in the verb chunk
 		elsif($chunk->exists('self::CHUNK[@type="sadv" or @type="coor-sadv"]') && !($chunk->exists('ancestor::CHUNK[@type="grup-verb" or @type="coor-v"]/descendant::NODE[@slem="nada" or @slem="nunca" or @slem="jamás"]') && $chunk->exists('child::NODE[@smi="RN"]') ) && !$chunk->hasAttribute('delete') )      
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $adverb = @{$chunk->findnodes('child::NODE[@smi="RG" or @smi="RN" ]')}[0];
 			&printNode($adverb,$chunk);
 			print STDOUT "\n";
 		}
 		# adjectives: print as is
 		elsif($chunk->exists('self::CHUNK[@type="sa" or @type="coor-sa"]') && !$chunk->hasAttribute('delete'))
 		{
 			
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $adjective = @{$chunk->findnodes('child::NODE[starts-with(@smi,"A")]')}[0];
 			&printNode($adjective,$chunk);
 			print STDOUT "\n";
 		}
 		# dates: print as is (only numbers are in a date-chunk)
 		elsif($chunk->exists('self::CHUNK[@type="date"]') && !$chunk->hasAttribute('delete') )
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $date = @{$chunk->findnodes('child::NODE[@smi="W"]')}[0];
 			&printNode($date,$chunk);
 			print STDOUT "\n";
 		}
 		# determiner (demonstrative, indefinite, interrogative or exclamative)
 		# TODO: print huk or not? (atm, not) huk is not really an indefinite article like Spanish 'un/a' (huk is atm only promoted to chunk before 'día')
 		elsif($chunk->exists('self::CHUNK[@type="det"]') && !$chunk->hasAttribute('delete') )
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $det = @{$chunk->findnodes('child::NODE')}[0];
 			&printNode($det,$chunk);
 			print STDOUT "\n";
 		}
 		# interjections: print as is
 		elsif($chunk->exists('self::CHUNK[@type="interjec"]') && !$chunk->hasAttribute('delete'))
 		{
 			# if there's a conjunction to be inserted and this is the first node in the clause
 			if($chunk->hasAttribute('conj'))
 			{
 				print STDOUT $chunk->getAttribute('conj')."\n";
 			}
 			my $interjec = @{$chunk->findnodes('child::NODE')}[0];
 			&printNode($interjec,$chunk);
 			print STDOUT "\n";
 		}
 	}
 	# emtpy line between sentences
 	print STDOUT "#EOS\n";
}

# print new xml to stdout
#my $docstring = $dom->toString;
#print STDOUT $docstring;


sub printNode{
	my $node = $_[0];
	my $chunk = $_[1];
	
	my $nodeString='';
	my $lemma;
	
	# if Spanish word in dictionary, but no translation: take source lemma + mi
 	if($node->getAttribute('lem') eq 'unspecified')
 	{
 		#print STDOUT  $node->getAttribute('slem').":".$node->getAttribute('mi');
 		$lemma = $node->getAttribute('slem');
 		$nodeString = $node->getAttribute('mi');
 		$nodeString = $nodeString.&getMorphFromChunk($node,$chunk);
 		print STDOUT "$lemma:".&adjustMorph($nodeString,\%mapTagsToSlots) ;
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
 		$lemma =  $node->getAttribute('lem');
 		my $replace_mi =  $node->getAttribute('replace_mi');
 		my $add_mi = $node->getAttribute('add_mi');
 		
 		# preforms and postforms are full forms, don't need to be generated -> print them directly to STDOUT
 		if($firstform ne '') {print STDOUT "$firstform\n";}
 		if($preform ne '')
 		{
 			my @pfsWithEmtpyFields = split('#',$preform);
 			# remove empty fields resulted from split
 			my @pfs = grep {$_} @pfsWithEmtpyFields; 
 			for my $preword (@pfs){print STDOUT "$preword\n";}
 		}

 		# retrieve morphology:
 		if($replace_mi ne '')
 		{
 			#print STDOUT ":$replace_mi";
 			$nodeString = $nodeString."$replace_mi";
 		}
 		else
 		{ 
 			my ($root,$morph) = $mi =~ m/(NRootNUM|NRoot|Noun|VRoot|Verb|Copula|Part|PrnDem|PrnInterr|PrnPers)?(.*)/ ;
 			#print STDERR "root: $root, morph: $morph\n";
 		
 			if($add_mi ne '')
 			{ 
 			 	my ($correctroot,$addmorph) = ($add_mi =~ m/(NRootNUM|NRoot|Noun|VRoot|Verb|Copula|Part|PrnDem|PrnInterr|PrnPers)?(.*)/ ) ;
 				#print STDERR "add_mi: $add_mi,....$add_morph\n"; 
 				if($correctroot ne '' )
 				{
 					#print STDOUT ":$correctroot$addmorph$morph";
 					$nodeString = $nodeString."$correctroot$addmorph$morph";
 				}
 				else
 				{
 					#print STDOUT ":$root$addmorph$morph";
 					$nodeString = $nodeString."$root$addmorph$morph";
 				}
 			}
 			else
 			{
 				#print STDOUT ":$root$morph";
 				$nodeString = $nodeString."$root$morph";
 			}
 		}
 		$nodeString = $nodeString.&getMorphFromChunk($node,$chunk);
 		$nodeString = &deleteUnusedTags($nodeString,$chunk);
 		#print STDERR "node string: $nodeString\n";
 		# clean up and adjust morphology tags
 		if($postform eq ''){
 			print STDOUT "$lemma:".&adjustMorph($nodeString,\%mapTagsToSlots);
 		}
 		else
 		{
 			print STDOUT "$lemma\n";
 			my @pfsWithEmtpyFields = split('#',$postform);
 			# remove empty fields resulted from split
 			my @pfs = grep {$_} @pfsWithEmtpyFields; 
 			foreach my $postword (@pfs){
 				if(!$postword == @pfs[-1]){
 					print STDOUT "$postword\n";
 					}
 				# if this is the last postword, attach morphology!
 				else{
 					print STDOUT "$postword:".&adjustMorph($nodeString,\%mapTagsToSlots);
 				}
 			}
 		}
 	}
 		
 	# else if word not contained in dictionary -> no lemma, no morphology
 	# -> take source lemma and try to generate morphological tags from source tag
 	else
 	{
 		$nodeString = $nodeString.&mapEaglesTagToQuechuaMorph($node,$chunk);
 		my ($lem, $morph) = split(':', $nodeString);
 		$nodeString = &adjustMorph($morph,\%mapTagsToSlots);
 		print STDOUT "$lem:".$nodeString;
 	}
 	
}

sub deleteUnusedTags{
	my $morphString = $_[0];
	my $chunk = $_[1];
	my $deleteMorph = $chunk->getAttribute('deleteMorph');
	my @morphsToDelete = split(',',$deleteMorph);
	foreach my $del (@morphsToDelete)
	{$morphString =~ s/\Q$del\E//;}
	return $morphString;
}

sub getMorphFromChunk{
	my $node = $_[0];
	my $chunk = $_[1];
	my $morphString = '';
		# get morphology information from chunk resulted from transfer, if any:
 		# if sn chunk
 		if($chunk->getAttribute('type') =~ /sn|coor-n/)
 		{ 
 			# print possessive suffix, if there is any
 			if($chunk->hasAttribute('poss'))
 			{
 				#print STDOUT $chunk->getAttribute('poss');	
 				$morphString = $morphString.$chunk->getAttribute('poss');
 			}
 			# print case, if there is any
 			if($chunk->exists('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@nouncase'))
 			{
 				#print $chunk->findvalue('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@nouncase');
 				$morphString = $morphString.$chunk->findvalue('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@nouncase');
 			}
 			elsif($chunk->exists('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@case') && $chunk->findvalue('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@case') ne 'none')
 			{
	 			#print $chunk->findvalue('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@case');
	 			$morphString = $morphString.$chunk->findvalue('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/@case');
	 		}
 			elsif($chunk->hasAttribute('case') && $chunk->getAttribute('case') ne 'none' )
 			{
 				#print $chunk->getAttribute('case');
 				$morphString = $morphString.$chunk->getAttribute('case');
 			}
 		}
 		# if this is 'mana' and negation has scope over verb (note that this is always the case, 
 		# because lexical negation (nada - mana imapas) is already handled in the lexicon)
 		elsif($node->getAttribute('smi') eq 'RN')
 		{
 			#print STDOUT "+DirE#mana:Part+IndE";
 			#$morphString = $morphString."+DirE#mana:Part+IndE";
 			$morphString = $morphString."+DirE";
 		}
 		# if this is a 'det' chunk: as this node has been created AFTER intrachunk movement: check if function is cd or ci
 		# and add case suffix if necessary
 		elsif($chunk->getAttribute('type') eq 'det')
 		{
 			if($chunk->getAttribute('si') =~ /cd/)
 			{
 				#print STDOUT "+Acc";
 				$morphString = $morphString."+Acc";
 			}
 			elsif($chunk->getAttribute('si') eq 'ci')
 			{
 				#print STDOUT "+Dat";
 				$morphString = $morphString."+Dat";
 			}
 		}
 		# print content of chunkmi, if present
 		#print STDOUT $chunk->getAttribute('chunkmi');
 		$morphString = $morphString.$chunk->getAttribute('chunkmi');
 		return $morphString;	 
}	

sub mapEaglesTagToQuechuaMorph{
	my $node = $_[0];
	my $chunk = $_[1];
	my $eaglesTag = $node->getAttribute('smi');
	my $slem = $node->getAttribute('slem');
	my $sform = $node->getAttribute('sform');
	my $EagleMorphs = '';
	
	#adjectives
	if($eaglesTag =~ /^A/)
	{
		my $type = substr($eaglesTag,1,1);
		my $grade = substr($eaglesTag,2,1);
		#my $number = substr($eaglesTag,4,1);
		
		# ordinal
		if($type eq 'O')
		{
			print  STDOUT "$slem\nñiqin\n";
		}
		else
		{
			if($grade =~ /A|S/)
			{
					print  STDOUT "aswan\n$slem";
			}
			# diminutive
			elsif($grade =~ /D/)
			{
				print  STDOUT "$slem+Dim";
			}
			else
			{
				print  STDOUT "$slem";
			}
		}
	}
	elsif($eaglesTag eq 'RG')
	{
		#print  STDOUT "$slem";
		$EagleMorphs = "$slem:";
		$EagleMorphs = $EagleMorphs.&getMorphFromChunk($node,$chunk);
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
			#print STDOUT @words[-1];
			$EagleMorphs = $EagleMorphs.@words[-1].":";
		}
		# other proper name
		elsif($type eq 'P')
		{
			# use sform instead of slem for proper nouns to keep original casing!
			my (@words) = split('_',$sform);
			for(my $i=0;$i<scalar(@words)-1;$i++)
			{
				print STDOUT @words[$i]."\n";
			}
			print STDOUT @words[-1]."\n";
			#print STDOUT "ni:VRoot+Perf";
			$EagleMorphs = $EagleMorphs."ni:VRoot+Perf";
			if( $number eq 'P')
			{
				#print STDOUT "+Pl";
				$EagleMorphs = $EagleMorphs."+Pl";
			}
		}
		#common noun
		else
		{
			#print STDOUT "$slem";
			$EagleMorphs = "$slem:";
			if($grade eq 'A')
			{
				#print STDOUT "+Aug";
				$EagleMorphs = $EagleMorphs."+Aug";
			}
			if($grade eq 'D')
			{
				#print STDOUT "+Dim";
				$EagleMorphs = $EagleMorphs."+Dim";
			}
			if($number eq 'P')
			{
				#print STDOUT "+Pl";
				$EagleMorphs = $EagleMorphs."+Pl";
			}
		}
		$EagleMorphs = $EagleMorphs.&getMorphFromChunk($node,$chunk);
		#print STDOUT $node->findvalue('parent::CHUNK[@type="sn" or @type="coor-n"]/@poss');
		#print STDOUT $node->findvalue('parent::CHUNK[@type="sn" or @type="coor-n"]/@nouncase');
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
	elsif($eaglesTag =~ /^C|I|S|W|D/)
	{
		print STDOUT "$slem";
	}
	return $EagleMorphs;
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



sub adjustMorph{
	my $morphString = $_[0];
	my $mapTagsToSlotsRef = $_[1];
	
	#extract root: 
	my ($roottag) = ($morphString =~ m/(NRootNUM|NRoot|Noun|VRoot|Verb|Copula|Part|PrnDem|PrnInterr|PrnPers)/ ) ;
	#delete double ++ and commas
	$morphString =~ s/$roottag//g;
	$morphString =~ s/\+\+(\+)?/\+/g;
	$morphString =~ s/,//g;
	
	# if there's a +Fut tag that was added during the transfer:
	# attach this to subj tag: 1.Sg.Subj+Fut = 1.Sg.Subj.Fut
	if($morphString =~ /\+Fut/)
	{
		$morphString =~ s/Subj/Subj.Fut/g;
		$morphString =~ s/\+Fut//g;
	}
	
	
	my @morphs = split(/(\+)/, $morphString);

	my %sortedMorphs =();
	my $sortedMorphString ='';
	#print STDERR "morphemes:"; 
	foreach my $m (@morphs)
	{
		unless($m eq '+' or $m eq '')
		{
			$m = '+'.$m;
			my $slot = $mapTagsToSlots{$m};
			$sortedMorphs{$m} = $slot;
		}
	}
	# sort %sortedMorphs by value
	# (advantage of using a hash: tags that have been accumulated double during transfer -> only one will appear in the output)
	foreach my $tag (sort { $sortedMorphs{$a} <=> $sortedMorphs{$b} } keys %sortedMorphs) 
	{
  		$sortedMorphString= $sortedMorphString.$tag;
	}
	return $sortedMorphString;
	#print STDERR "unsorted morph: $morphString\n";
	#print STDERR "sorted morph: $sortedMorphString\n";
}

sub printPrePunctuation{
	my $chunk = $_[0];
	# if there's an attribute PrePunc: opening punctuation, print this first
 	if($chunk->hasAttribute('PrePunc'))
 	{
 		if($chunk->getAttribute('PrePunc') eq 'quot'){
 			print STDOUT "\"\n";
 			}
 		else{
 			print STDOUT $chunk->getAttribute('PrePunc')."\n";}
 			}
}
