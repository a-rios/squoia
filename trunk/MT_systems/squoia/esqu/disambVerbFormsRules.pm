#!/usr/bin/perl

package squoia::esqu::disambVerbFormsRules;
use utf8;                  # Source code is UTF-8
use strict;

my %nounLexicon;

my $nbrOfRelClauses =0;
my $nbrOfSwitchForms=0;
my $nbrOfNominalForms=0;
my $nbrOfFinalClauses=0;
my $nbrOfFiniteForms=0;
my $nbrOfAmbigousClauses=0;
my $nbrOfVerbChunks=0;
my $nbrOfNonFiniteChunks=0;

sub main{
	my $dom = ${$_[0]};
	my $evid = $_[1];
	%nounLexicon = %{$_[2]};

	my $corpus = @{$dom->getElementsByTagName('corpus')}[0];
	if($corpus){
		$corpus->setAttribute('evidentiality',$evid);
	}
	
	my @sentenceList = $dom->getElementsByTagName('SENTENCE');
		
	
	## TODO: indirect questions with PT -> preguntan cuán efectivo será.., preguntan cómo será..
	## TODO: verbchunks as arguments of nouns: la esperanza de que se sane, el esterotipo de que las mujeres hablan mucho,
	##    la necesidad de que se registren, la prueba de que existen, etc
	## querer saber -> indirect question
	## verse +adj/participio -> 'kan', 
	## resultar +adj, participio -> -sqa, but 'resulta claro que eso afecta a la población..' -> infinitive?
	## subject clauses -> es posible que no pueden seguir produciendo
	## done - según + verbo -> cómo se traduce? -sqaman hina
	## al + infinitive -> spa/pti
	
	foreach my $sentence (@sentenceList)
	{
		# get all verb chunks and check if they have an overt subject, 
		# if they don't have an overt subject and precede the main clause -> look for subject in preceding sentence
		# if they don't have an overt subject and follow the main clause, and the main clause has an overt subject, this is the subject of the subordinated chunk
		#print STDERR "Disambiguating verb form in sentence: ".$sentence->getAttribute('ord')."\n";
		
	 	
	 	# consider linear sequence in sentence; in xml the verb of the main clause comes always first, but in this case the subject of a preceding subordinated clause is probably coreferent with the subject of the preceding clause
	 	my @verbChunks = $sentence->findnodes('descendant::CHUNK[@type="grup-verb" or @type="coor-v"]');
	 	$nbrOfVerbChunks = $nbrOfVerbChunks+scalar(@verbChunks);
#	 	#print STDERR "$nbrOfVerbChunks\n";
#	 	
	 	foreach my $verbChunk (@verbChunks)
	 	{
	 		#print STDERR "disambiguating verb chunk: ".$verbChunk->getAttribute('ord')."\n";
	 		if(squoia::util::getFiniteVerb($verbChunk))
	 		{
	 			# disambiguation needed only if not relative clause (those are handled separately)
	 			if( !squoia::util::isRelClause($verbChunk) && !$verbChunk->hasAttribute('verbform'))
	 			{ #print STDERR "disambiguating verb chunk: ".$verbChunk->getAttribute('ord')."\n";
	 				my $conjunction;
	 				# get conjunction, if present:
	 				#  if coordinated, get the conjunction from head of coordination, unless this verb has its own conjunction 
	 				# -> in this case, the parser messed up, take the conjunction of this verb, not the head (but we don't really know which one is right)
	 				if($verbChunk->exists('parent::CHUNK[@type="coor-v"]') && !$verbChunk->exists('child::NODE[@cpos="v"]/NODE[@pos="cs" or @pos="cc"]') )
	 				{ 
	 					$conjunction = @{$verbChunk->findnodes('parent::CHUNK[@type="coor-v"]/NODE[@cpos="v"]/NODE[@pos="cs" or @pos="cc"]')}[0];
	 				}
	 				elsif($verbChunk->getAttribute('si') ne 'top' || $verbChunk->exists('parent::CHUNK[@type="coor-v"]') && $verbChunk->exists('child::NODE[@cpos="v"]/NODE[@pos="cs" or @pos="cc"]'))
	 				{
	 					$conjunction = @{$verbChunk->findnodes('child::NODE[@cpos="v"]/NODE[@pos="cs" or @pos="cc"]')}[0];
	 				}
	 				# mientras, aún no -> might be RG
	 				if(!$conjunction && $verbChunk->exists('child::CHUNK/NODE[@lem="mientras" or @lem="aun_no" or @lem="aún_no"]')){
	 					($conjunction) = $verbChunk->findnodes('child::CHUNK/NODE[@lem="mientras" or @lem="aun_no" or @lem="aún_no"][1]');
	 				}
	 				if($conjunction){
	 					#print STDERR "conj in ".$verbChunk->getAttribute('ord').": ".$conjunction->toString()."\n";
	 					#print STDERR "lem: ".$conjunction->getAttribute('lem')."\n";
	 				}
	 				
	 				#if this is a coordinated verb to a relative clause that somehow has no verbform yet, just copy verbform from head to this chunk
	 				if($verbChunk->exists('parent::CHUNK[@type="coor-v"]/NODE[starts-with(@verbform,"rel")]') && $verbChunk->exists('descendant::NODE[@pos="pr"]') )
	 				{
	 					my $parent = $verbChunk->parentNode();
	 					if($parent){
	 						$verbChunk->setAttribute('verbform', $parent->getAttribute('verbform'));
	 						my $guessed = $parent->hasAttribute('guessed');
							if($guessed){$verbChunk->setAttribute('guessed', '1');}
	 					}	
	 				}
	 				# if this verb has a 'tener que' part or deber +inf -> obligative, TODO: hay que?
	 				elsif($verbChunk->exists('child::NODE[@cpos="v"]/NODE[@lem="tener"]/NODE[@lem="que" and @pos="cs"]') || $verbChunk->exists('child::NODE[@cpos="v"]/NODE/NODE[@lem="tener"]/NODE[@lem="que" and @pos="cs"]') || ($verbChunk->exists('child::NODE[@mi="VMN0000"]/NODE[@lem="tener"]') && $verbChunk->exists('child::NODE[@mi="VMN0000"]/NODE[@lem="que"]') ) || $verbChunk->exists('child::NODE[@mi="VMN0000"]/NODE[@lem="deber"]')  )
	 				{
	 					$nbrOfFinalClauses++;
	 					$verbChunk->setAttribute('verbform', 'obligative');
	 				}
	 				# if this is hay/había/habrá que + infinitive -nan kan
	 				# note that parser can attach 'que' to 'hay' but also to infinitive! 
	 				elsif(( $verbChunk->exists('child::NODE[@lem="haber" and contains(@mi,"3")]') && $verbChunk->exists('child::CHUNK/NODE[@mi="VMN0000"]/NODE[@lem="que" or @lem="de"]') ) || ( ($verbChunk->exists('child::NODE[@lem="haber" and contains(@mi,"3")/NODE[@lem="que"]]') || $verbChunk->exists('child::NODE[@lem="haber" and contains(@mi,"3")/following-sibling::NODE[@lem="que"]]') ) && $verbChunk->exists('child::CHUNK/NODE[@mi="VMN0000"]') ) )
	 				{ 
	 					$nbrOfFiniteForms++;
	 					$verbChunk->setAttribute('verbform','main');
	 					#$verbChunk->setAttribute('delete','yes');
	 					# get infintive of main verb and set this form to obligative
	 					my $infinitiveWithQUE = @{$verbChunk->findnodes('child::CHUNK[NODE[@mi="VMN0000"]/NODE[@lem="que"]][1]')}[0];
	 					my $infinitiveWithoutQUE = @{$verbChunk->findnodes('child::CHUNK[NODE[@mi="VMN0000"]][1]')}[0];
	 					if($infinitiveWithQUE)
	 					{
	 						$nbrOfFinalClauses++;
	 						$infinitiveWithQUE->setAttribute('verbform', 'obligative');
	 						$infinitiveWithQUE->setAttribute('addverbmi', '+3.Sg.Poss');
	 					}
	 					elsif($infinitiveWithoutQUE)
	 					{
	 						$nbrOfFinalClauses++;
	 						$infinitiveWithoutQUE->setAttribute('verbform', 'obligative');
	 						$infinitiveWithoutQUE->setAttribute('addverbmi', '+3.Sg.Poss');
	 					}
	 				} 			
	 				# if this is a passive clause with 'ser'/'estar'
	 				elsif($verbChunk->exists('child::NODE[starts-with(@mi,"VMP")]/NODE[@lem="ser" or @lem="estar"]'))
	 				{
	 					$verbChunk->setAttribute('verbform', 'passive');
	 				}
	 				# if this is a topicalization with 'ser' -> delete verb, but insert a topic marker
	 				# -> es ahí donde viven -> kaypiQA kawsanku
	 				elsif($verbChunk->exists('child::NODE[@lem="ser"]') && $verbChunk->findvalue('child::CHUNK[@type="sadv"]/NODE/@lem') =~ /ahí|allá|aquí/ && $verbChunk->exists('descendant::NODE[@lem="donde"]') )
	 				{
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
	 				# if this is a subordinated clause with 'cuando..'-> switch-reference forms (desr sometimes makes the sub-clause the main clause)
	 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /^cuando$|aún_cuando|aun_cuando|aunque|a_pesar_de_que|porque|con_tal_que|con_tal_de_que|en_cuanto|tan_pronto_como|una_vez_que|después_de_que|después_que/ )
	 				{
	 					#check if same subject 
	 					&compareSubjects($verbChunk);
	 					if($conjunction->getAttribute('lem') =~ /porque|con_tal_que|con_tal_de_que/ )
	 					{
	 						$nbrOfSwitchForms++;
	 						if($sentence->getAttribute('evidentiality') eq 'indirect'){z
	 							$verbChunk->setAttribute('chunkmi', '+IndE');
	 						}
	 						else{
	 							$verbChunk->setAttribute('chunkmi', '+DirE');
	 						}
	 					}
	 					elsif($conjunction->getAttribute('lem') =~ /aunque|a_pesar_de_que|bien|bien_si|si_bien/ )
	 					{
	 						$nbrOfSwitchForms++;
	 						$verbChunk->setAttribute('chunkmi', '+Add');
	 					}
	 					# if no SS/DS could be resolved (e.g. if main verb was not found): set to switch
	 					if(!$verbChunk->hasAttribute('verbform')){
	 						$verbChunk->setAttribute('verbform' ,'switch');
	 					}
	 				}
	 				# with conque, switch +Top
	 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /^conque$/ )
	 				{
	 					#check if same subject 
	 					&compareSubjects($verbChunk);
	 					$nbrOfSwitchForms++;
	 					$verbChunk->setAttribute('chunkmi', '+Top');
	 				}
	 				# with si: conditional, main  chayqa (and sichus?), but note: might also be an indirect question ('preguntaron si compraste la casa')
	 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /^si|a_condición_de_que$/ && !$verbChunk->exists('parent::CHUNK[@type="grup-verb" or @type="coor-v"]/NODE[@lem="preguntar" or @lem="interrogar"]') )
	 				{
	 					#check if same subject 
	 					$verbChunk->setAttribute('verbform', 'main');
	 					$verbChunk->setAttribute('conj', 'sichus');
	 					$verbChunk->setAttribute('conjHere', 'yes');
	 					$verbChunk->setAttribute('conjLast', 'chayqa');
	 				}
	 				# if this is a subordinated clause with 'sin_que..'-> DS form 
	 				# -> in same subject contexts, verb would be infinitive
	 				# -> me fui sin que lo notaran (DS), me fui sin notarles (SS)
	 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /sin_que/ )
	 				{
	 					$nbrOfSwitchForms++;
	 					$verbChunk->setAttribute('verbform', 'DS');
	 					$verbChunk->setAttribute('conj', 'mana');
	 				}
	 				# antes de que haga -> manaraq + finite verb -> DS (if SS -> verb would be infinitive)
	 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /antes_de_que/ )
	 				{
	 					$nbrOfSwitchForms++;
	 					$verbChunk->setAttribute('verbform', 'DS');
	 					$verbChunk->setAttribute('conj', 'manaraq');
	 				}
	 				# if this a subordinated  clause with a finite verb (in Quechua) (TODO: ni_siquiera -> Adverbio??)
	 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /pero|empero|^o$|^y$|y_cuando|^e$|^u$|sino|^ni$|ni_siquiera|por_tanto|por_lo_tanto|tanto_como|entonces|pues|puesto_que|por_eso|debido_a_que|ya_que|dado_que|aun$|aún$|aun_no|aún_no|de_modo_que|así_que/ )
	 				{	
	 					# if coordinated chunk: take verbform from head
	 				    my $parent = $verbChunk->parentNode();
	 					if($parent && $conjunction && $conjunction->getAttribute('lem') =~ /^o$|^y$|^e$|^u$|sino|^ni$/ && $verbChunk->exists('parent::CHUNK[@type="coor-v"]'))
	 					{
	 						#print STDERR"\nsfhshfsjhfksh ".$verbChunk->getAttribute('ord')."\n";
	 						my $parentForm = $parent->getAttribute('verbform');
	 						if($parentForm ne ''){
	 							$verbChunk->setAttribute('verbform',$parentForm);
	 						}
	 						else{
	 							$verbChunk->setAttribute('verbform', 'main');
	 						}
	 						# -taq
		 					if($conjunction->getAttribute('lem') =~ /^o$|^y$|^e$|^u$/ )
		 					{
		 						$verbChunk->setAttribute('chunkmi', '+Intr');
		 					}
		 					#ni, ni_siquera: nitaq
		 					elsif($conjunction->getAttribute('lem') =~ /^ni$/ )
		 					{
		 						$verbChunk->setAttribute('conj', 'nitaq');
		 					}
		 					#sino: aswanpas
		 					elsif($conjunction->getAttribute('lem') =~ /sino/ )
		 					{
		 						$verbChunk->setAttribute('conj', 'aswanpas');
		 					}
	 					}
	 					else
	 					{
		 					$nbrOfFiniteForms;
		 					$verbChunk->setAttribute('verbform', 'main');
		 					if($conjunction->getAttribute('lem') eq 'pero_cuando' )
		 					{
		 						$verbChunk->setAttribute('conj', 'chaytaq');
		 					}
		 					elsif($conjunction->getAttribute('lem') =~ /pero|empero/ )
		 					{
		 						$verbChunk->setAttribute('conj', 'ichaqa');
		 					}
		 					# -taq
		 					elsif($conjunction->getAttribute('lem') =~ /^o$|^y$|^e$|^u$/ )
		 					{
		 						$verbChunk->setAttribute('chunkmi', '+Intr');
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
		 					elsif($conjunction->getAttribute('lem') =~ /entonces|pues|puesto_que/ )
		 					{
		 						$verbChunk->setAttribute('conj', 'hinaspaqa');
		 					}
		 					elsif($conjunction->getAttribute('lem') =~ /por_eso|debido_a_que/ )
		 					{
		 						$verbChunk->setAttribute('conj', 'chayrayku');
		 					}
		 					elsif($conjunction->getAttribute('lem') =~ /ya_que|de_modo_que|así_que/ )
		 					{
		 						$verbChunk->setAttribute('conj', 'hinaqa');
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
	 				}
	 				# nominal subordinated clauses (no complement clauses, those are treated below!)
	 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /^como$|al_igual_que/ )
	 				{
	 					$nbrOfNominalForms++;
	 					if(&isSubjunctive($verbChunk) or &isFuture($verbChunk))
	 					{
	 						$verbChunk->setAttribute('verbform', 'obligative');
	 					}
	 					else
	 					{
	 						$verbChunk->setAttribute('verbform', 'perfect');
	 					}
	 					# hazlo como te dije -> nisqayman hina ruway
	 					$verbChunk->setAttribute('chunkmi', '+Dat');
	 					$verbChunk->setAttribute('conjLast', 'hina');
	 				}
	 				# según -> -sqaman hina, según que (?)
	 				if($conjunction && $conjunction->getAttribute('lem') =~ /^según$|según_que/){
	 					$nbrOfNominalForms++;
	 					$verbChunk->setAttribute('verbform', 'perfect');
	 					$verbChunk->setAttribute('conjLast', 'hina');
	 					$verbChunk->setAttribute('chunkmi', '+Dat');
	 				}
	 				# if this is a final clause,  -na?
					elsif($conjunction && $conjunction->getAttribute('lem') =~ /^a_que$|al_tiempo_que|con_el_fin_de_que|con_fin_de_que|a_fin_de_que|con_objeto_de_que|con_objeto_que|al_objeto_de_que|conque|con_que|para_que|mientras|mientras_que|hasta_que/ && &isSubjunctive($verbChunk))
					{ 
						$nbrOfFinalClauses++;
						$verbChunk->setAttribute('verbform', 'obligative');
						if($conjunction->getAttribute('lem') =~ /mientras|hasta_que|al_tiempo_que/)
						{
							$verbChunk->setAttribute('case', '+Term');
						}
						else
						{
							$verbChunk->setAttribute('case', '+Ben');
						}
					}
					# mientras, mientras que -> na -kama/ -spa/-pti?
					elsif($conjunction && $conjunction->getAttribute('lem') =~ /mientras|al_tiempo_que/ )
					{
						$nbrOfFinalClauses++;
						$verbChunk->setAttribute('verbform', 'obligative');
						$verbChunk->setAttribute('case', '+Term');
					}
	 				# if this is a complement clause (-> nominal form), TODO: already ++Acc?
	 				elsif($verbChunk->exists('self::CHUNK[@si="sentence" or @si="cd" or @si="CONCAT" or @si="S"]/child::NODE[@pos="cs" and (@lem="que" or @lem="si" or @lem="el_hecho_de_que") or NODE[@pos="cs" and (@lem="que" or @lem="si") ]]') && $verbChunk->exists('parent::CHUNK[@type="grup-verb" or @type="coor-v"]') ) 
	 				{
	 					my $headVerbCHunk = @{$verbChunk->findnodes('parent::CHUNK[@type="grup-verb" or @type="coor-v"]')}[0];
	 					my @coordVerbChunks = $verbChunk->findnodes('self::CHUNK[@type="coor-v"]/CHUNK[@type="grup-verb"]');
	 					#print STDERR "\ncoords: ".scalar(@coordVerbChunks)." in ".$verbChunk->getAttribute('ord')."\n";
	 					
	 					if($headVerbCHunk)
	 					{
	 						my $headVerb = squoia::util::getMainVerb($headVerbCHunk);
	 						push(@coordVerbChunks,$verbChunk);
	 						#print STDERR "\nhead verb: \n".$headVerb->toString."\n";
	 						#print STDERR "this verb: ".$verbChunk->getAttribute('ord')."\n";
	 						# if this is a complement of a speech verb -> use direct speech, finite form, insert 'nispa' in head chunk
	 						#if($headVerb && $headVerb->getAttribute('lem') =~ /admitir|advertir|afirmar|alegar|argumentar|aseverar|atestiguar|confiar|confesar|contestar|comentar|decir|declarar|enfatizar|expresar|hablar|indicar|interrogar|manifestar|mencionar|oficiar|opinar|preguntar|proclamar|proponer|razonar|recalcar|revelar|responder|rogar|señalar|sostener|subrayar|testificar|testimoniar/)
	 						## TODO: 'querer saber si..'-> indirect question -> translate as tapuy?
	 						if($headVerb && $headVerb->getAttribute('lem') =~ /afirmar|alegar|argumentar|aseverar|comentar|decir|declarar|enfatizar|mencionar|responder|sostener|subrayar/ or ($headVerb->getAttribute('lem') =~ /preguntar|interrogar/ and $conjunction->getAttribute('lem') eq 'si' ) )
	 						{
	 							# check if subject of complement clause is the same as in the head clause, if so, person of verb should be 1st
								# e.g. Pedro dice que se va mañana - paqarin risaq, Pedro nispa nin.
								# note: if compareSubjects gives 'switch', this means that both verbs are 3rd persons and have the same number, but at least
								#  one of the clauses has no overt subject. It is safe to assume that in this case the subjects are coreferential with a say verb in the main clause
								# do this also for coordinated verb forms!
								foreach my $vChunk (@coordVerbChunks)
								{
									&compareSubjectsDirectSpeech($vChunk);
									#print STDERR "\ncoords: ".$vChunk->getAttribute('ord')."\n";
									# better default not SS
									# if(($vChunk->getAttribute('verbform') eq 'SS' || $vChunk->getAttribute('verbform') eq 'switch') && &isSingular($vChunk))
									if($vChunk->getAttribute('verbform') eq 'SS'  && &isSingular($vChunk))
									{
										$vChunk->setAttribute('verbprs', '+1.Sg.Subj')
									}
									elsif($vChunk->getAttribute('verbform') eq 'SS' && !&isSingular($vChunk))
									{
										$vChunk->setAttribute('verbprs', '+1.Pl.Excl.Subj')
									}
									# set both this verb and the head verb to 'main'
									$vChunk->setAttribute('verbform', 'main');
									#print STDERR $vChunk->toString."\n";
									
									# indirect question with 'si' -> add -chu to (now direct speech) verbchunk
									if($conjunction->getAttribute('lem') eq 'si')
									{
										$vChunk->setAttribute('chunkmi', '+Neg');
									}
									$nbrOfFiniteForms++;
									$nbrOfSwitchForms--;
								}
								$headVerbCHunk->setAttribute('lem1', 'ni');
								$headVerbCHunk->setAttribute('verbmi1', '+SS');
	 						}
	 						# titular: finite verb form, like direct speech, but no co-reference resolution needed
	 						elsif($headVerb && $headVerb->getAttribute('lem') =~ /titular/)
	 						{
	 							foreach my $vChunk (@coordVerbChunks)
								{
									$vChunk->setAttribute('verbform', 'main');
									$nbrOfFiniteForms++;
								}
	 						}
	 						else
	 						{	
	 							foreach my $vChunk (@coordVerbChunks)
	 							{ 
		 							$nbrOfNominalForms++;
		 							if(&isSubjunctive($vChunk) || &isFuture($vChunk) || &isConditional($vChunk))
		 							{
		 								$vChunk->setAttribute('verbform', 'obligative');
		 								$vChunk->setAttribute('case', '+Acc');
		 							}
		 							else
		 							{
		 								$vChunk->setAttribute('verbform', 'perfect');
		 								$vChunk->setAttribute('case', '+Acc');
		 							}
		 							# if linker = el_hecho_de_que -> add +Top
		 							if($vChunk->exists('NODE/NODE[@lem="el_hecho_de_que" or NODE[@lem="el_hecho_de_que"] ]')){
		 								$vChunk->setAttribute('chunkmi','+Top');
		 							}
	 							}
	 						}
	 					}
	 				}
	 			    # if this is a complement clause of a speech verb, no linker needed!
	 				elsif(!$conjunction && $verbChunk->exists('self::CHUNK[@si="sentence" or @si="cd" or @si="CONCAT" or @si="S"]') && $verbChunk->exists('parent::CHUNK[@type="grup-verb" or @type="coor-v"]') ) 
	 				{ 
	 					my $headVerbCHunk = @{$verbChunk->findnodes('parent::CHUNK[@type="grup-verb" or @type="coor-v"]')}[0];
	 					my @coordVerbChunks = $verbChunk->findnodes('self::CHUNK[@type="coor-v"]/CHUNK[@type="grup-verb"]');
	 					
	 					if($headVerbCHunk)
	 					{ 
	 						my $headVerb = squoia::util::getMainVerb($headVerbCHunk);
	 						push(@coordVerbChunks,$verbChunk);
	 						# if this is a complement of a speech verb -> use direct speech, finite form, insert 'nispa' in head chunk
	 						if($headVerb && $headVerb->getAttribute('lem') =~ /admitir|advertir|afirmar|alegar|argumentar|aseverar|atestiguar|comentar|confiar|confesar|contestar|decir|declarar|enfatizar|expresar|hablar|indicar|interrogar|manifestar|mencionar|oficiar|opinar|preguntar|proclamar|proponer|razonar|recalcar|revelar|responder|rogar|señalar|sostener|subrayar|testificar|testimoniar/)
	 						#if($headVerb && $headVerb->getAttribute('lem') =~ /admitir|advertir|aseverar|confesar|comentar|decir|declarar|enfatizar|expresar|hablar|mencionar|responder/)
	 						{
	 							# check if subject of complement clause is the same as in the head clause, if so, person of verb should be 1st
								# e.g. Pedro dice que se va mañana - paqarin risaq, Pedro nispa nin.
								# note: if compareSubjects gives 'switch', this means that both verbs are 3rd persons and have the same number, but at least
								#  one of the clauses has no overt subject. It is safe to assume that in this case the subjects are coreferential with a say verb in the main clause
								# NOTE: only with indirect speech, do not alter direct speech (when there's no 'que')
								# do this also for coordinated verb forms!
								foreach my $vChunk (@coordVerbChunks)
								{
									&compareSubjectsDirectSpeech($vChunk);
									#print "\ncoords: ".$vChunk->getAttribute('ord')."\n";
									#if(($vChunk->getAttribute('verbform') eq 'SS' || $vChunk->getAttribute('verbform') eq 'switch') && &isSingular($vChunk))
									# better: default not SS
									if($vChunk->getAttribute('verbform') eq 'SS'  && &isSingular($vChunk) && !$vChunk->exists('descendant::NODE[@form="se" or @form="Se"]'))
									{
										$vChunk->setAttribute('verbprs', '+1.Sg.Subj')
									}
									elsif($vChunk->getAttribute('verbform') eq 'SS' && !&isSingular($vChunk))
									{
										$vChunk->setAttribute('verbprs', '+1.Pl.Excl.Subj')
									}
									# set both this verb and the head verb to 'main'
									$vChunk->setAttribute('verbform', 'main');
									
									# indirect question with 'si' -> add -chu to (now direct speech) verbchunk
									if($conjunction && $conjunction->getAttribute('lem') eq 'si')
									{
										$vChunk->setAttribute('chunkmi', '+Neg');
									}
									$nbrOfFiniteForms++;
									$nbrOfSwitchForms--;
								}
								$nbrOfFiniteForms++;
								$nbrOfSwitchForms--;
	 						}
	 						# titular: finite verb form, like direct speech, but no co-reference resolution needed
	 						elsif($headVerb && $headVerb->getAttribute('lem') =~ /titular/)
	 						{ 
	 							foreach my $vChunk (@coordVerbChunks)
								{ 
									$vChunk->setAttribute('verbform', 'main');
									$nbrOfFiniteForms++;
								}
	 						}
	 						else
	 						{
	 							$nbrOfAmbigousClauses++;
								$verbChunk->setAttribute('verbform', 'ambiguous');
	 						}
	 					}
	 				}
	 				# if this is a complement clause with preposition (creg)-> nominal+case TODO: set proper case suffix! (probably best in prep-disamb)
	 				elsif($verbChunk->exists('parent::CHUNK[(@type="grup-sp" or @type="coor-sp") and @si="creg"]') && $verbChunk->exists('child::NODE/NODE[(@pos="cs" and @lem="que") or NODE[@pos="cs" and @lem="que" ]]')  && $verbChunk->exists('parent::CHUNK/parent::CHUNK[@type="grup-verb" or @type="coor-v"]') ) 
	 				{	
	 						$nbrOfNominalForms++;
	 						if(&isSubjunctive($verbChunk) || &isFuture($verbChunk) || &isConditional($verbChunk))
	 						{
	 							$verbChunk->setAttribute('verbform', 'obligative');
	 							#$verbChunk->setAttribute('case', '--');
	 						}
	 						else
	 						{
	 							$verbChunk->setAttribute('verbform', 'perfect');
	 							#$verbChunk->setAttribute('case', '--');
	 						}
	 				}
	 				# if this is a subject clause -> infinitive
	 				# que vengas tarde, me molesta 
	 				# que tal con puede ser que..? '(no) puede ser que eso se demora/e' TODO
	 				elsif($verbChunk->getAttribute('si') eq 'suj') 
	 				{
	 					my $headVerbCHunk = @{$verbChunk->findnodes('parent::CHUNK[@type="grup-verb" or @type="coor-v"]')}[0];
	 					if($headVerbCHunk)
	 					{
	 						my $headlem = squoia::util::getMainVerb($headVerbCHunk);
	 						if($headlem =~ /gustar|molestar|ser|dar_lo_mismo|dar_igual|importar|impresionar|decepcionar|parecer|joder|cansar|enervar/)
	 						{
		 						$verbChunk->setAttribute('verbform', 'infinitive');
		 						my $finiteVerb = squoia::util::getFiniteVerb($verbChunk);
		 						if($finiteVerb)
		 						{
		 						my $mi = $finiteVerb->getAttribute('mi');
		 						if($mi =~ '1S'){$verbChunk->setAttribute('infverbmi','+Inf+1.Sg.Poss')};
		 						if($mi =~ '2S'){$verbChunk->setAttribute('infverbmi','+Inf+2.Sg.Poss')};
		 						if($mi =~ '3S'){$verbChunk->setAttribute('infverbmi','+Inf+3.Sg.Poss')};
		 						if($mi =~ '1P'){$verbChunk->setAttribute('infverbmi','+Inf+1.Incl.Pl.Poss')};
		 						if($mi =~ '2P'){$verbChunk->setAttribute('infverbmi','+Inf+2.Pl.Poss')};
		 						if($mi =~ '3P'){$verbChunk->setAttribute('infverbmi','+Inf+3.Pl.Poss')};
		 						}
	 						}
	 						else{
	 							$verbChunk->setAttribute('verbform','ambiguous');
	 						}
	 					}
	 					else{
	 						$verbChunk->setAttribute('verbform','ambiguous');
	 					}
	 					
	 				}
	 				# el_hecho_de_que, desde que -> perfect +Top
	 				elsif( $conjunction && $conjunction->getAttribute('lem') =~ /el_hecho_de_que|desde_que|desde_el_momento_en_que/ )
	 				{
	 					$nbrOfNominalForms;
	 					$verbChunk->setAttribute('verbform', 'perfect');
	 					if($conjunction->getAttribute('lem') =~ /el_hecho_de_que/){
	 						$verbChunk->setAttribute('chunkmi', '+Top');
	 					}
	 					if($conjunction->getAttribute('lem') =~ /desde/){
	 						$verbChunk->setAttribute('chunkmi', '+Abl');
	 						$verbChunk->setAttribute('conjLast', 'pacha');
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
	 				# if there is a grup-verb above, check if there's a finite verb in it, if not, this chunk is probably not the main verb, make this chunk finite
	 				elsif($verbChunk->exists('ancestor::CHUNK[@type="grup-verb" or @type="coor-v"]'))
	 				{
	 					my @parentVChunks = $verbChunk->findnodes('ancestor::CHUNK[@type="grup-verb" or @type="coor-v"]');
	 					my $finite =0;
	 					foreach my $vchunk (@parentVChunks)
	 					{
	 						if(squoia::util::getFiniteVerb($vchunk))
	 						{
	 							$finite=1;
	 							last;
	 						}
	 					}
	 					if(!$finite)
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
	 				# if still ambiguous: check if there's a coor-v parent with verbform set, if so, copy that
	 				elsif($verbChunk->exists('parent::CHUNK[@type="coor-v"]/@verbform'))
	 				{
	 					my $verbform = $verbChunk->findvalue('parent::CHUNK[@type="coor-v"]/@verbform');
	 					$verbChunk->setAttribute('verbform',$verbform);
	 				}
					else
					{
						$nbrOfAmbigousClauses++;
						$verbChunk->setAttribute('verbform', 'ambiguous');
					}
	 			}
				elsif(squoia::util::isRelClause($verbChunk))
				{
					#this is a relative clause, copy verbform value to chunk (otherwise, it will get lost during the lexical transfer)
					my $reltype = $verbChunk->findvalue('child::NODE/descendant-or-self::NODE/@verbform');
					$verbChunk->setAttribute('verbform',$reltype);
					$nbrOfRelClauses++;
					
					# if this is a relative clause with hay/había/habrá que + infinitive  --> use obligative, but only on main verb, 
					# set delete=yes in haber
	 				# 'las inercias que hay que combatir'
	 				# note that parser can attach 'que' to 'hay' but also to infinitive! 
	 				if(( $verbChunk->exists('child::NODE[@lem="haber" and contains(@mi,"3")]') && $verbChunk->exists('child::CHUNK/NODE[@mi="VMN0000"]/NODE[@lem="que"]') ) || ( $verbChunk->exists('child::NODE[@lem="haber" and contains(@mi,"3") and NODE[@lem="que"]]') && $verbChunk->exists('child::CHUNK/NODE[@mi="VMN0000"]') ) )
	 				{
	 					$nbrOfFiniteForms++;
	 					#$verbChunk->setAttribute('verbform','main');
	 					$verbChunk->setAttribute('delete','yes');
	 					# get infintive of main verb and set this form to obligative
	 					my $infinitiveWithQUE = @{$verbChunk->findnodes('child::CHUNK[NODE[@mi="VMN0000"]/NODE[@lem="que"]][1]')}[0];
	 					my $infinitiveWithoutQUE = @{$verbChunk->findnodes('child::CHUNK[NODE[@mi="VMN0000"]][1]')}[0];
	 					if($infinitiveWithQUE)
	 					{
	 						$nbrOfFinalClauses++;
	 						$infinitiveWithQUE->setAttribute('verbform', 'obligative');
	 						$infinitiveWithQUE->setAttribute('addverbmi', '+3.Sg.Poss');
	 					}
	 					elsif($infinitiveWithoutQUE)
	 					{
	 						$nbrOfFinalClauses++;
	 						$infinitiveWithoutQUE->setAttribute('verbform', 'obligative');
	 						$infinitiveWithoutQUE->setAttribute('addverbmi', '+3.Sg.Poss');
	 					}
	 				}
				}
	 		}
	 		# if this is an infinitive chunk with 'sin' or 'antes de' -> set verbform to -spa (SS)
	 		# -> lo dije sin pensar -> mana yuyaspa rimarqani
	 		elsif(!squoia::util::getFiniteVerb($verbChunk) && $verbChunk->exists('child::NODE[@mi="VMN0000"]') && $verbChunk->exists('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/NODE[@lem="sin" or @lem="antes_de"]') )
	 		{
	 			$verbChunk->setAttribute('verbform','SS');
	 		}
	 		# if this is an infinitive chunk with 'para', 'con_objeto_de', con/a_fin_de -> set verbform to obligative
	 		# -> se fue a Lima para trabajar -> llamk'ananpaq Limata ripun.
	 		elsif(!squoia::util::getFiniteVerb($verbChunk) && $verbChunk->exists('child::NODE[@mi="VMN0000"]') && $verbChunk->exists('parent::CHUNK[@type="grup-sp" or @type="coor-sp"]/NODE[@lem="para" or @lem="con_objeto_de" or @lem="al_objeto_de" or @lem="con_fin_de" or @lem="con_el_fin_de" or @lem="a_fin_de" or @lem="a_fines_de" ]') )
	 		{
	 			$verbChunk->setAttribute('verbform','obligative');
	 		}
	 		# infinitive chunk that is a complement clause of a perception verb:
	 		# agentive form: te veo bailar -> tusuq rikusuni
	 		elsif(!squoia::util::getFiniteVerb($verbChunk) && $verbChunk->exists('child::NODE[@mi="VMN0000"]') && $verbChunk->getAttribute('si') =~ /cd/ && $verbChunk->findvalue('parent::CHUNK[@type="grup-verb" or @type="coor-v"]/NODE[@cpos="v"]/@lem') =~ /contemplar|descubrir|escuchar|imaginar|mirar|notar|observar|oír|percibir|sentir|^ver$/ )
	 		{
	 			$verbChunk->setAttribute('verbform','agentive');
	 		}
	 		else
	 		{
	 			$nbrOfNonFiniteChunks++;
	 		}
	 	}
	}
	
#	print STDERR "\n****************************************************************************************\n";
#	print STDERR "total number of verb chunks: ".$nbrOfVerbChunks."\n";
#	print STDERR "total number of verb chunks with no finite verb: ".$nbrOfNonFiniteChunks."\n";
#	print STDERR "total number of relative clauses: $nbrOfRelClauses \n";
#	print STDERR "total number of switch reference forms: ".$nbrOfSwitchForms."\n";
#	print STDERR "total number of nominal clauses: ".$nbrOfNominalForms."\n";
#	print STDERR "total number of final clauses: ".$nbrOfFinalClauses."\n";
#	print STDERR "total number of finite forms: ".$nbrOfFiniteForms."\n";
#	print STDERR "total number of ambiguous clauses: ".$nbrOfAmbigousClauses."\n";
#	print STDERR "total number of disambiguated verb forms: ".($nbrOfRelClauses+$nbrOfSwitchForms+$nbrOfNominalForms+$nbrOfFinalClauses+$nbrOfFiniteForms)."\n";
#	print STDERR "\n****************************************************************************************\n";

	#return $dom;	
	# print new xml to stdout
#	my $docstring = $dom->toString(1);
#	#print STDERR $dom->actualEncoding();
#	print STDOUT $docstring;
}

sub compareSubjects{
	my $verbChunk = $_[0];
	my $finiteVerb = squoia::util::getFiniteVerb($verbChunk);
#	print STDERR "compare subjs in chunk:".$verbChunk->getAttribute('ord')."\n";
	#subject of main clause
	my $mainverb = &getVerbMainClause($verbChunk);
	if($mainverb && $finiteVerb)
	{
		my $finiteMainVerb = squoia::util::getFiniteVerb($mainverb);
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

sub compareSubjectsDirectSpeech{
	my $verbChunk = $_[0];
	my $finiteVerb = squoia::util::getFiniteVerb($verbChunk);
	#print STDERR "compare subjs in chunk:".$verbChunk->getAttribute('ord')."\n";
	#subject of main clause
	my $mainverb = &getVerbMainClause($verbChunk);
	if($mainverb && $finiteVerb)
	{
		my $finiteMainVerb = squoia::util::getFiniteVerb($mainverb);
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
				$verbChunk->setAttribute('verbform', 'SS');
			}
			else
			{
				$verbChunk->setAttribute('verbform', 'DS');
			}
		}
		# if 3rd person
		elsif($finiteMainVerb  && $finiteVerb->getAttribute('mi') !~ /1|2/ )
		{ 
		 	 # if main verb SAP -> DS
		  	 if($finiteMainVerb->getAttribute('mi') =~ /1|2/)
		 	 {
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
		  			$verbChunk->setAttribute('verbform', 'DS');
		  		}
		  		# else, if both 3rd and same number: check coref
		  		else
		  		{
					# subject of this (subordinate) clause
					my ($subjNoun, $subjMI ) = &getSubjectNounSpeech($verbChunk);
					my ($subjNounMain,$subjMIMain ) =  &getSubjectNounSpeech($mainverb);
					#print STDERR "main suj: $subjNounMain, sub suj: $subjNoun\n";
		
				# if subjects of main and subord clause found, check if they're the same
				if($subjNounMain && $subjNoun && $subjMIMain && $subjMI)
				{
					#print STDERR "main: $subjNounMain $subjMIMain | sub: $subjNoun $subjMI\n";
					if($subjNounMain eq $subjNoun && $subjMIMain eq $subjMI)
					{
						$verbChunk->setAttribute('verbform', 'SS');
					}
					else
					{
						$verbChunk->setAttribute('verbform', 'DS');
					}
				}
				elsif(!$subjNounMain && !$subjNoun)
				{
					$verbChunk->setAttribute('verbform', 'DS'); 
				}
				else
				{
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
		$verbChunk->setAttribute('verbform', 'switch');
	}
}

sub isSubjunctive{
	my $verbChunk = $_[0];
	my $finiteVerb = squoia::util::getFiniteVerb($verbChunk);
	if($finiteVerb)
	{
		return substr($finiteVerb->getAttribute('mi'), 2, 1) =~ /S|M/;
	}
	else
	{
		return 0;
	}
}

sub isSingular{
	my $verbChunk = $_[0];
	my $finiteVerb = squoia::util::getFiniteVerb($verbChunk);
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
	my $finiteVerb = squoia::util::getFiniteVerb($verbChunk);
	# if 'ir a +inf' -> 1
	if($verbChunk->exists('child::NODE[@mi="VMN0000"]'))
	{
		return ($verbChunk->exists('child::NODE/NODE[@lem="ir"]') && $verbChunk->exists('child::NODE/NODE[@lem="a" and @pos="sp"]') );
	}
	elsif($finiteVerb)
	{
		return substr($finiteVerb->getAttribute('mi'), 3, 1) eq 'F';
	}
	else
	{   
		return 0;
	}
}

sub isConditional{
	my $verbChunk = $_[0];
	my $finiteVerb = squoia::util::getFiniteVerb($verbChunk);
	if($finiteVerb)
	{
		return substr($finiteVerb->getAttribute('mi'), 3, 1) eq 'C';
	}
	else
	{
		return 0;
	}
}

sub getSubjectNoun{
	my $verbChunk = $_[0];
	my ($subjectNoun,$subjectNounMI);
	my ($subjectChunk) = $verbChunk->findnodes('child::CHUNK[@si="suj" or @si="suj-a"][1]');
	
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
	#print STDERR "$subjectNoun:$subjectNounMI\n";
	return @subj;
}

sub getSubjectNounSpeech{
	my $verbChunk = $_[0];
	my ($subjectNoun,$subjectNounMI);
	my ($subjectChunk) = $verbChunk->findnodes('child::CHUNK[@si="suj" or @si="suj-a"][1]');
	
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
		my $semTag = $nounLexicon{$subjectNoun};
		# unless suposed subject is human, a social group or a proper name -> no congruence (indirect speech should not made direct with 1st person, but 3rd)
		unless($semTag =~ /hum|soc/ or $subjectNounMI =~ /^NP/){
			$subjectNoun = "none";
			$subjectNounMI="none";
		}
		#print STDERR "sem: $semTag\n";
	}
	else
	{
		print STDERR "no subject, no coref in: ";
		print STDERR $verbChunk->getAttribute('ord');
		print STDERR "\n";
	}

	my @subj = ($subjectNoun, $subjectNounMI);
	#print STDERR "$subjectNoun:$subjectNounMI\n";
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
		print STDERR $subordVerbChunk->toString();
		print STDERR "\n";
		return 0;
	}
	return $headVerbChunk;
}

1;