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

# retrieve hash with config parameters from disk, get path to file with semantic information
eval {
	my $hashref = retrieve("$path/../VerbLex");
} or die "No VerbLex found! Use readInSemanticDix.pl first! ";

eval {
	my $hashref = retrieve("$path/../NounLex");
} or die "No NounLex found! Use readInSemanticDix.pl first!";

my %lexEntriesWithFrames   = %{ retrieve("VerbLex") };
my %nounLexicon = %{ retrieve("NounLex") };

#foreach my $key (sort keys %lexEntriesWithFrames)
#{
#	print "$key: ";
#	foreach my $frame (@{ $lexEntriesWithFrames{$key} })
#	{
#		print "$frame ";
#	}
#	#print @{ $lexEntriesWithFrames{$key} }[0];
#	print "\n";
#}



my $dom2    = XML::LibXML->load_xml( IO => *STDIN );

foreach my $sentence  ( $dom2->getElementsByTagName('SENTENCE'))
{
	#debug
	print STDERR "disambiguating relative clause in ".$sentence->getAttribute('ord')."\n";
	
	# check if sentence contains relative clause
	# with preposition sometimes grup-sp, rel=cc/sp depends on noun (vi al hombre [a quien dejaron])
	# -> never agentive form in quz -> set to rel:not.agentive
	my @relprnWithPP = $sentence->findnodes('descendant::CHUNK[@type="sn"]/CHUNK[@type="grup-sp"]/CHUNK[@type="grup-verb"]/descendant::NODE[@pos="pr"]');
	foreach my $relprnWithPP (@relprnWithPP)
	{
		my $verbchunk = &getParentChunk($relprnWithPP);
		#my @verbforms = $verbchunk->findnodes('descendant::NODE[@pos="vs" or @pos="vm"]');
		my @verbforms =();
		if($verbchunk)
		{
			my $firstverb = @{$verbchunk->findnodes('child::NODE[@pos="vm" or @pos="vs"][1]')}[-1];	
			my @coordVerbs = $verbchunk->findnodes('child::NODE[@rel="coord"]/following-sibling::CHUNK[@type="grup-verb" and (@si="S" or @si="cn")]/NODE[@pos="vm" or @pos="vs"]');
			if($firstverb && scalar(@coordVerbs)>0)
			{
				@verbforms = ($firstverb, @coordVerbs);
			}
			elsif($firstverb)
			{
				push (@verbforms, $firstverb);
			}
		
			#  if coordination: treat each verb seperately
			foreach my $verbform (@verbforms)
			{
				# if main verb is copula  -> agentive: la casa que está grande -> hatun kaq wasi
				if($verbform->getAttribute('lem') eq 'ser')
				{
					#$verbform->setAttribute('verbform', 'rel:delete');
					$verbform->setAttribute('verbform', 'rel:agentive');
				}
				else
				{
					$verbform->setAttribute('verbform', 'rel:not.agentive');	
				}
			}
		}
	}
	
	# correct analysis with preposition, grup-verb, rel=S, child chunk grup-sp with preposition+relprn
	# -> never agentive form in quz -> set to head.not.agent
	my @relprnWithPP2 = $sentence->findnodes('descendant::CHUNK[@type="sn"]/CHUNK[(@type="grup-verb" or @type="coor-v") and (@si="S" or @si="cn")]/CHUNK[@type="grup-sp"]/NODE[@pos="sp"]/descendant::NODE[@pos="pr"]');
	foreach my $relprnWithPP2 (@relprnWithPP2)
	{
		my $verbchunk = @{$relprnWithPP2->findnodes('ancestor::CHUNK[(@type="grup-verb" or @type="coor-v") and (@si="S" or @si="cn")][1]')}[-1];
		#my @verbforms = $verbchunk->findnodes('descendant::NODE[@pos="vs" or @pos="vm"]');
		my @verbforms =();
		
		if($verbchunk)
		{
			my $firstverb = @{$verbchunk->findnodes('child::NODE[@pos="vm" or @pos="vs"][1]')}[-1];	
			my @coordVerbs = $verbchunk->findnodes('child::NODE[@rel="coord"]/following-sibling::CHUNK[@type="grup-verb" and (@si="S" or @si="cn")]/NODE[@pos="vm" or @pos="vs"]');
			if($firstverb && scalar(@coordVerbs)>0)
			{
				@verbforms = ($firstverb, @coordVerbs);
			}
			elsif($firstverb)
			{
				push (@verbforms, $firstverb);
			}
		
			#  if coordination: treat each verb seperately
			foreach my $verbform (@verbforms)
			{
				# check if this is the main verb of the (possibly coordinated) chunk: first child node of verb chunk
				if($verbform->exists('parent::CHUNK[@type="grup-verb" or @type="coor-v"]'))
				{
					# if main verb is copula -> agentive: la casa que está grande -> hatun kaq wasi
					if($verbform->getAttribute('lem') eq 'ser')
					{
						#$verbform->setAttribute('verbform', 'rel:delete');
						$verbform->setAttribute('verbform', 'rel:agentive');
					}
					else
					{
						$verbform->setAttribute('verbform', 'rel:not.agentive');	
					}
				}
			}
		}
	}
		
	# headless relclauses: only with 'quien', 'el/los que', 'la/las que', ('aquel/aquella que' ??)
	# 'Quién está informado vive mejor', 'Los que trabajan, comen'
	# -> always agentive form (?) 'YACHAQqa aswan allinta kawsan. LLAMK'AQKUNA mikhunku'
	# also: lo que, el que -> insert topic suffix in this chunk! 
	my @headlessRelClauses = $sentence->findnodes('descendant::CHUNK[(@type="grup-verb" or @type="coor-v")]/NODE[@cpos="v"]/NODE[(@lem="quien" and @rel="suj") or (@pos="da" and @rel="spec")]');
	foreach my $subjOfheadlessRelclause (@headlessRelClauses)
	{ 
		# check if there's really no head or prepositinal phrase ('diferencia fuertemente de lo que conocen')
		# el que, la que -> agentive (else a la que, al que..), but 'lo que' -> ambigous
		# Lo que me molesta es tu actitud -> subj (but not agentive?)// Lo que dicen, me molesta -> cd
		if(!$subjOfheadlessRelclause->exists('ancestor::CHUNK[@type="sn" or @type="grup-sp"]'))
		{
			my $verbform = $subjOfheadlessRelclause->parentNode();
			my $verbchunk = @{$verbform->findnodes('ancestor::CHUNK[@type="grup-verb" or @type="coor-v"][1]')}[0];
			if ($verbform)
			{
				if(($verbform->exists('child::NODE[(not(@form="lo") and not(@form="Lo")) and @rel="spec"]') && $verbform->getAttribute('mi') =~ /3S/) || ($verbform->exists('child::NODE[(not(@form="los") and not(@form="Los")) and @rel="spec"]') && $verbform->getAttribute('mi') =~ /3P/) || ($subjOfheadlessRelclause->getAttribute('lem') eq 'quien' && $verbform->getAttribute('lem') !~ /estar|ser/))
				{
					$verbform->setAttribute('verbform', 'rel:agentive');
					$verbchunk->setAttribute('chunkmi', '+Top');
					# set HLRC (headless relative clause)
					$verbchunk->setAttribute('HLRC', 'yes');
				}
				else
				{ 	# if lo que, los que-> check if verb is congruent, if so, check if rel-clause contains an object
					if( ($verbform->exists('child::NODE[(@form="lo" or @form="Lo") and @rel="spec"]') && $verbform->getAttribute('mi') =~ /3S/) || ($verbform->exists('child::NODE[(@form="los" or @form="Los") and @rel="spec"]') && $verbform->getAttribute('mi') =~ /3P/) )
					{
						#my $verbchunk = @{$verbform->findnodes('parent::CHUNK[@type="grup-verb" or @type="coor-v"][1]')}[0];
						if($verbchunk && hasDorSPobj($verbchunk))
						{
							$verbform->setAttribute('verbform', 'rel:agentive');
							$verbchunk->setAttribute('chunkmi', '+Top');
							$verbchunk->setAttribute('HLRC', 'yes');
						}
					}
					else
					{
						$verbform->setAttribute('verbform', 'rel:not.agentive');
						$verbchunk->setAttribute('chunkmi', '+Top');
						$verbchunk->setAttribute('HLRC', 'yes');
					}
				}
			}	
		}
		# headless, within prep-phrase ->depende de lo que dicen, en lo que respecta la siniestralidad, etc -> perfect+Top
		else{
			my $verbform = $subjOfheadlessRelclause->parentNode();
			my $verbchunk = @{$verbform->findnodes('ancestor::CHUNK[@type="grup-verb" or @type="coor-v"][1]')}[0];
			$verbform->setAttribute('verbform', 'rel:not.agentive');
			$verbchunk->setAttribute('chunkmi', '+Top');
			$verbchunk->setAttribute('HLRC', 'yes');
		}
	}

	# relclauses without preposition:
	my @relprnNoPP = $sentence->findnodes('descendant::CHUNK[@type="sn"]/CHUNK[(@type="grup-verb" or @type="coor-v") and (@si="S" or @si="cn")]/NODE[@cpos="v"]/NODE[@pos="pr"]');

	foreach my $relprn (@relprnNoPP)
	{
	#my $relprn = @{$relClause->findnodes('descendant::NODE[@pos="pr"][1]')}[-1];
	my $relClause = @{$relprn->findnodes('ancestor::CHUNK[(@type="grup-verb" or @type="coor-v") and (@si="S" or @si="cn")][1]')}[-1];
	if($relClause)
	{
		#print STDERR "\n relclause:"; print $relClause->toString; print STDERR "\n";
		#print STDERR "\n relpron:"; print $relprn->getAttribute('lem'); print STDERR "\n";
		# if relative pronoun is something else than 'que' or 'quien', head noun is not subject
		if($relprn->getAttribute('lem') !~ /que|quien|cual/)
		{
			&setVerbform($relClause,0);
			# if relative pronoun is 'donde' -> this has to be translated as an internally headed RC:
			# 'La ciudad donde vivo es grande' -> ñuqap llaqta tiyasqayqa hatunmi
			if($relprn->getAttribute('lem') eq 'donde')
			{
				$relClause->setAttribute('IHRC', 'yes');
			}
		}
		#if main verb in rel clause is 'ser' -> always attributive, never agentive head noun (passive or attributive)
		elsif($relClause->exists('child::NODE[@lem="ser"]'))
		{ 
			#set to 'delete' (no copula in Quechua in this case)
			&setVerbform($relClause,2);
		}
		# with 'lo que', lo cual, (el que, la que..?) -> head is pronoun, else 'a la/el cual'
		# la cual, el cual -> subj
#		elsif($relClause->exists('child::NODE[@lem="cual"]/NODE[@lem="el"]'))
#		{
#			&setVerbform($relClause,1);
#		}
		# check if estar ->  unless estar+gerund: never agentive -> estar as main verb: vm, as auxiliary: va
		elsif($relClause->exists('child::NODE[@lem="estar" and @pos="vm"]') )
		{
			&setVerbform($relClause,0);
		}
		# check if relclause is passive with ser+participle: in this case, head noun is syntactic subject, but semantic object-> not agentive
		# 'la casa que ha sido vendida..'
		elsif($relClause->exists('child::NODE/NODE[@lem="ser" and @pos="vs"]') && $relClause->exists('child::NODE[starts-with(@mi, "VMP")]') )
		{
			&setVerbform($relClause,0);
		}
		else
		{
			my $headNoun = &getHeadNoun($relClause);
			# if getHeadNoun return 1, this is no relative clause, but something wrongly analysed -> ingnore this chunk
			unless($headNoun == -1)
			{
			#print STDERR $headNoun->getAttribute('lem');
			my $headNounMI = $headNoun->getAttribute('mi');
			#get lemma of head noun
			my $headNounLem = $headNoun->getAttribute('lem');
			#print STDERR "head lem: $headNounLem\n";
			#print STDERR "mi: $headNounMI\n";
		
			my $finiteVerb = &getFiniteVerb($relClause);
			if($finiteVerb)
			{
				my $verbMI = $finiteVerb->getAttribute('mi');
				#print STDERR $finiteVerb->toString;

				# relative clauses where head noun is personal pronoun of local person (1/2)
				# if verb agrees-> subj, (check frame), if not -> not agent
				# e.g. 'yo que soy tan floja'
				if($headNounMI =~ /^PP/)
				{
					if(!&isCongruentPronoun($headNoun, $finiteVerb))
					{
						&setVerbform($relClause,0);
					}
					else
					{
						&setVerbform($relClause,1);
					}
				}
				else # if not preceded by preposition nor local person
				{ 
					# if no congruence, head noun is not subject of relative clause -> attributive, not applicable for proper names (those don't indicate number), so if lemma was splitted from a complex name -> ignore number
					if(!&isCongruentHeadRelClause($headNoun, $finiteVerb) && $headNounLem !~ /_/)
					{
						&setVerbform($relClause,0);
					}
					# else, if person is non-local & number of head noun and verb are the same, 
					# check verb frame from lexicon
					else
					{
					#get verb lemma
					my $mainVerb = &getMainVerb($relClause);
					if($mainVerb)
					{
						my $lem = $mainVerb->getAttribute('lem');
					#	print STDERR "verb:$lem ";
								
						if(exists $lexEntriesWithFrames{$lem})
						{
							my @frameTypes = @{$lexEntriesWithFrames{$lem}};
							#print STDERR @frameTypes;
							#print STDERR "\n\n";
							# if there is only one verb frame in the lexicon, assume this is the actual verb frame in this relative clause
							if(scalar(@frameTypes) == 1)
							{
								my $frame = @frameTypes[0];
								&evaluateSingleFrame($relClause, $frame, $lem, $headNounLem);
							}
							elsif(scalar(@frameTypes) > 1)
							{
#								print STDERR "$lem:\n";
#								foreach my $frame (@frameTypes)
#								{
#									print STDERR "$frame\n";	
#								}
#								print STDERR "\n";

								for (my $i=0;$i<scalar(@frameTypes);$i++)
							 	{
						 			my $frame = @frameTypes[$i];
						 			
						 			#if d-obj or iobj present, delete all intransitive frames
						 			if($frame =~ /[BCD].+default|A.+#(anticausative|resultative|intransitive|passive)/ && (&hasDobj($relClause) || &hasIobj($relClause)) )
						 			{# print "delete $frame\n";
						 				splice(@frameTypes,$i,1);
						 				$i--;
						 			}
						 		
						 			# disambiguate cases with type='object-extension', only 3 lemmas: caminar, correr, navegar
						 			elsif($frame =~ /object_extension/)
						 			{
						 				if($lem =~ /caminar|correr/ && ($headNounLem =~ /paso|camino|metros|legua|milla/))
						 				{
						 					&setVerbform($relClause,0);
						 					undef(@frameTypes);
						 					last;
						 				}
						 				elsif($lem =~ /navegar/ && $headNounLem =~ /espacio/)
						 				{
						 					&setVerbform($relClause,0);
						 					undef(@frameTypes);
						 					last;
						 				}
						 				else
						 				{
						 					splice(@frameTypes,$i,1);
						 					$i--;
						 				}
						 			}
						 		
						 			elsif($frame =~ /#(anticausative|passive|impersonal)/)
						 			{
						 				# if no 'se', delete frames 'inergative', 'anticausative', 'passive' and 'impersonal'
						 				# note that passives with ser+participles are handled above, so we have to consider only medio-passives with 'se' here
						 				# 'la casa que se vendió..'
						 				if(!&hasRflx($relClause))
						 				{
						 					splice(@frameTypes,$i,1);
						 					$i--;
						 				}
						 				# if rel-clause contains a verbform with 'se', head noun is subject if anticausative
										# -el hombre que se afeita
										# else if se + impersonal -> head noun is NOT subject
						 				# BUT passive: las casas que se venden (verb matches number of casas), yet casa is not agent
										# so verbform should be attributive (rantinan wasikuna, not rantiq wasikuna)
										# -> some verbs have anticausative AND passive frames, but in those cases, the passive is NOT a 'se' form (e.g. dañarse (antic) vs ser dañado)
						 				else
						 				{
						 					# if 'se' and no impersonal or passive frame: either anticausative or reflexive -> head noun is agent
						 					# NOTE: 6 verbs have anticausative AND impersonal frames (cambiar, despreciar, esperar, hacer, reconstruir, retirar)
						 					# in those cases: take anticausative as default
						 					
						 					#check if parser has labeled 'se' as 'impers' -> in this case: not agentive
						 					if($relClause->exists('NODE/NODE[@lem="se" and @rel="impers"]'))
						 					{
						 						&setVerbform($relClause,0);
						 						undef(@frameTypes);
						 						last;						 						
						 					}	
						 					
						 					# if no passive/impersonal frames-> anticausative or reflexive ('el hombre que se afeita'): agentive
						 					elsif(!grep {$_ =~ /impersonal|passive/} @frameTypes)
						 					{
						 						&setVerbform($relClause,1);
						 						undef(@frameTypes);
						 						last;
						 					}
						 					#else, if se+impersonal or se+passive
						 					# -> head noun is not agent, unless there's a sp-obj..then it's probably a reflexive use and head noun is agent (?)
						 					else
						 					{
						 						if(&hasDorSPobj($relClause))
						 						{
						 							&setVerbform($relClause,1);
						 						}
						 						else
						 						{
						 							&setVerbform($relClause,0);
						 						}
						 						undef(@frameTypes);
						 						last;
						 					}
						 				}
						 			}
						 			
						 			# if transitive frame and d-obj present but no iobj, evaluate as transitive
						 			elsif($frame =~ /A(1|2).+default|[BCD].+#causative|D.+(cognate_object|object_extension)/ && &hasDobj($relClause) && !&hasIobj($relClause))
						 			{
						 				&evaluateSingleFrame($relClause, $frame);
						 				undef(@frameTypes);
						 				last;
						 			}
						 		
						 			# ditransitive verbs (A31-35): if iobj is head noun, rel. prn is 'a que', 'a quien'
						 			# -> only disambiguation needed for subj/obj -> if 'que/quien' rel-clause and no iobj
						 			# -> not ditransitive
						 			# if iobj present: select ditransitive frame for this clause & evaluate
						 			elsif($frame =~ /A3.+default/)
						 			{
							 			if(&hasIobj($relClause))
						 				{
						 					&evaluateSingleFrame($relClause, $frame);
						 					undef(@frameTypes);
						 					last;
						 				}
						 				#if no iobj, but dobj, and no transitive frame present: evaluate this frame (can happen with e.g. decir, mostrar: those have only transitive
						 				# frame, yet they can occur onyl with a complement clause (no iobj))
						 				elsif(&hasDorSPobj($relClause) && !grep {$_ =~ /A1|A2/} @frameTypes )
						 				{
						 					&evaluateSingleFrame($relClause, $frame);
						 					undef(@frameTypes);
						 					last;
						 				}
						 				# else, delete frame, unless it's the only frame left
						 				else
						 				{
						 					if(scalar(@frameTypes) > 1)
						 					{
						 						splice(@frameTypes,$i,1);
						 						$i--;
						 					}
						 				}
						 			}
						 		
						 		}
						 
								# cases, where verb has more than 1 frame and neither subj nor obj are present as np in rel-clause	
								if(@frameTypes)
								{ 
#									print STDERR "frames left for $lem:\n";
#									foreach my $frame (@frameTypes)
#									{
#										print STDERR "$frame\n";	
#									}
#									print STDERR "\n";
									if(scalar(@frameTypes) == 1)
									{ 
										my $frame = @frameTypes[0];
										#print "single frame: $frame\n";
										&evaluateSingleFrame($relClause, $frame);
									}
									elsif(scalar(@frameTypes) > 1)
									{ 
										my $semTag;
										# get semantic tag of head noun, assume it's the first word in the name (except for articles). 
										# Note that in this case, we have only the word form, so e.g. plural won't be found in noun lexicon
										if($headNounLem =~ /_/)
										{
											my @firstLem = split ( '_', $headNounLem);
											#print STDERR "$firstLem[0]\n";
											$semTag = $nounLexicon{$firstLem[0]};
										}
										else
										{
											 $semTag = $nounLexicon{$headNounLem};
										}
										#print STDERR "semtag: $semTag\n";
										# if subject thematic roles of all frames are agt/cau
										# -> check if semantics of noun matches thematic roles of agent/causer
										# one exception: C11 with 'tem' should be agentive as well
										#print "$lem: @frameTypes\n";
										if($semTag && !grep {$_ =~ /##(exp|src|ins|loc|pat)/} @frameTypes)
										{ 
											# no 'tem' in frameTypes: check if head noun matches for agentive semantics
											if(!grep {$_ =~ /##tem/} @frameTypes)
											{
												# check if creg/obj in rel-clause, in this case, assume head is subject-> according to frame->agentive
												if(!&hasSubjRel($relClause) and (&hasDorSPobj($relClause) or &hasIobj($relClause) ))
												{
													&setVerbform($relClause,1);
												}
												elsif($semTag =~ /ani|soc|hum|pot/)
												{
													&setVerbform($relClause,1);
												}
												else
												{
													&setVerbform($relClause,0);
												}
											}
											#if 'tem' is in a C11 frame, assume agentive
											elsif(grep {$_ =~ /##tem/} @frameTypes)
											{
												#if only with C11
												if(!grep {$_ =~ /([BD]|C[234]).+##tem/} @frameTypes)
												{
													if(&hasRflx($relClause))
													{
														&setVerbform($relClause,0);
													}
													else
													{
														&setVerbform($relClause,1);
													}
												}
												else
												{
													&guess($relClause,\@frameTypes,$semTag);
												}
											}
										}
										# if only pat/tem and tem not with C11 -> not agentive
										elsif($semTag && !grep {$_ =~ /##(exp|src|ins|loc|agt|cau)/} @frameTypes && !grep {$_ =~ /C11.+##tem/} @frameTypes)
										{
											&setVerbform($relClause,0);
										}
								
										# else: not really resolvable, take a guess:
										# TODO: or is better to this unresolved, generate all possibilities and let the language model decide which one's best?
										else
										{
											if($semTag)
											{
												&guess($relClause,\@frameTypes,$semTag);
											}
											#noun not in lexicon, if NP00SP0 -> hum, else: guess its a unanimated common noun (cnc)
											else
											{ 
												if($headNounMI eq 'NP00SP0')
												{
													$semTag = 'hum';
													&guess($relClause,\@frameTypes,$semTag);
												}
												elsif($headNounMI eq 'NP00O00')
												{
													$semTag = 'soc';
													&guess($relClause,\@frameTypes,$semTag);
												}
												else
												{ 
													$semTag = 'cnc';
													&guess($relClause,\@frameTypes,$semTag);
												}
											}
										}
									}
								}
							}
						}
					}
					}
				}
			}
			}
		}
	}
	}
}

#
## print new xml to stdout
my $docstring = $dom2->toString(1);
##print $dom->actualEncoding();
print STDOUT $docstring;




sub isCongruentPronoun{
	my $prsprn = $_[0];
	my $finiteVerb = $_[1]; 
	if($prsprn && $finiteVerb)
	{
		my $verbMI = $finiteVerb->getAttribute('mi');
		my $prnMI = $prsprn->getAttribute('mi');	
		my $verbprs = substr ($verbMI, 4, 1);
		my $verbnbr = substr ($verbMI, 5, 1);	
		my $pronounprs = substr ($prnMI, 2, 1);
		my $pronounnbr = substr ($prnMI, 4, 1);
	
		#print STDERR "$prnMI: prs:$pronounprs, nbr: $pronounnbr, $verbMI: prs:$verbprs nbr: $verbnbr\n";
		return ($pronounprs eq $verbprs && $pronounnbr eq $verbnbr);
	}
	#this shouldn't happen
	else
	{
		print STDERR "failed to check congruency of pronoun and finite verb (no verb or no pronoun)\n";
	}

}

sub setVerbform {
	my $verbchunk = $_[0];
	my $isSubj = $_[1];
	
	#in case of coordination (la casa que pintamos y edificamos): 
#	  <NODE ord="2" form="casa" lem="casa" pos="nc" cpos="n" rel="suj" mi="NCFS000">
#          <NODE ord="1" form="La" lem="el" pos="da" cpos="d" head="2" rel="spec" mi="DA0FS0"/>
#        </NODE>
#        <CHUNK type="grup-verb" si="S" idref="4" ord="3">
#          <NODE ord="4" form="pintamos" lem="pintar" pos="vm" cpos="v" rel="S" mi="VMIP1P0">
#            <NODE ord="3" form="que" lem="que" pos="pr" cpos="p" head="4" rel="suj" mi="PR00C000"/>
#            <NODE ord="5" form="y" lem="y" pos="cc" cpos="c" head="4" rel="coord" mi="CC"/>
#          </NODE>
#          <CHUNK type="grup-verb" si="S" idref="6" ord="4">
#            <NODE ord="6" form="edificamos" lem="edificar" pos="vm" cpos="v" rel="S" mi="VMIP1P0"/>
#          </CHUNK>
#        </CHUNK>
#      </CHUNK>
	
	if($verbchunk && $isSubj != 2)
	{
		my @verbforms =();
		my $firstverb = @{$verbchunk->findnodes('child::NODE[@pos="vm"][1]')}[-1];	
		my @coordVerbs = $verbchunk->findnodes('child::NODE[@rel="coord"]/following-sibling::CHUNK[@type="grup-verb" and (@si="S" or @si="cn")]/NODE[@pos="vm"]');
		if($firstverb && scalar(@coordVerbs)>0)
		{
			@verbforms = ($firstverb, @coordVerbs);
		}
		elsif($firstverb)
		{
			push (@verbforms, $firstverb);
		}

		foreach my $verbform (@verbforms)
		{
			# before setting verbform=agentive, check if really congruent-> in case of false attached coordinated verbs-> if not congruent, this verb does not belong to the relclause
			if($isSubj == 1)
			{
				my $headnoun = &getHeadNoun($verbchunk);
				my $verbMI = $verbform->getAttribute('mi');

				if($verbMI =~ /1|2|3/ && $headnoun &&&isCongruentHeadRelClause($headnoun, $verbform))
				{
					$verbform->setAttribute('verbform', 'rel:agentive');
				}
				# if main verb is non-finite
				else
				{
					my $finiteVerb = &getFiniteVerb($verbchunk);
					if($finiteVerb && $headnoun &&  $finiteVerb->getAttribute('mi') =~ /1|2|3/ &isCongruentHeadRelClause($headnoun, $finiteVerb))
					{
						$verbform->setAttribute('verbform', 'rel:agentive');
					}	
				}
			}
			else
			{
				$verbform->setAttribute('verbform', 'rel:not.agentive');
			}
		}
	}
	elsif($verbchunk &&$isSubj == 2)
	{
		my @verbforms = $verbchunk->findnodes('child::CHUNK/NODE[@pos="vs"]');
		foreach my $verbform (@verbforms)
		{
				$verbform->setAttribute('verbform', 'rel:agentive');
		}
	}
}


sub evaluateSingleFrame{
	my $relClause = $_[0];
	my $frame = $_[1];
	my $lem = $_[2];
	my $headNounLem = $_[3];
	
	$frame =~ /##(.+)/;
	my $thematicRoleOfSubj = $1;
	
	my $semTag = $nounLexicon{$headNounLem};			
	
	if($relClause)
	{
	#if intransitive, head noun is subj
	#lss's: 
	#"B11.unaccusative-motion"
	#"B12.unaccusative-passive-ditransitive"
	#"B21.unaccusative-state"
	#"B22.unaccusative-passive-transitive"
	#"B23.unaccusative-cotheme"
	#"B23.unaccusative-theme-cotheme"
	#"C11.state-existential"
	#"C21.state-attributive"
	#"C31.state-scalar"
	#"C41.state-benefective"
	#"C42.state-experiencer"
	#"D11.inergative-agentive"
	#"D21.inergative-experiencer"
	#"D31.inergative-source"
	#
	# Axx+type=passive, A11,A12,A13+anticausative, Axx+resultative, A21-23+intransitive
	if($frame =~ /[BCD].+default|A.+#(anticausative|resultative|intransitive)/)
	{
		# if thematic role of subj is agentive 
		#(agent, causer, experiencer, source (e.g. chillar, escupir), instrument, locative (not clear why labeled locative, seem to be abstract nouns))
		if($thematicRoleOfSubj =~ /agt|cau|exp|src|ins|loc/)
		{
			&setVerbform($relClause,1);
		}
		# C11-verbs, thematicrole is 'tem', but they are agentive, e.g. el sol que arde, la lágrima que brotó de sus pupilas, etc
		elsif($thematicRoleOfSubj eq 'tem' && $frame =~ /C11/)
		{
			&setVerbform($relClause,1);
		}
		# else: pat or tem (patient or theme)
		else
		{
			&setVerbform($relClause,0);
		}
		
	}
	#if impersonal: head noun cannot be subject (probably: no impersonal rel-clauses without preposition possible)
	elsif($frame =~ /impersonal|passive/)
	{
		&setVerbform($relClause,0);
	}
	#if transitive
	#"A11.transitive-causative"
	#"A12.diransitive-causative-state"
	#"A13.ditransitive-causative-instrumental"
	#"A21.transitive-agentive-patient"
	#"A22.transitive-agentive-theme"
	#"A23.transitive-agentive-extension"	
	# B11,B21+causative, C+causative, D+causative/cognate object/object extension
	elsif($frame =~ /A(1|2).+default|[BCD].+(#causative|#benefactive)|D.+(cognate_object|object_extension)/)
		{
			#check if object is contained in relative clause 
			#-> if yes, head noun is subj
			#-> if no, head noun is obj
			if(&hasDorSPobj($relClause))
			{
				# if agentive
				if($thematicRoleOfSubj =~ /agt|cau|exp|src|ins|loc/)
				{
					&setVerbform($relClause,1);
				}
				# else if pat/tem
				else
				{
					&setVerbform($relClause,0);
				}
			}
			elsif(&hasSubjRel($relClause))
			{
				&setVerbform($relClause,0);
			}
			#no overt subj nor obj: check if head noun can be subj semantically
			# see 'la mujer que come' vs. 'la manzana que come'
			else
			{
				&evaluateSemTags($frame,$thematicRoleOfSubj,$semTag,$relClause, $lem, $headNounLem);
			}
							
		}
	#ditransitive
	#"A31.ditransitive-patient-locative"
	#"A32.ditransitive-patient-benefactive"
	#"A33.ditransitive-theme-locative"
	#"A34.ditransitive-patient-theme"
	#"A35.ditransitive-theme-cotheme"
	elsif($frame =~ /A3.+default/)
		{
			if(&hasSubjRel($relClause))
			{
				&setVerbform($relClause, 0);
			}
			# ditransitive: if head noun is iobj, rel-prn with 'a' (la casa A LA que pusieron una techa, no *la casa que pusieron techa) 
			#-> we only need to disambiguate between the cases where the head noun is obj or subj (e.g. la casa que dieron a Jośe vs. el hombre que dio la casa a José)		
			# if rel-clause has overt subj but no obj -> head noun is obj
			elsif(!&hasSubjRel($relClause) && $relClause->exists('CHUNK[@si="ci" or @si="creg" or @si="cd-a" or @si="cd" or @si="cd/ci"]'))
			{
				# if agentive
				if($thematicRoleOfSubj =~ /agt|cau|exp|src|ins|loc/)
				{
					&setVerbform($relClause,1);
				}
				# else if pat/tem
				else
				{
					&setVerbform($relClause,0);
				}
			}
			# no overt subj, no obj in rel-clause -> need to test if head noun is semantically possible subject
			# see the difference in 'la manzana que come' vs. 'el hombre que come'
			else
			{ 
				&evaluateSemTags($frame,$thematicRoleOfSubj,$semTag,$relClause, $lem, $headNounLem);
			}
		}
	}
}
	
# if no overt subj and obj, and verb number/person = number/person of head noun
# try to find out if head is subj/obj (actually agentive/non-agentive) 
# by comparing the thematic role of the subject in the verb frame and the semantic tag from the noun lexicon

	# thematic roles (subject) Ancora, semantic labels:
	# 'agentive':
	# agt (agent): 					ani, hum, pot, soc
	# cau (causer):   				ani, hum, pot, soc
	# exp (experiencer):			ani, hum, soc
	# src (source):					ani, hum, (cnc)		('chillar, destellar, escupir, relucir' -> src=person/thing)
	# ins (instrument):				cnc, mat, pot
	# loc (locative (??), abstract inanimate):	abs, loc, cnc, sem
	#
	# 'not agentive':
	# pat (patient,passives):			all, except with C11: agentive
	# tem (theme, unaccusat./anticaus.):	all

sub	evaluateSemTags{
	my $frame = $_[0];
	my $thematicRoleOfSubj = $_[1];
	my $semTag = $_[2];
	my $relClause = $_[3];
	my $lem = $_[4];
	my $headNounLem = $_[5];
	
	if($relClause)
	{
		if($thematicRoleOfSubj =~ /agt|cau/ && $semTag =~ /ani|soc|hum|pot/)
		{
			&setVerbform($relClause,1);
		}
		elsif($thematicRoleOfSubj =~ /exp/ && $semTag =~ /ani|soc|hum/)
		{
			&setVerbform($relClause,1);
		}
		elsif($thematicRoleOfSubj =~ /src/ && $semTag =~ /ani|hum/)
		{
			&setVerbform($relClause,1);
		}
		# extremely rare, onyl with lemmas: relucir, destellar, crujir, olear (solo mar (?), pegar (solo gritos), romper (extremely rare))
		elsif($thematicRoleOfSubj =~ /src/ && $semTag =~ /cnc/)
		{
			if($lem =~ /crujir|destellar|relucir/ || ($lem eq 'olear' && $headNounLem eq 'mar') )
			{
				&setVerbform($relClause,1);
			}
			elsif( $lem eq 'pegar' && $headNounLem eq 'grito')
			{
				&setVerbform($relClause,0);
			}	
		}
		elsif($thematicRoleOfSubj eq 'ins' && $semTag =~ /cnc|mat|pot/)
		{
			&setVerbform($relClause,1);
		}
		elsif($thematicRoleOfSubj eq 'loc' && $semTag =~ /abs|loc|cnc|sem/)
		{
			&setVerbform($relClause,1);
		}
		#else, if thematic role is pat/tem:  never agentive
		# or if head noun does not 'match' thematic role (e.g. abstract noun as agent): not agentive 
		# (note: this assumption will not be correct in all cases!)
		else
		{
			&setVerbform($relClause,0);
		}
	}
}			

sub guess{
	my $relClause = $_[0];
	my $frameTypes = $_[1];
	my $semTag = $_[2];
	
	if($relClause)
	{
		#$relClause->setAttribute('guess','1');
		if(&hasSubjRel($relClause))
		{
			&setVerbform($relClause,0);
		}
		elsif(&hasDorSPobj($relClause) || &hasIobj($relClause))
		{
			&setVerbform($relClause,1);
		}
		# if a A frame is present & head noun is hum, soc, pot or animated -> agentive, else not agentive
		elsif(grep {$_ =~ /##agt/} @{$frameTypes})
		{
			if($semTag =~ /ani|soc|hum|pot/)
			{
				&setVerbform($relClause,1);
			}
			# if parser labeled relprn as 'suj' -> guess its agentive
			elsif($relClause->exists('descendant::NODE[@pos="pr" and @rel="suj"]'))
			{
				&setVerbform($relClause,1);
			}
			else
			{
				&setVerbform($relClause,0);
			}
		}
		# if parser labeled relprn as 'suj' -> guess its agentive
		elsif($relClause->exists('descendant::NODE[@pos="pr" and @rel="suj"]'))
		{
			&setVerbform($relClause,1);
		}
		else
		{
			&setVerbform($relClause,0);
		}
	}
}


sub hasSubjRel{
	my $relClauseNode = $_[0];
	#print STDERR "rel clause: \n".$relClauseNode->toString."\n";
	return ($relClauseNode->exists('CHUNK[@si="suj"]'));

}

sub hasDobj{
	my $relClauseNode = $_[0];
	
	return($relClauseNode->exists('CHUNK[@si="cd" or @si="cd-a" or @si="cd/ci"]') );

}

sub hasDorSPobj{
	my $relClauseNode = $_[0];
	
	return ($relClauseNode->exists('CHUNK[@si="cd" or @si="cd-a" or @si="creg" or @si="cd/ci"]') );
}

sub hasIobj{
	my $relClauseNode = $_[0];
	
	return ($relClauseNode->exists('CHUNK[@si="ci" or @si="cd-a" or @si="cd/ci"]') );
}

sub hasRflx{
	my $relClauseNode = $_[0];
	
	return($relClauseNode->exists('CHUNK/NODE[@lem="se"]'));
 }