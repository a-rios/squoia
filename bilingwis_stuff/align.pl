#!/usr/bin/perl


use strict;
use utf8;
binmode STDOUT, ':utf8';
use XML::LibXML;
use Storable;

my $num_args = $#ARGV + 1;
if ($num_args != 4) {
  print "\nUsage: perl align.pl es.xml quz.xml (full) sentence_aligned_es.xml sentence_aligned_quz.xml \n";
  exit;
  }

my $file_es = $ARGV[0];
my $file_quz = $ARGV[1];
my $file_sent_es = $ARGV[2];
my $file_sent_quz = $ARGV[3];
open (ES, "<", $file_es)  or die "Can't open input file \"$file_es\": $!\n";
open (SENT_ES, "<", $file_sent_es)  or die "Can't open input file \"$file_sent_es\": $!\n";

open (QUZ, "<", $file_quz)  or die "Can't open input file \"$file_quz\": $!\n";
open (SENT_QUZ, "<", $file_sent_quz)  or die "Can't open input file \"$file_sent_quz\": $!\n";
my $dom_es    = XML::LibXML->load_xml( IO => *ES );
my $dom_sent_es    = XML::LibXML->load_xml( IO => *SENT_ES );
my $dom_quz    = XML::LibXML->load_xml( IO => *QUZ );
my $dom_sent_quz    = XML::LibXML->load_xml( IO => *SENT_QUZ );

my %lexicon_es_qu = %{retrieve('lexicon-es-qu')};
my %alignments=();

foreach my $segment_es ($dom_sent_es->getElementsByTagName('seg')){
	my $segID = $segment_es->getAttribute('id');
	my $xpathToSeg = 'descendant::seg[@id='.$segID."]";
	my ($segment_quz) = $dom_sent_quz->findnodes($xpathToSeg);
	
	if($segment_quz)
	{
		#print "found corresponding $segID\n";
		# find sentences in xml
		my @sents_quz;
		my @wordforms_quz;
		#my @roots_quz;
		my @morphs_quz;
		my %quz_already_aligned =();
		foreach my $s_quz ($segment_quz->findnodes('child::s')){
			my $sentIDquz = $s_quz->getAttribute('id');
			my $xpathToSentquz = 'descendant::s[@Intertext_id="'.$sentIDquz.'"]';
			#print "xpath: $xpathToSentquz\n";
			my ($s)= $dom_quz->findnodes($xpathToSentquz);
			push(@sents_quz, $s);
			my @words = $s->findnodes('child::t/w');
			foreach my $w (@words){
				push(@wordforms_quz, lc($w->textContent) );
				#print 'quz: '.$w->textContent."\n";
			}
			my @morphs = $s->findnodes('child::t/morph');
			foreach my $morph (@morphs){
				push(@morphs_quz, lc($morph->textContent) );
			}
		}
		
		
		foreach my $s_es ($segment_es->findnodes('child::s')){
			my $sentIDes = $s_es->getAttribute('id');
			my $xpathToSentes = 'descendant::s[@Intertext_id="'.$sentIDes.'"]';
			my ($s_es_in_xml) = $dom_es->findnodes($xpathToSentes);
			#print "xpath $xpathToSentes\n";
			# get words
			foreach my $w_es ($s_es_in_xml->findnodes('child::t')){
				my $wordform_es = lc($w_es->textContent());					
				my $pos_es = $w_es->getAttribute('pos');
				my $lem_es = $w_es->getAttribute('lemma');
				my $tokenID_es = $w_es->getAttribute('n');
				# check if there's a Quechua word that starts with the exactly same sequence of characters (only if $wordform_es > 3) (proper names & loans)
				# proper names in Spanish: mwe with '_' -> split
				my @wordforms_es;
				if($pos_es =~ /^NP/){
					@wordforms_es = split('_', $wordform_es);
				}
				# don't split prepositions and locucions
				else{					
					push(@wordforms_es, $wordform_es);	
				}
				#print "wordforms: @wordforms_es  ".@wordforms_es."\n";
				foreach my $wordform_es (@wordforms_es){
					my $xpath_to_quz_cand;
					if(length($wordform_es)>3){
						
						if (grep {$_ =~ /^\Q$wordform_es\E/} @wordforms_quz) {
							#print "w es: $wordform_es\n";
							# get id of Quechua word
							# note: no lower-case function in XPath 1, have to use this: 
							# translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü")
							$xpath_to_quz_cand = 'descendant::t[w[starts-with( translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü"),"'.$wordform_es.'")]]';
							
							#print "xpath: $xpath_to_quz_cand\n";
							my @quz_cand_ts;
							foreach my $s_quz (@sents_quz){
								my @cands = $s_quz->findnodes($xpath_to_quz_cand);
								push(@quz_cand_ts, @cands);
							}
							foreach my $cand (@quz_cand_ts){
								#unless already aligned, TODO: better align only roots!
								unless($quz_already_aligned{$cand->getAttribute('n')} ==1){
									$quz_already_aligned{$cand->getAttribute('n')} =1;
									if(exists($alignments{$tokenID_es})){
										push(@{$alignments{$tokenID_es}}, $cand->getAttribute('n')."-1" );
									}
									else{
										$alignments{$tokenID_es} = [ $cand->getAttribute('n')."-1"];
									}
									last;
								}
							} #print "quz:  @quz_cand_ts\n";
							next;
						}
					}
					# lenght < 3 -> match whole string, but only if this was part of a proper name (to avoid non-adjacent alignments)
					else{
						if($w_es->textContent() =~ /_/){
							if (grep {$_ =~ /^\Q$wordform_es\E$/} @wordforms_quz) {
								$xpath_to_quz_cand = 'descendant::t[w[translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü")="'.$wordform_es.'"]]';
							
#								print "w es: $wordform_es,".$w_es->getAttribute('n')."\n";
#								print $xpath_to_quz_cand."\n";
								my @quz_cand_ts;
								foreach my $s_quz (@sents_quz){
									my @cands = $s_quz->findnodes($xpath_to_quz_cand);
									push(@quz_cand_ts, @cands);
								}
								foreach my $cand (@quz_cand_ts){
									#print "found: ".$cand->getAttribute('n')."\n";
								#unless already aligned
								unless($quz_already_aligned{$cand->getAttribute('n')} ==1){
#									print "not aligned".$cand->getAttribute('n')."\n";
									$quz_already_aligned{$cand->getAttribute('n')} =1;
									if(exists($alignments{$tokenID_es})){
										push(@{$alignments{$tokenID_es}}, $cand->getAttribute('n') );
									}
									else{
										$alignments{$tokenID_es} = [ $cand->getAttribute('n')];
									}
									last;
								}
							} #print "quz:  @quz_cand_ts\n";
								next;
							}
						}
					}
					
					# if no proper name or loan: get translation from dictionary
					my $quz_class = &mapPos2LexEntry($pos_es);
#					print "es word: $wordform_es class: $quz_class, pos: $pos_es\n";
					# lexicon lookup: use word form with personal pronouns, otherwise: lemma
					my $translations_dix = 	($quz_class eq 'prspronoun')? $lexicon_es_qu{$quz_class}{$wordform_es} : $lexicon_es_qu{$quz_class}{$lem_es};
					# if this was an adjective, and adjective lookup did not return anything: look in noun lexicon
					# (adjective lexicon contains only those adjectives that have a different translation from the corresponding noun)
					if(!$translations_dix and $quz_class eq 'adjective'){
						$translations_dix = $lexicon_es_qu{'noun'}{$lem_es};
					}
					if($translations_dix)
					{
						#print "es: $wordform_es, quz: @$translations_dix\n";
						# first step: align only (relatively) unambiguous forms, i.e. Quechua roots and words, no suffixes
						#if($quz_class =~ /^noun|^verb|interjection|number/)
						if($quz_class !~ /preposition/)
						{
							my @quz_cands;
							foreach my $translation (@$translations_dix)
							{
								# don't align suffixes yet! prspronoun: whole word forms can be aligned already here
								unless(($translation =~ /^-|^\+/ && $quz_class ne 'adverb') or $quz_class =~ /posspronoun|preposition|conjunction/ or ($quz_class eq 'determiner' and $pos_es !~ /^DN/))
								{
									my ($mainword, @preforms) = split('#',$translation);
									#print "translation $wordform_es, $lem_es: $mainword\n";
									# if only one syllable (ka, chay, kay..)-> match rootmorph EXACTLY, not just beginning, to avoid very ambiguous alignments (chay -> chaya-, etc.)
									if($mainword =~ /([^aeiou]*[aeiou][^aeiou]*){2,}/){
										# if finite verb with 1/2 person: exclude quechua verbs with other subject person
										if($pos_es =~ /V...1../){
											$xpath_to_quz_cand = 'descendant::t[root[starts-with( translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü"),"'.$mainword.'")] and count(descendant::morph[contains(@tag, "2") or contains(@tag, "3")] )=0  ]';
										}
										elsif($pos_es =~ /V...2../){
											$xpath_to_quz_cand = 'descendant::t[root[starts-with( translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü"),"'.$mainword.'")] and count(descendant::morph[contains(@tag, "1") or contains(@tag, "3")] )=0  ]';
										}
										elsif($pos_es =~ /V...3../){
											$xpath_to_quz_cand = 'descendant::t[root[starts-with( translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü"),"'.$mainword.'")] and count(descendant::morph[contains(@tag, "1") or contains(@tag, "2")] )=0  ]';
										}
										else{
											$xpath_to_quz_cand = 'descendant::t[root[starts-with( translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü"),"'.$mainword.'")]]';
										}
									}
									# only one syllable: use root in attribute @root ('only' root, no suffixes)
									else{
										if($pos_es =~ /V...1../){
												$xpath_to_quz_cand = 'descendant::t[root[ translate(@root, "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü")="'.$mainword.'"]  and count(descendant::morph[contains(@tag, "2") or contains(@tag, "3")] )=0  ]';
										}
										elsif($pos_es =~ /V...2../){
											$xpath_to_quz_cand = 'descendant::t[root[ translate(@root, "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü")="'.$mainword.'"]  and count(descendant::morph[contains(@tag, "1") or contains(@tag, "3")] )=0  ]';
										}
										elsif($pos_es =~ /V...3../){
											$xpath_to_quz_cand = 'descendant::t[root[ translate(@root, "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü")="'.$mainword.'"]  and count(descendant::morph[contains(@tag, "1") or contains(@tag, "2")] )=0  ]';
										}
										else{
											$xpath_to_quz_cand = 'descendant::t[root[ translate(@root, "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü")="'.$mainword.'"]]';
										}
									}
									#print "xpath: $xpath_to_quz_cand\n";
									my @quz_cand_ts;
									foreach my $s_quz (@sents_quz){
										my @cands = $s_quz->findnodes($xpath_to_quz_cand);
#										foreach my $c (@cands){
#											print "cand: ".$c->textContent()."\n";
#										}
										my %cand_ids;
										my $is_aligned=1;
										if(scalar(@preforms>0)){
											# search preforms, last element in @preforms = first word to the left of mainword
											my $leftContexCount=1;
											for(my $i=scalar(@preforms)-1;$i>=0;$i--)
											{
												my $preform = @preforms[$i];
												my $xpath_to_preform = 'preceding-sibling::t['.$leftContexCount.']';
												#print "preform: $preform\t";
												#print "xpath: $xpath_to_preform\n";
												# scan left context of candidates: only if preform(s) present -> align, otherwise: only partial match, do not align
												
												foreach my $cand (@cands){
													#print "cand: ".$cand->toString()."\n";
													my ($preform_cand) = $cand->findnodes($xpath_to_preform);
													if($preform_cand and lc($preform_cand->findvalue('child::w/text()')) eq $preform ){
														$cand_ids{$cand->getAttribute('n')}{$preform_cand->getAttribute('n')}=1;
														#print "preform hieeer".$preform_cand->toString()."\n";
													}
													else{
														$is_aligned =0;
														undef %cand_ids;
														#print "hieeer\n";
														last;
													}
												}
												$leftContexCount++;	
											}
											# if all preforms found: insert alignments
											if($is_aligned){
													if(exists($alignments{$tokenID_es})){
														foreach my $id (keys %cand_ids){
															unless($quz_already_aligned{$id} ==1){
																#print "aligned: $wordform_es id: $tokenID_es ----  id: ".$id."\n";
																# align whole token or only root? 
																#push($alignments{$tokenID_es}, $id );
																push(@{$alignments{$tokenID_es}}, $id."-1" );
																foreach my $preID (keys %{$cand_ids{$id}}){
																	#print "aligned preform: $wordform_es id: $tokenID_es ----  preid: ".$preID."\n";
																	#push($alignments{$tokenID_es}, $preID );
																	push(@{$alignments{$tokenID_es}}, $preID."-1" );
																}
																$quz_already_aligned{$id} =1;
																last;
															}
														}
													}
													else{
														foreach my $id (keys %cand_ids){
															unless($quz_already_aligned{$id} ==1){
																#align token or only root?
																$alignments{$tokenID_es} = [$id."-1"];
																#print "aligned: $wordform_es id: $tokenID_es ----  id: ".$id."\n";
																foreach my $preID (keys %{$cand_ids{$id}}){
																	#print "aligned preform: $wordform_es id: $tokenID_es ----  preid: ".$preID."\n";
																	push(@{$alignments{$tokenID_es}}, $preID."-1" );
																}
																$quz_already_aligned{$id} =1;
																last;
															}
														}
													}
											}
										}
										else{
											push(@quz_cand_ts, @cands);
											# special case negation: look for -chu to the right of mana/ama
											if($pos_es eq 'RN' && scalar(@cands)>0 ){
											#	print "$tokenID_es $translation  @cands\n";
												foreach my $candNode (@cands){
													my ($chu) = $candNode->findnodes('following-sibling::t/morph[@tag="+Intr_Neg"][1]');
													if($chu){
														#print $chu->toString()."\n";
														push(@quz_cand_ts, $chu);
													}
												}
											}
											#print "translation ".$translation."  @cands\n";
										}
									}
									foreach my $cand (@quz_cand_ts){
										if($pos_es eq 'RN'){
											my $aligned_id = $cand->getAttribute('n');
											if($cand->getAttribute('n') !~ /^\d+-\d+-\d+-\d+/){
												$aligned_id =$cand->getAttribute('n')."-1";
											}
											if(exists($alignments{$tokenID_es})){
												#	print "aligned: $wordform_es id: $tokenID_es ---- $mainword, id: ".$cand->getAttribute('n')."\n";
													push(@{$alignments{$tokenID_es}}, $aligned_id );
												}
												else{
													$alignments{$tokenID_es} = [ $aligned_id];
													#print "aligned: $wordform_es id: $tokenID_es ---- $mainword, id: ".$cand->getAttribute('n')."\n";
												}
										}
										else{
											unless($quz_already_aligned{$cand->getAttribute('n')} ==1){
												if(exists($alignments{$tokenID_es})){
												#	print "aligned: $wordform_es id: $tokenID_es ---- $mainword, id: ".$cand->getAttribute('n')."\n";
													push(@{$alignments{$tokenID_es}}, $cand->getAttribute('n')."-1" );
												}
												else{
													$alignments{$tokenID_es} = [ $cand->getAttribute('n')."-1"];
													#print "aligned: $wordform_es id: $tokenID_es ---- $mainword, id: ".$cand->getAttribute('n')."\n";
												}
												$quz_already_aligned{$cand->getAttribute('n')} =1;
												last;
											}
										}
									}#foreach
									# if this is an adverb translated as a suffix, but to unknown head: search for tags given in translation
									if($translation =~ /^\+/)
									{
										my @translation_tags = ($translation =~  /(\+[^\+#]+)/g);
										#print "trans tags: @translation_tags\n";
										#find first tag (if more than one: have to be adjacent!)
										my $xpath_to_tag = 'descendant::t/morph[@tag="'.@translation_tags[0].'"]';
										my %cand_ids;
										foreach my $s_quz (@sents_quz)
										{
											my @cands = $s_quz->findnodes($xpath_to_tag);
											#print "xpath $xpath_to_tag\n";
											if(scalar(@translation_tags)>1 and scalar(@cands)>0)
											{
												my $is_aligned=1;
												foreach my $cand (@cands){
													# check if following morphs concurr 
													for(my $i=1; $i<scalar(@translation_tags);$i++){
														my $nextTag = @translation_tags[$i];
														my $xpath_to_nextTag = 'following-sibling::morph['.$i.']';
														my ($nextTag_cand) = $cand->findnodes($xpath_to_nextTag);
														if($nextTag_cand and $nextTag_cand->getAttribute('tag') eq $nextTag){
															$cand_ids{$cand->getAttribute('n')}{$nextTag_cand->getAttribute('n')}=1;
														}
														else{
															$is_aligned = 0;
															undef %cand_ids;
															last;
														}
													
													}
												}
												# if all tags found: insert alignments
												if($is_aligned){
														if(exists($alignments{$tokenID_es})){
															foreach my $id (keys %cand_ids){
																#print "aligned: $wordform_es id: $tokenID_es ----  id: ".$id."\n";
																push(@{$alignments{$tokenID_es}}, $id );
																foreach my $tagID (keys %{$cand_ids{$id}}){
																	#print "aligned preform: $wordform_es id: $tokenID_es ----  preid: ".$preID."\n";
																	push(@{$alignments{$tokenID_es}}, $tagID );
																}
															}
														}
														else{
															foreach my $id (keys %cand_ids){
																$alignments{$tokenID_es} = [$id];
															#	print "aligned: $wordform_es id: $tokenID_es ----  tagid: ".$id."\n";
																foreach my $tagID (keys %{$cand_ids{$id}}){
																	#print "aligned tag: $wordform_es id: $tokenID_es ----  tagid: ".$tagID."\n";
																	push(@{$alignments{$tokenID_es}}, $tagID );
																}
															}
														}
												}
											}
											elsif(scalar(@translation_tags)==1 and scalar(@cands)>0){
												foreach my $cand (@cands){
													if(exists($alignments{$tokenID_es})){
														#print "aligned: $wordform_es id: $tokenID_es ---- , id: ".$cand->getAttribute('n')."\n";
														push(@{$alignments{$tokenID_es}}, $cand->getAttribute('n') );
													}
													else{
														$alignments{$tokenID_es} = [ $cand->getAttribute('n')];
														#print "aligned: $wordform_es id: $tokenID_es ---- , id: ".$cand->getAttribute('n')."\n";
													}
												}
											}
										}
									}
								}#unless
							}#foreach $translation
						}# if $quz_class
					}# if $translation
					if(!exists($alignments{$tokenID_es})) #no still no alignment: maybe Spanish root that occurs on the Quechua side as well, but may have a different form (e.g. mantengas - mantenenayki)?
					{
						# finite verb: cut infinitive -r
						if($pos_es =~ /^V.+[123].+/){
							$lem_es =~ s/r$//;
						}
						if(length($lem_es)>4){
							my $xpath_to_loan_cand = 'descendant::t[root[starts-with( translate(@root, "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü"),"'.$lem_es.'")]]';
							my @quz_cand_ts;
							foreach my $s_quz (@sents_quz){
								my @cands = $s_quz->findnodes($xpath_to_loan_cand);
								push(@quz_cand_ts, @cands);
							}
							foreach my $cand (@quz_cand_ts){
								unless($quz_already_aligned{$cand->getAttribute('n') } == 1){
									if(exists($alignments{$tokenID_es})){
										#print "aligned: $wordform_es id: $tokenID_es ----  id: ".$cand->getAttribute('n')."-1 \n";
										# align whole token or only root? 
										push(@{$alignments{$tokenID_es}}, $cand->getAttribute('n')."-1" );
									}else{	#align token or only root?
										$alignments{$tokenID_es} = [ $cand->getAttribute('n')."-1" ];
										#print "aligned: $wordform_es id: $tokenID_es ----  id: ".$cand->getAttribute('n')."-1 \n";
									}
									$quz_already_aligned{$cand->getAttribute('n') } =1;
									last;
								}
							}
						}
					}# else align loan words
				}# foreach my $wordforms_es
			}# foreach my $w_es
			
		# try to align Spanish words to suffixes, postpositions, determiners and conjunction that are realized as suffixes, but use already existing alignments between word forms as ankers
		foreach my $w_es ($s_es_in_xml->findnodes('child::t'))
		{
			my $wordform_es = lc($w_es->textContent());					
			my $pos_es = $w_es->getAttribute('pos');
			my $lem_es = $w_es->getAttribute('lemma');
			my $tokenID_es = $w_es->getAttribute('n');
			
			#only consider unaligned words (?), no proper names (with '_')
			unless($alignments{$tokenID_es} or $pos_es =~ /^NP/ ){
				#print "unaligned: $wordform_es\n";
				# if no proper name or loan: get translation from dictionary
				my $quz_class = &mapPos2LexEntry($pos_es);
				#print "es word: $wordform_es class: $quz_class, pos: $pos_es\n";
				# lexicon lookup: use word form with personal pronouns, otherwise: lemma
				my $translations_dix = 	($quz_class eq 'prspronoun')? $lexicon_es_qu{$quz_class}{$wordform_es} : $lexicon_es_qu{$quz_class}{$lem_es};
				# if this was an adjective, and adjective lookup did not return anything: look in noun lexicon
				# (adjective lexicon contains only those adjectives that have a different translation from the corresponding noun)
				if(!$translations_dix and $quz_class eq 'adjective'){
						$translations_dix = $lexicon_es_qu{'noun'}{$lem_es};
				}
				if($translations_dix){
					my $xpath_to_quz_cand;
					my @quz_cand_ts;
					foreach my $translation (@$translations_dix)
					{ 
							$translation =~ s/#//;
							#print "translation for $wordform_es: $translation\n";
							# if conjunction with ++ -> as a suffix (only one)
							if($translation =~ /^\+/){
								$translation =~ s/^\+\+/\+/;
								$xpath_to_quz_cand = 'descendant::t/morph[@tag="'.$translation.'"]';
#								print $xpath_to_quz_cand."\n";
							}
							# case suffix
							elsif($translation =~ /^-/){
								$xpath_to_quz_cand = 'descendant::t/morph[ translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü")="'.$translation.'"]';
							}
							# with personal pronouns (not suffixes, those are handled above): exact matches, not starts-with
							elsif($quz_class eq 'prspronoun'){
								$xpath_to_quz_cand = 'descendant::t[w[translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü")="'.$translation.'"]]';
							}					
							else{
								$xpath_to_quz_cand = 'descendant::t[w[starts-with (translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü"),"'.$translation.'")]]';
							}
							#print "xpath: $xpath_to_quz_cand\n";
							# get all candidates
							foreach my $s_quz (@sents_quz){
										my @cands = $s_quz->findnodes($xpath_to_quz_cand);
										my %cand_ids;
										my $is_aligned=1;
										push(@quz_cand_ts, @cands);
#										foreach my $c (@cands){
#											print "candidate for $wordform_es: ".$c->toString()."\n";
#										}
							}
						}
						# if more than one candidate: check if one of their roots is aligned to noun on the right of the Spanish preposition, same
						if(scalar(@quz_cand_ts>1) and $quz_class =~ /preposition|posspronoun|determiner/)
						{
									my ($firstRightNoun_es) = $w_es->findnodes('following-sibling::t[starts-with(@pos,"N") or @pos="VMN0000" or starts-with(@pos, "PP")][1]');
									if($firstRightNoun_es){
										#print "noun:  ".$firstRightNoun_es->toString()."\n";
										my $firstRightNoun_es_id = $firstRightNoun_es->getAttribute('n');
										#print "noun id: $firstLeftNoun_es_id\n";
										my $firstRightNoun_alignments = $alignments{$firstRightNoun_es_id};
										
										foreach my $cand (@quz_cand_ts){
											# TODO test possessive pronouns!!
											# if possessive pronoun (not suffix) in Quechua (e.g. 'ñuqap'): stop, in this case, corresponding root is to the right, not left!
											if($quz_class =~ /posspronoun|determiner/ and $cand->nodeName eq 't'){
												my $quz_w_id = $cand->findvalue('following-sibling::t[1]/@n');
												#print "head noun quechua id: $quz_w_id\n";
												# if quechua root is aligned to this noun: align preposition and suffix/postposition (token or root)
												if($firstRightNoun_alignments and grep {$_ =~ /^\Q$quz_w_id\E$|^\Q$quz_w_id\E-1$/} @$firstRightNoun_alignments){
													$alignments{$tokenID_es} =[$cand->getAttribute('n')];
													#print "suffix aligned $tokenID_es with ".$cand->getAttribute('n')."\n";
												}
											}
											else{
												my $quz_w_id = $cand->findvalue('parent::t/@n');
												# if quechua root is aligned to this noun: align preposition and suffix/postposition
												if($firstRightNoun_alignments and grep {$_ =~ /^\Q$quz_w_id\E$|^\Q$quz_w_id\E-1$/} @$firstRightNoun_alignments){
													$alignments{$tokenID_es} =[$cand->getAttribute('n')];
													#print "suffix aligned $tokenID_es with ".$cand->getAttribute('n')."\n";
												}
											}
										}
									}
						}
						# personal pronouns (clitics)
						if(scalar(@quz_cand_ts>1) and $quz_class =~ /prspronoun|conjunction/){
								# only main verbs as ser and estar don't take objects
								my ($firstLeftVerb_es) = $w_es->findnodes('following-sibling::t[starts-with(@pos,"VM")][1]');
								if($firstLeftVerb_es){
									#print "verb:  ".$firstLeftVerb_es->toString()."\n";
									my $firstLeftVerb_es_id = $firstLeftVerb_es->getAttribute('n');
									#print "verb id: $firstLeftVerb_es_id\n";
									my $firstLeftVerb_alignments = $alignments{$firstLeftVerb_es_id};
								
									foreach my $cand (@quz_cand_ts){
										# if word (e.g. ñuqata) -> verb can be to left or right, no way of really knowing without a parse tree...
										# BUT: case marked pronouns only used for emphasis, can be relatively sure the alignment is not ambiguous -> just align
										if($quz_class eq 'prspronoun' and $cand->nodeName eq 't'){
											if(exists($alignments{$tokenID_es})){
												#print "aligned: $wordform_es id: $tokenID_es ---- $wordform_es, id: ".$cand->getAttribute('n')."\n";
												push(@{$alignments{$tokenID_es}}, $cand->getAttribute('n') );
											}
											else{
												$alignments{$tokenID_es} = [ $cand->getAttribute('n')];
												#print "aligned: $wordform_es id: $tokenID_es ---- $wordform_es, id: ".$cand->getAttribute('n')."\n";
											}
#												
										}
										else{
												my $quz_w_id = $cand->findvalue('parent::t/@n');
												if($firstLeftVerb_alignments and grep {$_ =~ /^\Q$quz_w_id\E$|^\Q$quz_w_id\E-1$/} @$firstLeftVerb_alignments){
													if(exists($alignments{$tokenID_es})){
														#print "aligned: $wordform_es id: $tokenID_es ---- $wordform_es, id: ".$cand->getAttribute('n')."\n";
														push(@{$alignments{$tokenID_es}}, $cand->getAttribute('n') );
													}
													else{
														$alignments{$tokenID_es} = [ $cand->getAttribute('n')];
														#print "aligned: $wordform_es id: $tokenID_es ---- $wordform_es, id: ".$cand->getAttribute('n')."\n";
													}
												}
										}
										
									}
								}
								
								
						}
						# only one candidate: align
						elsif(scalar(@quz_cand_ts) == 1){
									$alignments{$tokenID_es} =[@quz_cand_ts[0]->getAttribute('n')];
									#print "only candidate aligned $tokenID_es with ".@quz_cand_ts[0]->getAttribute('n')."\n";
						}
				}# if $translation_dix
			}#unless aligned or proper name
		} # 2nd foreach my $w_es
		#print "################################################\n";
		# just for debugging: still unaligned?
#		foreach my $w_es ($s_es_in_xml->findnodes('child::t')){
#			my $tokenID_es = $w_es->getAttribute('n');
#			my $wordform_es = lc($w_es->textContent());
#			my $pos_es = $w_es->getAttribute('pos');
#			#only consider unaligned words (?), no proper names (with '_')
#			unless($alignments{$tokenID_es} or $pos_es =~ /^NP/ ){
#				print "still unaligned: $wordform_es\n";
#			}
#		}
		}# foreach my $s_es
		
#		#print for debugging: alignments for this sentence:
#		print "alignments in sentences: \n";
#		foreach my $s_quz ($segment_quz->findnodes('child::s')){
#			print "quz-".$s_quz->getAttribute('id').": ".$s_quz->textContent()."\n";
#		}
#		foreach my $s_es ($segment_es->findnodes('child::s')){
#			print "es-".$s_es->getAttribute('id').": ".$s_es->textContent()."\n";
#			my $xpathToSentes = 'descendant::s[@Intertext_id="'.$s_es->getAttribute('id').'"]';
#			my ($s_es_in_xml) = $dom_es->findnodes($xpathToSentes);
#			
#			foreach my $w_es ($s_es_in_xml->findnodes('child::t')){
#				my $id = $w_es->getAttribute('n');
#				my $wordform_es = $w_es->textContent();
#				print "aligments for $wordform_es with id $id: \t";
#				my $alignment_ids = $alignments{$id};
#				foreach my $id (@$alignment_ids){
#					my $xpath_to_quz_w = 'descendant::*[@n="'.$id.'"]';
#					my ($w_quz) = $dom_quz->findnodes($xpath_to_quz_w);
#					my ($wordform_quz) = ( $w_quz->toString() =~ m/>([^<]+)<rootmorph/ ) ;
#					if(!$wordform_quz){
#						($wordform_quz) = ( $w_quz->toString() =~ m/$id.*>(-[^<]+)/ ) ;
#					}
#					print "quz: $wordform_quz $id, ";
#				}
#			print "\n";
#		}
#		}
	}# if $quz_segment
} # foreach $segment_es

##### FOR DEBUGGING, print aligned words
#print "################################################\n";
#foreach my $es_id (sort id_sort keys %alignments){
#	my $xpath_to_es_w = 'descendant::t[@n="'.$es_id.'"]';
#	my ($w_es) = $dom_es->findnodes($xpath_to_es_w);
#	my $wordform_es = $w_es->textContent();
#	print "aligments for $wordform_es with id $es_id: ";
#	
#	my $alignment_ids = $alignments{$es_id};
#	foreach my $id (@$alignment_ids){
##		my $xpath_to_quz_w = 'descendant::*[@n="'.$id.'"]';
##		my ($w_quz) = $dom_quz->findnodes($xpath_to_quz_w);
##		my ($wordform_quz) = ( $w_quz->toString() =~ m/w>([^<]+)/ ) ;
##		if(!$wordform_quz){
##			($wordform_quz) = ( $w_quz->toString() =~ m/$id.*>(-[^<]+)/ ) ;
##		}
#		# whole words
#		my $wordform_quz;
#		if($id =~ /^\d+-\d+-\d+$/){
#			my $xpath_to_quz_w = 'descendant::*[@n="'.$id.'"]';
#			my ($w_quz) = $dom_quz->findnodes($xpath_to_quz_w);
#			($wordform_quz) = ( $w_quz->toString() =~ m/w>([^<]+)/ ) ;
#		}
#		#roots: print whole word form
#		elsif($id =~ /^\d+-\d+-\d+-1$/){
#			$id =~ s/-1$//;
#			my $xpath_to_quz_w = 'descendant::*[@n="'.$id.'"]';
#			my ($w_quz) = $dom_quz->findnodes($xpath_to_quz_w);
#			($wordform_quz) = ( $w_quz->toString() =~ m/w>([^<]+)/ ) ;
#		}
#		#suffixes
#		elsif($id =~ /^\d+-\d+-\d+-\d+/){
#			my $xpath_to_quz_w = 'descendant::*[@n="'.$id.'"]';
#			#print $xpath_to_quz_w."\n";
#			my ($w_quz) = $dom_quz->findnodes($xpath_to_quz_w);
#			($wordform_quz) = ( $w_quz->toString() =~ m/$id.*>(-[^<]+)/ ) ;
#		}
#
#		print "quz: $wordform_quz $id, ";
#	}
#	print "\n";
#	
#}

#my $es_book_id = $dom_es->documentElement->getAttribute('id');
#my $quz_book_id = $dom_quz->documentElement->getAttribute('id');
#foreach my $es_id (sort id_sort keys %alignments){
#	my $alignment_ids = $alignments{$es_id};
#	my @uniq_alignments = sort id_sort uniq(@$alignment_ids);
#	
##	my $xpath_to_es_word = 'descendant::t[@n="'.$es_id.'"]';
##	my ($es_word) = $dom_es->findnodes($xpath_to_es_word);
##	print $es_word->textContent()."\n";
#	
#	# check if adjacent morphemes!
#	my $prev_morph_id;
#	my $prev_token_id;
#	my $is_adjacent=1;
#	my $start_tok;
#	my $end_tok;
#	my $start_morph;
#	my $end_morph;
#	for (my $i=0;$i<scalar(@uniq_alignments);$i++)
#	{
#		my $this_id = @uniq_alignments[$i];
#		if($i==0){
#			($prev_morph_id) = ($this_id =~ /^\d+-\d+-\d+-(\d+)/);
#			($prev_token_id) = ($this_id =~ /^\d+-\d+-(\d+)/);
#			$start_morph = $prev_morph_id;
#			$start_tok = $prev_token_id;
##			print "this id: $this_id, prev token id: $prev_token_id, morph: $prev_morph_id\n";
#			# no morph id: whole word is aligned, just print
##			if(!$prev_morph_id){
##				#print "$es_book_id-$es_id\t$quz_book_id-$this_id\n";
##			}
#		}
#		else{
#			my ($this_morph_id) = ($this_id =~ /^\d+-\d+-\d+-(\d+)/);
#			my ($this_token_id) = ($this_id =~ /^\d+-\d+-(\d+)/);
#			#print "$this_id token $this_token_id, $prev_token_id\n";
#			# no morph in id, whole word form is aligned and adjacent:
#			if(!$this_morph_id && $this_token_id-1 == $prev_token_id  ) {
#				$end_tok = $this_token_id;
#				$prev_token_id = $this_token_id;
#			}
#			elsif(!$this_morph_id && !($this_token_id-1 == $prev_token_id )) {
#				$is_adjacent =0;
#			}
#			elsif($this_morph_id && ( ($this_token_id == $prev_token_id && $this_morph_id-1 == $prev_morph_id ) || ($this_morph_id ==1 &&  $this_token_id-1 == $prev_token_id ) )){
#				$end_tok = $this_token_id;
#				$end_morph = $this_morph_id;
#				$prev_morph_id = $this_morph_id;
#			}
#			elsif($this_morph_id && !($this_morph_id-1 == $prev_morph_id)){
#				# or print only first??
#				$is_adjacent = 0;
##				print "non-adjacent alignments in: ";
##				my $xpath_to_es_word = 'descendant::t[@n="'.$es_id.'"]';
##				my ($es_word) = $dom_es->findnodes($xpath_to_es_word);
##				print $es_word->textContent()."\n";
##				foreach my $quz_id (@uniq_alignments){
##					print "$es_book_id-$es_id\t$quz_book_id-$quz_id\n";
##				}
##				print "\n";
##				last;
#			}
#		}
#		
#	}
#	if(!$is_adjacent){
#		#print "non-adjacent alignments in: ";
##				my $xpath_to_es_word = 'descendant::t[@n="'.$es_id.'"]';
##				my ($es_word) = $dom_es->findnodes($xpath_to_es_word);
##				print $es_word->textContent()."\n";
#				foreach my $quz_id (@uniq_alignments){
#					print "$es_book_id-$es_id\t$quz_book_id-$quz_id\n";
#				}
#	}
#	else{
#		if(scalar(@uniq_alignments) ==1){
#			print "$es_book_id-$es_id\t$quz_book_id-".@uniq_alignments[0]."\n";
#		}
#		# more than one alignment, adjacent
#		else{
#			# only whole tokens aligned
#			if(!$end_morph && !$start_morph){
#				print "$es_book_id-$es_id\t$quz_book_id-".@uniq_alignments[0].":$end_tok\n";
#			}
#			# also: adjacent roots aligned: align whole word forms
#			elsif($end_morph ==1 && $start_morph ==1 && $start_tok != $end_tok){
#				my ($quz_start_id) = (@uniq_alignments[0] =~ m/^(\d+-\d+-\d+)/);
#				print "$es_book_id-$es_id\t$quz_book_id-$quz_start_id:$end_tok\n";
#			}
#			# adjacent morphemes aligned
#			elsif($end_morph != 1 && $start_tok == $end_tok){
#				print "$es_book_id-$es_id\t$quz_book_id-".@uniq_alignments[0].":$end_morph\n";
#			}
#			else{
#				## atm: only ya aligned to ña and -ña, just print, will be handled later by PHP scripts
#				foreach my $quz_id (@uniq_alignments){
#					print "$es_book_id-$es_id\t$quz_book_id-$quz_id\n";
#				}
##				print "weird alignment!!!\n";
##				print "start: $start_tok, $start_morph, end: $end_tok, $end_morph\n";
##				my $xpath_to_es_word = 'descendant::t[@n="'.$es_id.'"]';
##				my ($es_word) = $dom_es->findnodes($xpath_to_es_word);
##				print $es_word->textContent()."\n";
##				foreach my $quz_id (@uniq_alignments){
##					print "\tcontains: $es_book_id-$es_id\t$quz_book_id-$quz_id\n";
##				}
##				print "\n";
#			}	
#		}	
#	}
#}


## no phrases, no check if adjacent alignments
my $es_book_id = $dom_es->documentElement->getAttribute('id');
my $quz_book_id = $dom_quz->documentElement->getAttribute('id');
foreach my $es_id (sort id_sort keys %alignments){
	my $alignment_ids = $alignments{$es_id};
	my @uniq_alignments = sort id_sort uniq(@$alignment_ids);
	
#	my $xpath_to_es_word = 'descendant::t[@n="'.$es_id.'"]';
#	my ($es_word) = $dom_es->findnodes($xpath_to_es_word);
#	print $es_word->textContent()."\n";
	foreach my $quz_id (@uniq_alignments){
		print "$es_book_id-$es_id\t$quz_book_id-$quz_id\n";
	}

}

sub mapPos2LexEntry{
	my $pos = $_[0];
	my $class;
	
	if($pos =~ /^A[^O]/){$class = 'adjective';}
	elsif($pos =~ /^N/){$class = 'noun';}
	elsif($pos =~ /^V/){$class = 'verb';}
	elsif($pos =~ /^SP/){$class = 'preposition';}
	elsif($pos =~ /^PX|^DP/){$class = 'posspronoun';}
	elsif($pos =~ /^PP/){$class = 'prspronoun';}
	elsif($pos =~ /^R/){$class = 'adverb';}
	elsif($pos =~ /^I/){$class = 'interjection';}
	elsif($pos =~ /^C/){$class = 'conjunction';}
	elsif($pos =~ /^Z|^DN|^AO/){$class = 'number';}
	elsif($pos =~ /^D[^N]/){$class = 'determiner';}
	elsif($pos =~ /^P[^PX]/){$class = 'otherpronoun';}
	return $class;
}


sub id_sort {
	my ($article_a, $sentence_a, $token_a) = split('-', $a);
	my ($article_b, $sentence_b, $token_b) = split('-', $b);
	
	if($article_a > $article_b){
		return 1;
	}
	elsif($article_b > $article_a){
		return -1;
	}
	else{
		if($sentence_a > $sentence_b){
			return 1;
		}
		elsif($sentence_b > $sentence_a){
			return -1;
		}
		else{
			if($token_a > $token_b){
				return 1;
			}
			elsif($token_b > $token_a){
				return -1;
			}
		}
	}
	return 0;
}

sub uniq {
    my %contained_id;
    grep !$contained_id{$_}++, @_;
}
