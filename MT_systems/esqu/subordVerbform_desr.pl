#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
use open ':utf8';
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

# note that if the subordinated clause preceeds the main clause, subordination depends on main verb:
#  <SENTENCE ord="1">
#    <CHUNK type="grup-verb" si="top" ord="6">
#      <NODE ord="6" form="saldré" lem="salir" pos="vm" cpos="v" rel="sentence" mi="VMIF1S0">
#        <NODE ord="1" form="Cuando" lem="cuando" pos="cs" cpos="c" head="6" rel="conj" mi="CS"/>
#      </NODE>
#      <CHUNK type="grup-verb" si="suj" ord="2">
#        <NODE ord="2" form="termino" lem="terminar" pos="vm" cpos="v" rel="suj" mi="VMIP1S0"/>
#        <CHUNK type="grup-sp" si="creg" ord="3">
#          <NODE ord="3" form="de" lem="de" pos="sp" cpos="s" rel="creg" mi="SPS00"/>
#          <CHUNK type="grup-verb" si="S" ord="4">
#            <NODE ord="4" form="comer" lem="comer" pos="vm" cpos="v" rel="S" mi="VMN0000"/>
#          </CHUNK>
#        </CHUNK>
#        <CHUNK type="F-term" si="term" ord="5">
#          <NODE ord="5" form="," lem="," pos="Fc" cpos="F" mi="FC"/>
#        </CHUNK>
#      </CHUNK>
#      <CHUNK type="F-term" si="term" ord="7">
#        <NODE ord="7" form="." lem="." pos="Fp" cpos="F" mi="FP"/>
#      </CHUNK>
#    </CHUNK>
#  </SENTENCE>


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
 				if($verbChunk->exists('parent::CHUNK[@type="coor-v"]'))
 				{
 					$conjunction = @{$verbChunk->findnodes('parent::CHUNK[@type="coor-v"]/NODE[@cpos="v"]/NODE[@pos="cs"]')}[0];
 				}
 				else
 				{
 					$conjunction = @{$verbChunk->findnodes('child::NODE[@cpos="v"]/NODE[@pos="cs"]')}[0];
 				}
 		
 				
 				# if this verb has a 'tener que' part or deber +inf -> obligative, TODO: hay que?
 				if($verbChunk->exists('child::NODE[@cpos="v"]/NODE[@lem="tener"]/NODE[@lem="que" and @pos="cs"]') || ($verbChunk->exists('child::NODE[@mi="VMN0000"]/NODE[@lem="tener"]') && $verbChunk->exists('child::NODE[@mi="VMN0000"]/NODE[@lem="que"]') ) || $verbChunk->exists('child::NODE[@mi="VMN0000"]/NODE[@lem="deber"]') )
 				{
 					$nbrOfFinalClauses++;
 					$verbChunk->setAttribute('verbform', 'obligative');
 				}
 				# if this is a passive clause with 'ser'/'estar'
 				elsif($verbChunk->exists('child::NODE[starts-with(@mi,"VMP")]/NODE[@lem="ser" or @lem="estar"]'))
 				{
 					$verbChunk->setAttribute('verbform', 'passive');
 				}
 				# if this is a subordinated clause with 'si/cuando..'-> switch-reference forms (desr sometimes makes the sub-clause the main clause)
 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /si|cuando|aunque|porque|con_tal_que/ )
 				{
 					$nbrOfSwitchForms++;
 					#check if same subject 
 					&compareSubjects($verbChunk);
 					if($conjunction->getAttribute('lem') =~ /porque|con_tal_que/ )
 					{
 						$verbChunk->setAttribute('verbmi', '+DirE,+IndE');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /aunque|bien|bien_si/ )
 					{
 						$verbChunk->setAttribute('verbmi', '+Add');
 					}
 					elsif($conjunction->getAttribute('lem') =~ /^si$/ )
 					{
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
 					# hazlo como te dije -> nisqay hina ruway
 					if($conjunction->getAttribute('lem') =~ /como/)
 					{
 						$verbChunk->setAttribute('postpos', 'hina');
 					}
 				}
 				# if this is a final clause,  -na?
				
				elsif($conjunction && $conjunction =~ /con_fin_de_que|conque|con_que|para_que|mientras|mientras_que|hasta_que/ && &isSubjunctive($verbChunk))
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
 				# if subordinated clause is a gerund -> set to spa-form (trabaja cantando)
 				elsif($verbChunk->exists('child::NODE[starts-with(@mi, "VMG")]') && !$verbChunk->exists('descendant::NODE[@pos="va" or @pos="vs"]') && !$verbChunk->exists('child::NODE[starts-with(@mi, "VMG")]/NODE[@lem="venir" or @lem="ir" or @lem="andar" or @lem="estar"]')  )
 				{
 					$nbrOfSwitchForms++;
 					$verbChunk->setAttribute('verbform', 'SS');
 				}
 				# if this is a complement clause (-> nominal form), TODO: already ++Acc?
 				elsif($verbChunk->exists('self::CHUNK[@si="sentence" or @si="cd" or @si="CONCAT"]/NODE/NODE[@pos="cs"]') && $verbChunk->exists('parent::CHUNK[@type="grup-verb" or @type="coor-v"]') ) 
 				{
 					$nbrOfNominalForms++;
 					my $headVerbCHunk = @{$verbChunk->findnodes('parent::CHUNK[@type="grup-verb" or @type="coor-v"]')}[0];
 					if($headVerbCHunk)
 					{
 						my $headVerb = &getMainVerb($headVerbCHunk);
 						# if this is a complement of a speech verb -> use direct speech, finite form, insert 'nispa' in head chunk
 						if($headVerb && $headVerb->getAttribute('lem') =~ /admitir|advertir|afirmar|alegar|argumentar|aseverar|atestiguar|confiar|confesar|contestar|decir|declarar|expresar|hablar|indicar|manifestar|mencionar|oficiar|opinar|proclamar|proponer|razonar|revelar|responder|sostener|señalar|testificar|testimoniar/)
 						{
							$verbChunk->setAttribute('verbform', 'main');
							$headVerbCHunk->setAttribute('lem2', 'ni');
							$headVerbCHunk->setAttribute('verbmi2', '+SS');
 						}
 						else
 						{
 							if(&isSubjunctive($verbChunk) or &isFuture($verbChunk))
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
					$verbChunk->setAttribute('verbform', 'main');
					my $subordVerb = @{$verbChunk->findnodes('child::CHUNK[@type="grup-verb" or @type="coor-v"]/NODE[@mi="VMN0000"]')}[0];
					if( $subordVerb)
					{
						$subordVerb->parentNode->setAttribute('verbform', 'obligative');
					}
				}
				# if this is a main clause, or a coordinated verbform of a main clause, set verbform to 'main'
 				elsif( ($verbChunk->exists('self::CHUNK[@si="top"]') ||  $verbChunk->exists('parent::CHUNK[@si="top" and @type="coor-v"]')) && !$verbChunk->exists('child::NODE[@cpos="v"]/NODE[@pos="cs"]') )
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
		
			#print STDERR $finiteMainVerb ->getAttribute('lem').": $verbMIMain\n";
			#print STDERR $finiteVerb->getAttribute('lem').": $verbMI\n";
		
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
		  	
		 	 	#print STDERR $finiteMainVerb ->getAttribute('lem').": ".$finiteMainVerb->getAttribute('mi')."\n";
				#print STDERR $finiteVerb->getAttribute('lem').": ".$finiteVerb->getAttribute('mi')."\n";
		  	
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
		
				#if subjects of main and subord clause found, check if they're the same
				if($subjNounMain,$subjNoun,$subjMIMain,$subjMI)
				{
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
				else
				{
					$nbrOfAmbigousClauses++;
					$verbChunk->setAttribute('verbform', 'switch'); # maybe better default=DS here?
				}
			}
		  	}
		}
	}
	 # if no main verb found, set verbform to ambiguous
	else
	{
		$nbrOfAmbigousClauses++;
		$verbChunk->setAttribute('verbform', 'ambiguous');
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
	my $subjectChunk = @{$verbChunk->findnodes('child::CHUNK[@si="subj" or @si="subj-a"][1]')}[-1];
	
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
		#print STDERR $verbChunk->toString;
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
