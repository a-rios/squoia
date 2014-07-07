#!/usr/bin/perl


use strict;
use utf8;
binmode STDOUT, ':utf8';
use XML::LibXML;
use Storable;

my $num_args = $#ARGV + 1;
if ($num_args != 4) {
  print "\nUsage: perl align.pl sentence_aligned_es.xml es.xml quz.xml (full) sentence_aligned_quz.xml \n";
  exit;
  }

my $file_es = $ARGV[0];
my $file_sent_es = $ARGV[1];
my $file_quz = $ARGV[2];
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
	
	if($segment_quz){
		#print "found corresponding $segID\n";
		# find sentences in xml
		my @sents_quz;
		my @wordforms_quz;
		my @roots_quz;
		my @morphs_quz;
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
			my @roots = $s->findnodes('child::t/root');
			foreach my $root (@roots){
				push(@roots_quz, lc($root->textContent) );
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
			# get words
			foreach my $w_es ($s_es_in_xml->findnodes('child::t')){
				my $wordform_es = lc($w_es->textContent());					
				my $pos_es = $w_es->getAttribute('pos');
				my $lem_es = $w_es->getAttribute('lemma');
				my $tokenID_es = $w_es->getAttribute('n');
				# check if there's a Quechua word that starts with the exactly same sequence of characters (only if $wordform_es > 3) (proper names & loans)
				# proper names in Spanish: mwe with '_' -> split
				my @wordforms_es = split('_', $wordform_es);
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
								if(exists($alignments{$tokenID_es})){
									push($alignments{$tokenID_es}, $cand->getAttribute('n') );
								}
								else{
									$alignments{$tokenID_es} = [ $cand->getAttribute('n')];
								}
							}
												#print "quz:  @quz_cand_ts\n";
							next;
						}
					}
					# lenght < 1 -> match whole string, unless this is punctuation (do not align punctuation..)
					else{
						unless($w_es->getAttribute('pos') =~ /^F/){
							if (grep {$_ =~ /^\Q$wordform_es\E$/} @wordforms_quz) {
								#TODO: align!!
								#print "w es: $wordform_es\n";
								next;
							}
						}
					}
					
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
						#print "es: $wordform_es, quz: @$translations_dix\n";
						# first step: align only (relatively) unambiguous forms, i.e. Quechua roots and words, no suffixes
						if($quz_class =~ /^noun|^verb|interjection|number/){
							my @quz_cands;
							foreach my $translation (@$translations_dix){
								my ($mainword, @preforms) = split('#',$translation);
								$xpath_to_quz_cand = 'descendant::t[root[starts-with( translate(text(), "ABCDEFGHIJKLMNOPQRSTUVWXYZÑÁÉÍÓÚÜ", "abcdefghijklmnopqrstuvwxyzñáéíóúü"),"'.$mainword.'")]]';
								my @quz_cand_ts;
								foreach my $s_quz (@sents_quz){
									my @cands = $s_quz->findnodes($xpath_to_quz_cand);
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
														print "aligned: $wordform_es id: $tokenID_es ----  id: ".$id."\n";
														push($alignments{$tokenID_es}, $id );
														foreach my $preID (keys $cand_ids{$id}){
															print "aligned preform: $wordform_es id: $tokenID_es ----  preid: ".$preID."\n";
															push($alignments{$tokenID_es}, $preID );
														}
													}
												}
												else{
													foreach my $id (keys %cand_ids){
														$alignments{$tokenID_es} = [ $id];
														print "aligned: $wordform_es id: $tokenID_es ----  id: ".$id."\n";
														foreach my $preID (keys $cand_ids{$id}){
															print "aligned preform: $wordform_es id: $tokenID_es ----  preid: ".$preID."\n";
															push($alignments{$tokenID_es}, $preID );
														}
													}
												}
										}
									}
									else{
										push(@quz_cand_ts, @cands);
									}
								}
								foreach my $cand (@quz_cand_ts){
									if(exists($alignments{$tokenID_es})){
										print "aligned: $wordform_es id: $tokenID_es ---- $mainword, id: ".$cand->getAttribute('n')."\n";
										push($alignments{$tokenID_es}, $cand->getAttribute('n') );
									}
									else{
										$alignments{$tokenID_es} = [ $cand->getAttribute('n')];
										print "aligned: $wordform_es id: $tokenID_es ---- $mainword, id: ".$cand->getAttribute('n')."\n";
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





