#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
#use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
use File::Spec::Functions qw(rel2abs);
use File::Basename;
my $path = dirname(rel2abs($0));
require "$path/../util.pl";

#read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

my @sentenceList = $dom->getElementsByTagName('SENTENCE');

my $nbrOfRelClauses =0;
my $nbrOfSwitchForms=0;
my $nbrOfNominalForms=0;
my $nbrOfFinalClauses=0;
my $nbrOfFiniteForms=0;
my $nbrOfAmbigousClauses=0;
my $nbrOfVerbChunks=0;
my $nbrOfNonFiniteChunks=0;

foreach my $sentence (@sentenceList)
{
	# get all verb chunks and check if they have an overt subject, 
	# if they don't have an overt subject and precede the main clause -> look for subject in preceding sentence
	# if they don't have an overt subject and follow the main clause, and the main clause has an overt subject, this is the subject of the subordinated chunk
	print STDERR "Disambiguating verb form in sentence:";
	print STDERR $sentence->getAttribute('ord')."\n";
	
 	
 	# consider linear sequence in sentence; in xml the verb of the main clause comes always first, but in this case the subject of a preceding subordinated clause is probably coreferent with the subject of the preceding clause
 	my @verbChunks = $sentence->findnodes('descendant::CHUNK[@type="grup-verb" or @type="coor-v"]');
 	$nbrOfVerbChunks = $nbrOfVerbChunks+scalar(@verbChunks);
 	#print STDERR "$nbrOfVerbChunks\n";
 	
 	foreach my $verbChunk (@verbChunks)
 	{
 		if(&getFiniteVerb($verbChunk))
 		{
 			# disambiguation needed only if not relative clause (those are handled separately)
 			if( !&isRelClause($verbChunk) )
 			{
 				my $conjunction;
 				# get conjunction, if present:
 				#  for a coordinated, get the conjunction from head of coordination, unless this verb has its own conjunction 
 				# -> in this case, the parser messed up, take the conjunction of this verb, not the head (but we don't really know which one is right)
 				if($verbChunk->exists('parent::CHUNK[@type="coor-v"]') && !$verbChunk->exists('child::NODE[@cpos="v"]/NODE[@pos="cs" or @pos="cc"]') )
 				{ 
 					$conjunction = @{$verbChunk->findnodes('parent::CHUNK[@type="coor-v"]/NODE[@cpos="v"]/NODE[@pos="cs" or @pos="cc"]')}[0];
 				}
 				elsif($verbChunk->getAttribute('si') ne 'top' || $verbChunk->exists('parent::CHUNK[@type="coor-v"]') && $verbChunk->exists('child::NODE[@cpos="v"]/NODE[@pos="cs" or @pos="cc"]'))
 				{
 					$conjunction = @{$verbChunk->findnodes('child::NODE[@cpos="v"]/NODE[@pos="cs" or @pos="cc"]')}[0];
 				}
 				if($conjunction){print STDERR "conj: ".$conjunction->toString();}
 				
 				# if this verb has a 'tener que' part or deber +inf -> obligative, TODO: hay que?
 				if($verbChunk->exists('child::NODE[@cpos="v"]/NODE[@lem="tener"]/NODE[@lem="que" and @pos="cs"]') || ($verbChunk->exists('child::NODE[@mi="VMN0000"]/NODE[@lem="tener"]') && $verbChunk->exists('child::NODE[@mi="VMN0000"]/NODE[@lem="que"]') ) || $verbChunk->exists('child::NODE[@mi="VMN0000"]/NODE[@lem="deber"]') )
 				{
 					$nbrOfFinalClauses++;
 					$verbChunk->setAttribute('verbform', 'obligative');
 				}
 				# if this is hay/había/habrá que + infinitive -nan kan
 				elsif($verbChunk->exists('child::NODE[@lem="haber" and contains(@mi,"3")]') && $verbChunk->exists('child::CHUNK/NODE[@mi="VMN0000"]/NODE[@lem="que"]') )
 				{
 					$nbrOfFiniteForms++;
 					$verbChunk->setAttribute('verbform','main');
 					#$verbChunk->setAttribute('delete','yes');
 					# get infintive of main verb and set this form to obligative
 					my $infinitive = @{$verbChunk->findnodes('child::CHUNK[NODE[@mi="VMN0000"]/NODE[@lem="que"]][1]')}[0];
 					if($infinitive)
 					{
 						$nbrOfFinalClauses++;
 						$infinitive->setAttribute('verbform', 'obligative');
 						$infinitive->setAttribute('addverbmi', '+3.Sg.Poss');
 					}
 				}
 				# if this is a passive clause with 'ser'/'estar'
 				elsif($verbChunk->exists('child::NODE[starts-with(@mi,"VMP")]/NODE[@lem="ser" or @lem="estar"]'))
 				{
 					$verbChunk->setAttribute('verbform', 'passive');
 				}
 				# if this is a topicalization with 'ser' -> delete verb, but insert a topic marker
 				# -> es ahí donde viven -> kaypiQA kaswanku
 				elsif($verbChunk->exists('child::NODE[@lem="ser"]') && $verbChunk->findvalue('child::CHUNK[@type="sadv"]/NODE/@lem') =~ /ahí|allá|aquí/ && $verbChunk->exists('descendant::NODE[@lem="donde"]') )
 				{print STDERR "hieeeeeeeeeer\n";
 					$verbChunk->setAttribute('delete', 'yes');
 					# set sadv chunkmi to +Top
 					my $sadv = @{$verbChunk->findnodes('child::CHUNK[NODE[@lem="ahí" or @lem="allá" or @lem="aquí"]][1]')}[0];
 					if($sadv)
 					{
 						$sadv->setAttribute('chunkmi', '+Top');
 					}
 				}
 				# set form of sub verb in those topicalized forms
 				elsif($verbChunk->exists('parent::CHUNK/NODE[@lem="ser"]') && $verbChunk->findvalue('parent::CHUNK/CHUNK[@type="sadv"]/NODE/@lem') =~ /ahí|allá|aquí/ && $verbChunk->exists('child::NODE/NODE[@lem="donde"]') )
 				{
 					$nbrOfFiniteForms++;
 					$verbChunk->setAttribute('verbform', 'main');
 				}
 				# if this is a subordinated clause with 'si/cuando..'-> switch-reference forms (desr sometimes makes the sub-clause the main clause)
 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /si|cuando|aunque|porque|con_tal_que/ && !$conjunction->getAttribute('lem') =~ /pero_cuando|y_cuando/)
 				{
 					
 					#check if same subject 
 					&compareSubjects($verbChunk);
 					if($conjunction->getAttribute('lem') =~ /porque|con_tal_que/ )
 					{
 						$nbrOfSwitchForms++;
 						$verbChunk->setAttribute('verbmi', '+DirE,+IndE');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /aunque|bien|bien_si/ )
 					{
 						$nbrOfSwitchForms++;
 						$verbChunk->setAttribute('verbmi', '+Add');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /^si$/ )
 					{
 						$nbrOfSwitchForms++;
 						$verbChunk->setAttribute('verbmi', '+Top');
 					}
 				}
 				# if this a subordinated clause with a finite verb (in Quechua)
 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /pero|empero|^o$|^y$|^e$|^u$|sino|^ni$|ni_siquiera|por_tanto|por_lo_tanto|tanto_como|entonces|pues|por_eso|ya_que|aun|aún|aun_no|aún_no/ )
 				{
 					$nbrOfFiniteForms;
 					$verbChunk->setAttribute('verbform', 'main');
 					if($conjunction->getAttribute('lem') =~ /pero|empero/ )
 					{
 						$verbChunk->setAttribute('conj', 'ichaqa');
 					}
 					# -taq
 					elsif($conjunction->getAttribute('lem') =~ /^o$|^y$|^e$|^u$/ )
 					{
 						$verbChunk->setAttribute('verbmi', '+Intr');
 					}
 					#sino: aswanpas
 					elsif($conjunction->getAttribute('lem') =~ /sino/ )
 					{
 						$verbChunk->setAttribute('conj', 'aswanpas');
 					}
 					#ni, ni_siquera: nitaq
 					elsif($conjunction->getAttribute('lem') =~ /^ni$|ni_siquiera/ )
 					{
 						$verbChunk->setAttribute('conj', 'nitaq');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /por_tanto|por_lo_tanto/ )
 					{
 						$verbChunk->setAttribute('conj', 'chaymi');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /tanto_como/ )
 					{
 						$verbChunk->setAttribute('postpos', 'ima');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /entonces|pues/ )
 					{
 						$verbChunk->setAttribute('conj', 'hinaspaqa');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /por_eso/ )
 					{
 						$verbChunk->setAttribute('conj', 'chayrayku');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /ya_que/ )
 					{
 						$verbChunk->setAttribute('conj', 'chayqa');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /aún|aun$/ )
 					{
 						$verbChunk->setAttribute('conj', 'chayraq');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /aún_no|aun_no/ )
 					{
 						$verbChunk->setAttribute('conj', 'manaraq');
 					}
 				}
 				# nominal subordinated clauses (no complement clauses, those are treated below!)
 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /como/ )
 				{
 					$nbrOfNominalForms;
 					if(&isSubjunctive($verbChunk) or &isFuture($verbChunk))
 					{
 						$verbChunk->setAttribute('verbform', 'obligative');
 					}
 					else
 					{
 						$verbChunk->setAttribute('verbform', 'perfect');
 					}
 					# hazlo como te dije -> nisqay hinalla ruway
 					if($conjunction->getAttribute('lem') =~ /como/)
 					{
 						$verbChunk->setAttribute('postpos', 'hinalla');
 					}
 				}
 				# if this is a final clause,  -na?
				
				elsif($conjunction && $conjunction->getAttribute('lem') =~ /con_fin_de_que|conque|con_que|para_que|mientras|mientras_que|hasta_que/ && &isSubjunctive($verbChunk))
				{
					$nbrOfFinalClauses++;
					$verbChunk->setAttribute('verbform', 'obligative');
					if($conjunction->getAttribute('lem') =~ /mientras|hasta_que/)
					{
						$verbChunk->setAttribute('case', '+Term');
					}
					else
					{
						$verbChunk->setAttribute('case', '+Ben');
					}
				}
				# mientras, mientras que -> na -kama/ -spa/-pti?
				elsif($conjunction && $conjunction->getAttribute('lem') =~ /mientras/ )
				{
					$nbrOfFinalClauses++;
					$verbChunk->setAttribute('verbform', 'obligative');
					$verbChunk->setAttribute('case', '+Term');
				}
 				# if subordinated clause is a gerund -> set to spa-form (trabaja cantando)
 				# wrong, gerund is main verb in chunk TOGETHER with finite verb -> verbform of gerund always SS, but verbform of finite verb -> disambiguate like any other chunk
# 				elsif($verbChunk->exists('child::NODE[starts-with(@mi, "VMG")]') && !$verbChunk->exists('descendant::NODE[@pos="va" or @pos="vs"]') && !$verbChunk->exists('child::NODE[starts-with(@mi, "VMG")]/NODE[@lem="venir" or @lem="ir" or @lem="andar" or @lem="estar"]')  )
# 				{
# 					$nbrOfSwitchForms++;
# 					$verbChunk->setAttribute('verbform', 'SS');
# 				}
 				# if this is a complement clause (-> nominal form), TODO: already ++Acc?
 				elsif($verbChunk->exists('self::CHUNK[@si="sentence" or @si="cd" or @si="CONCAT" or @si="S"]/descendant::NODE[@pos="cs"]') && $verbChunk->exists('parent::CHUNK[@type="grup-verb" or @type="coor-v"]') ) 
 				{
 					my $headVerbCHunk = @{$verbChunk->findnodes('parent::CHUNK[@type="grup-verb" or @type="coor-v"]')}[0];
 					if($headVerbCHunk)
 					{
 						my $headVerb = &getMainVerb($headVerbCHunk);
 						#print STDERR "head verb: \n".$headVerb->toString."\n";
 						# if this is a complement of a speech verb -> use direct speech, finite form, insert 'nispa' in head chunk
 						if($headVerb && $headVerb->getAttribute('lem') =~ /admitir|advertir|afirmar|alegar|argumentar|aseverar|atestiguar|confiar|confesar|contestar|decir|declarar|expresar|hablar|indicar|manifestar|mencionar|oficiar|opinar|proclamar|proponer|razonar|recalcar|revelar|responder|sostener|señalar|testificar|testimoniar/)
 						{
 							# check if subject of complement clause is the same as in the head clause, if so, person of verb should be 1st
							# e.g. Pedro dice que se va mañana - paqarin risaq, Pedro nispa nin.
							# note: if compareSubjects gives 'switch', this means that both verbs are 3rd persons and have the same number, but at least
							#  one of the clauses has no overt subject. It is safe to assume that in this case the subjects are coreferential with a say verb in the main clause
							&compareSubjects($verbChunk);
							#print $verbChunk->toString."\n";
							if(($verbChunk->getAttribute('verbform') eq 'SS' || $verbChunk->getAttribute('verbform') eq 'switch') && &isSingular($verbChunk))
							{
								$verbChunk->setAttribute('verbprs', '+1.Sg.Subj')
							}
							elsif($verbChunk->getAttribute('verbform') eq 'SS' && !&isSingular($verbChunk))
							{
								$verbChunk->setAttribute('verbprs', '+1.Pl.Excl.Subj')
							}
							# set both this verb and the head verb to 'main'
							$verbChunk->setAttribute('verbform', 'main');
							$headVerbCHunk->setAttribute('lem1', 'ni');
							$headVerbCHunk->setAttribute('verbmi1', '+SS');
							$nbrOfFiniteForms++;
							$nbrOfSwitchForms--;
							
 						}
 						else
 						{	
 							$nbrOfNominalForms++;
 							if(&isSubjunctive($verbChunk) || &isFuture($verbChunk))
 							{
 								$verbChunk->setAttribute('verbform', 'obligative');
 								$verbChunk->setAttribute('case', '+Acc');
 							}
 							else
 							{
 								$verbChunk->setAttribute('verbform', 'perfect');
 								$verbChunk->setAttribute('case', '+Acc');
 							}
 						}
 					}
 				}
				# special case: hace falta que + subjuntivo -> 'hace falta que' -> kan, subj.-verb: +-na 
				# hace falta que te vayas -> ripunayki kan
				# also: hace falta comprar pan -> t'anta rantinan kan
				elsif($verbChunk->exists('child::NODE[ @lem="hacer_falta" or @lem="hacer_falta_que"]') )
				{
					$nbrOfFiniteForms++;
					$verbChunk->setAttribute('verbform', 'main');
					my $subordVerb = @{$verbChunk->findnodes('child::CHUNK[@type="grup-verb" or @type="coor-v"]/NODE[@mi="VMN0000"]')}[0];
					if( $subordVerb)
					{
						$nbrOfFinalClauses++;
						$subordVerb->parentNode->setAttribute('verbform', 'obligative');
					}
				}
				# if this is a main clause, or a coordinated verbform of a main clause, set verbform to 'main'
				# also: if this is not the top chunk, but there's no other verb chunk above this one, set verb form to main (probably a parser error)
 				elsif( ($verbChunk->exists('self::CHUNK[@si="top"]') ||  $verbChunk->exists('parent::CHUNK[@si="top" and @type="coor-v"]')) && !$verbChunk->exists('child::NODE[@cpos="v"]/NODE[@pos="cs"]') || !$verbChunk->exists('ancestor::CHUNK[@type="grup-verb" or @type="coor-v"]') )
 				{
 					$nbrOfFiniteForms++;
 					$verbChunk->setAttribute('verbform', 'main');
 				}
				else
				{
					$nbrOfAmbigousClauses++;
					$verbChunk->setAttribute('verbform', 'ambiguous');
				}
 			}
			else
			{ 
				#this is a relative clause, copy verbform value to chunk (otherwise, it will get lost during the lexical transfer)
				my $reltype = $verbChunk->findvalue('child::NODE/descendant-or-self::NODE/@verbform');
				$verbChunk->setAttribute('verbform',$reltype);
				$nbrOfRelClauses++;
			}
 		}
 		else
 		{
 			$nbrOfNonFiniteChunks++;
 		}
 	}
 	
}

print STDERR "\n****************************************************************************************\n";
print STDERR "total number of verb chunks: ".$nbrOfVerbChunks."\n";
print STDERR "total number of verb chunks with no finite verb: ".$nbrOfNonFiniteChunks."\n";
print STDERR "total number of relative clauses: $nbrOfRelClauses \n";
print STDERR "total number of switch reference forms: ".$nbrOfSwitchForms."\n";
print STDERR "total number of nominal clauses: ".$nbrOfNominalForms."\n";
print STDERR "total number of final clauses: ".$nbrOfFinalClauses."\n";
print STDERR "total number of finite forms: ".$nbrOfFiniteForms."\n";
print STDERR "total number of ambiguous clauses: ".$nbrOfAmbigousClauses."\n";
print STDERR "total number of disambiguated verb forms: ".($nbrOfRelClauses+$nbrOfSwitchForms+$nbrOfNominalForms+$nbrOfFinalClauses+$nbrOfFiniteForms)."\n";
print STDERR "\n****************************************************************************************\n";

# print new xml to stdout
my $docstring = $dom->toString(1);
#print STDERR $dom->actualEncoding();
print STDOUT $docstring;

sub compareSubjects{
	my $verbChunk = $_[0];
	my $finiteVerb = &getFiniteVerb($verbChunk);
	print STDERR "compare subjs in chunk:".$verbChunk->getAttribute('ord')."\n";
	#subject of main clause
	my $mainverb = &getVerbMainClause($verbChunk);
	if($mainverb && $finiteVerb)
	{
		my $finiteMainVerb = &getFiniteVerb($mainverb);
		#print STDERR $finiteMainVerb->toString;
		#compare person & number
		if($finiteMainVerb  && $finiteVerb->getAttribute('mi') =~ /1|2/ )
		{
			my $verbMI = $finiteVerb->getAttribute('mi');
			my $verbPerson = substr ($verbMI, 4, 1);
			my $verbNumber = substr ($verbMI, 5, 1);
	
			my $verbMIMain = $finiteMainVerb->getAttribute('mi');
			my $verbPersonMain = substr ($verbMIMain, 4, 1);
			my $verbNumberMain = substr ($verbMIMain, 5, 1);
		
			print STDERR $finiteMainVerb ->getAttribute('lem').": $verbMIMain\n";
			print STDERR $finiteVerb->getAttribute('lem').": $verbMI\n";
		
			if($verbPerson eq $verbPersonMain && $verbNumber eq $verbNumberMain)
			{
				$nbrOfSwitchForms++;
				$verbChunk->setAttribute('verbform', 'SS');
			}
			else
			{
				$nbrOfSwitchForms++;
				$verbChunk->setAttribute('verbform', 'DS');
			}
		}
		# if 3rd person
		elsif($finiteMainVerb  && $finiteVerb->getAttribute('mi') !~ /1|2/ )
		{ 
		 	 # if main verb SAP -> DS
		  	 if($finiteMainVerb->getAttribute('mi') =~ /1|2/)
		 	 {
		 	 		$nbrOfSwitchForms++;
		  			$verbChunk->setAttribute('verbform', 'DS');
		 	 }
		 	 else
		 	 {
		  		#check number
		  		my $verbNumberMain = substr ($finiteMainVerb->getAttribute('mi'), 5, 1);
		  		my $verbNumber = substr ($finiteVerb->getAttribute('mi'), 5, 1);
		  	
		 	 	print STDERR $finiteMainVerb ->getAttribute('lem').": ".$finiteMainVerb->getAttribute('mi')."\n";
				print STDERR $finiteVerb->getAttribute('lem').": ".$finiteVerb->getAttribute('mi')."\n";
		  	
			  	if($verbNumber ne $verbNumberMain)
			  	{
			  		$nbrOfSwitchForms++;
		  			$verbChunk->setAttribute('verbform', 'DS');
		  		}
		  		# else, if both 3rd and same number: check coref
		  		else
		  		{
					# subject of this (subordinate) clause
					my ($subjNoun, $subjMI ) = &getSubjectNoun($verbChunk);
					my ($subjNounMain,$subjMIMain ) =  &getSubjectNoun($mainverb);
		
				# if subjects of main and subord clause found, check if they're the same
				if($subjNounMain,$subjNoun,$subjMIMain,$subjMI)
				{
					#print STDERR "main: $subjNounMain $subjMIMain | sub: $subjNoun $subjMI\n";
					if($subjNounMain eq $subjNoun && $subjMIMain eq $subjMI)
					{
						$nbrOfSwitchForms++;
						$verbChunk->setAttribute('verbform', 'SS');
					}
					else
					{
						$nbrOfSwitchForms++;
						$verbChunk->setAttribute('verbform', 'DS');
					}
				}
				elsif(!$subjNounMain && !$subjNoun)
				{
					$nbrOfSwitchForms++;
					$verbChunk->setAttribute('verbform', 'SS'); 
				}
				else
				{
					$nbrOfAmbigousClauses++;
					$verbChunk->setAttribute('verbform', 'switch'); # maybe better default=SS here?
				}
			}
		  	}
		}
	}
	 # if no main verb found, set verbform to ambiguous
	 # edit: set verb form to switch, as its probably either -spa or -pti
	else
	{
		$nbrOfAmbigousClauses++;
		$verbChunk->setAttribute('verbform', 'switch');
	}
}

sub isSubjunctive{
	my $verbChunk = $_[0];
	my $finiteVerb = &getFiniteVerb($verbChunk);
	if($finiteVerb)
	{
		return substr($finiteVerb->getAttribute('mi'), 2, 1) eq 'S';
	}
	else
	{
		return 0;
	}
}

sub isSingular{
	my $verbChunk = $_[0];
	my $finiteVerb = &getFiniteVerb($verbChunk);
	if($finiteVerb)
	{
		return substr($finiteVerb->getAttribute('mi'), 5, 1) eq 'S';
	}
	else
	{
		return 0;
	}
}

sub isFuture{
	my $verbChunk = $_[0];
	my $finiteVerb = &getFiniteVerb($verbChunk);
	if($finiteVerb)
	{
		return substr($finiteVerb->getAttribute('mi'), 3, 1) eq 'F';
	}
	else
	{
		return 0;
	}
}

sub getSubjectNoun{
	my $verbChunk = $_[0];
	my ($subjectNoun,$subjectNounMI);
	my $subjectChunk = @{$verbChunk->findnodes('child::CHUNK[@si="suj" or @si="suj-a"][1]')}[-1];
	
	if($subjectChunk)
	{
			$subjectNoun = $subjectChunk->findvalue('NODE[@cpos="n" or @pos="pp"][1]/@lem');
			$subjectNounMI = $subjectChunk->findvalue('NODE[@cpos="n" or @pos="pp"][1]/@mi');
	}
	# else if no overt subject, but coref
	elsif($verbChunk->exists('self::CHUNK/@coref'))
	{
		$subjectNoun = $verbChunk->getAttribute('coref');
		$subjectNounMI = $verbChunk->getAttribute('corefmi');
	}
	else
	{
		print STDERR "no subject, no coref in: ";
		print STDERR $verbChunk->getAttribute('ord');
		print STDERR "\n";
	}

	my @subj = ($subjectNoun, $subjectNounMI);
	print STDERR "$subjectNoun:$subjectNounMI\n";
	return @subj;
}


sub getVerbMainClause{
	my $subordVerbChunk= $_[0];
	my $headVerbChunk; 
	
	#if this subordinated clause is wrongly analysed as main clause
	if($subordVerbChunk && $subordVerbChunk->exists('self::CHUNK[@si="top"]'))
	{
		#print STDERR "subord verb chunk: ".$subordVerbChunk->toString()."\n";
		$headVerbChunk = @{$subordVerbChunk->findnodes('child::CHUNK[@type="grup-verb" or @type="coor-v"][1]')}[0];
	}
	elsif($subordVerbChunk && $subordVerbChunk->exists('ancestor::SENTENCE/CHUNK[@si="top" and @type="grup-verb"]'))
	{
		$headVerbChunk = @{$subordVerbChunk->findnodes('ancestor::SENTENCE/CHUNK[@si="top" and @type="grup-verb"][1]')}[0];
	}
	# if head of sentence is not a verb chunk -> wrong analysis or incomplete sentence (e.g. title)
	# -> check if subord verb chunk has any verb chunks as ancestor
	elsif($subordVerbChunk && $subordVerbChunk->exists('ancestor::SENTENCE/CHUNK[@si="top" and not(@type="grup-verb")]') )
	{
		$headVerbChunk = @{$subordVerbChunk->findnodes('ancestor::CHUNK[@type="grup-verb"][1]')}[0];
	}
	else
	{
		#get sentence id
		my $sentenceID = $subordVerbChunk->findvalue('ancestor::SENTENCE/@ord');
		print STDERR "head verb chunk not found in sentence nr. $sentenceID: \n ";
		print $subordVerbChunk->toString();
		print "\n";
		return 0;
	}
	return $headVerbChunk;
}
