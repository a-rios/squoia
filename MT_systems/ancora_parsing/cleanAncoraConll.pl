#!/usr/bin/perl


use strict;
use utf8;
binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
#binmode (STDERR);
use Getopt::Long;



#	Usage:  perl cleanAncoraConll.pl -r retok -a anocra.conll\n";
my $helpstring = "Usage: $0 [options]
available options are:
--help|-h: print this help
--retok|-r: retokenized conll
--ancora|-a: original ancora conll\n";

my $retok;
my $ancora;
my $help;

GetOptions(
	# general options
    'help|h'     => \$help,
    'retok|r=s' => \$retok,
    'ancora|a=s' => \$ancora,
) or die "Incorrect usage!\n $helpstring";

if($help or (!$retok or !$ancora)){ print STDERR $helpstring; exit;}


open RETOK, "< $retok" or die "Can't open $retok : $!";
open ANCORA, "< $ancora" or die "Can't open $ancora : $!";

# read in conll sentences

my %sents_retok =();
my $count_sent_r=1;
my $count_word_r=1;

while(<RETOK>){
	if($_ =~ /^$/){
		$count_sent_r++;
		$count_word_r =1;
	}
	else{
		$sents_retok{$count_sent_r}{$count_word_r} = $_;
		$count_word_r++;
		#print STDERR "saved line $_";
	}
	
}

my %sents_ancora =();
my $count_sent_a=1;
my $count_word_a=1;
my %headdix = ();
my $prevelliptic =0;

while(<ANCORA>){
	if($_ =~ /^$/){
		$count_sent_a++;
		$count_word_a =1;
		$prevelliptic=0;
	}
	else{
		#$sents_ancora{$count_sent_a}{$count_word_a} = $_;
		if($_ =~ /elliptic/){
			$prevelliptic++;
		}
		else{
			# remove elliptic tokens in ancora and adapt tokennr
			my ($linenr,$word_a,$lem_a,$cpos_a,$pos_a,$morphs,$head,$dep,$x,$y) = split('\t',$_);
			
				#save original tokid with word -> tokid of word will be the acutal id
				my $headkey = "s".$count_sent_a.":".$linenr;
				my $originallinenr = $linenr;			
				
				$linenr = $linenr-$prevelliptic;
				
				my %word = ( tokid => $linenr,
							 word => $word_a,
							 lem => $lem_a,
							 cpos => $cpos_a,
							 pos => $pos_a,
							 morphs => $morphs,
							 head => $head,
							 dep => $dep,
							 originaltokid=> $originallinenr
				);
				
				#print STDERR "saved: $word_a, tokid: $linenr, with head $head, linenr was $linenr, prev elliptic was $prevelliptic with key $headkey\n";
				
				$headdix{$headkey} = \%word;
				$sents_ancora{$count_sent_a}{$count_word_a} = \%word;
				$count_word_a++;

		}
	}
	
}

#foreach my $s (keys %sents_ancora){
#	my $ancora_sentence = $sents_ancora{$s};
#	foreach my $linenr (sort {$a <=> $b} keys %{$ancora_sentence}){
#		my $word = $ancora_sentence->{$linenr};
#		print STDERR "tokid: ".$word->{tokid}.", word: ".$word->{word}."\n";
#	}
#}

# adapt multi-token
for(my $i=1;$i<=$count_sent_a;$i++){
	my $ancora_sentence = $sents_ancora{$i};
	my $retok_sentence = $sents_retok{$i};
	
	my $ancora_sentence_size = keys %{$ancora_sentence};
	my $retok_sentence_size = keys %{$retok_sentence};

	my %merged_sentence =();
	
	print STDERR "working on sentence $i\n";
	
	#my $larger = ($ancora_sentence_size >= $retok_sentence_size) ? $ancora_sentence_size : $retok_sentence_size;
	if($retok_sentence_size> $ancora_sentence_size ){
		print STDERR "------------------------------------\n";
		print STDERR "retok size ($retok_sentence_size) is larger than ancora size ($ancora_sentence_size), in sentence $i!\n";
		print STDERR "sentence: \n";

		for(my $j=1;$j<= $retok_sentence_size;$j++){
			my $retok_line = $retok_sentence->{$j};
			my ($word_r,$lem_r,$cpos_r,$pos_r) = split('\t',$retok_line);
			my $word = $ancora_sentence->{$j};
			print STDERR " a=".$word->{word}.":=".$word_r." ";
		}
		print STDERR "\n------------------------------------\n";
		next;
		#exit(0);
	}
	

	my $ancora_linenr=1;
	for(my $j=1;$j<= $retok_sentence_size;$j++)
	{
		my $ancora_word = $ancora_sentence->{$ancora_linenr};
		my $retok_line = $retok_sentence->{$j};
		chomp($retok_line);
		my ($word_r,$lem_r,$cpos_r,$pos_r) = split('\t',$retok_line);
		#print STDERR "w: $word_r,lem: $lem_r,cpos: $cpos_r, pos: $pos_r\n"; 
		#print STDERR "ancora line: $ancora_linenr\n";
		
		my $word_a =  $ancora_word->{word};
		my %merged_token =();
		#print STDERR "working on ancora word word_a: $word_a\n";
#		print STDERR "working on tokid: ".$ancora_word->{tokid}.", word: ".$ancora_word->{word}."\n";
#		print STDERR "------------------------------------\n";
#		print STDERR "sentence: \n";
#		for(my $j=1;$j<= $retok_sentence_size;$j++){
#					my $retok_line = $retok_sentence->{$j};
#					my ($word_r,$lem_r,$cpos_r,$pos_r) = split('\t',$retok_line);
#					my $word = $ancora_sentence->{$j};
#					print STDERR " a=".$word->{word}.":=".$word_r." ";
#				}
#		print STDERR "\n------------------------------------\n";
		
		#print STDERR "a: $word_a, r: $word_r\n";
		if(lc($word_r) eq lc($word_a)){
			$merged_token{tokid}=$j;
			$merged_token{word}= $word_r;
			$merged_token{lem}= $lem_r;
			$merged_token{cpos}= $cpos_r;
			$merged_token{pos}= $pos_r;
			$merged_token{dep}= $ancora_word->{dep};
			
			my $morphstring = &eaglesToMorph($pos_r);
			$merged_token{morphs}= $morphstring;
			
			my $headid = $ancora_word->{head};
			#print STDERR "head: $headid\n";
			if($headid ne '0'){
				$merged_token{head}= $headid;
			}
			else{
				$merged_token{head}= '0';
			}
			
			
			# find acutal head, in case there was an elliptic token
#			my $headid = $ancora_word->{head};
#			
#			if($headid ne '0'){
#				my $headkey = "s".$i.":".$headid;
#				my $headword = $headdix{$headkey};
#				$headid = $headword->{tokid};
#				$merged_token{head}= $headid;
#			}
#			else{
#				$merged_token{head}= '0';
#			}
			
			
			#print STDERR "merged $j, $word_r, $lem_r, $cpos_r, $pos_r, ".$ancora_word->{dep}." $morphstring\n";
			
			# print words that dont match in case to STDERR to be fixed later, manually
			unless($word_a eq $word_r){
				print STDERR "different case: $word_a, $word_r\n";
			}	

		}
		elsif($word_r =~ /\Q$word_a\E/)
		{
			#print STDERR "\nmultiword: $word_r, $word_a\n";
			#get number of contracted tokens in ancora
			my $multi_word_end=$ancora_linenr+1;
			my ($next_word_r,$rest) = split('\t', $retok_sentence->{$j+1});
			#my ($nr,$next_word_a,$rest_a) = split('\t', $ancora_sentence->{$multi_word_end});
			my $next_word_a = $ancora_sentence->{$multi_word_end}->{word};
			while($next_word_a ne $next_word_r){
				$multi_word_end++;
				$next_word_a = $ancora_sentence->{$multi_word_end}->{word};
				
			}
			# we stopped at beginning of next word -> -1
			$multi_word_end -=1;
			my $length_multi_token = $multi_word_end-$ancora_linenr;
			#print STDERR "multi word ends at: $multi_word_end, $next_word_a -1\n";
			
			# get the head: head is the one with a head relation to a token id outside the multi-word
			my $ancora_headid = $ancora_word->{head};
			#get acutal head, in case there was an elliptic token

			my $found=0;
			my $real_start = $ancora_word->{tokid};
			my $real_end =  $ancora_sentence->{$multi_word_end}->{tokid};
			
			my $headword_in_multi_word;
			for(my $multi_token_id_in_ancora= $ancora_linenr; $multi_token_id_in_ancora<= $multi_word_end; $multi_token_id_in_ancora++){
				my $thisword =  $ancora_sentence->{$multi_token_id_in_ancora};
				my $multi_headid = $thisword->{head};

				#get acutal head, in case there was an elliptic token
				my $headkey = "s".$i.":".$multi_headid;
				my $headword = $headdix{$headkey};
				$multi_headid = $headword->{tokid};

				
				#print STDERR "testing token ".$thisword->{word}." with head: $multi_headid  ".$thisword->{head}." with headkey: $headkey\n";
				#print STDERR "tokid of multi word head: $multi_headid, -- real start: $real_start, -- real end: $real_end\n";

				
				if($multi_headid<$real_start || $multi_headid > $real_end ){
					
					#print STDERR "eval true: for testing token ".$thisword->{word}." with head from dix: $multi_headid, original head ".$thisword->{head}." with headkey: $headkey\n";
#					print STDERR "multihead_id = $multi_headid, j: $j\n";
#					print STDERR "1multi token id in ancora: $multi_token_id_in_ancora\n";
					$found=1;
					$headword_in_multi_word = $multi_token_id_in_ancora;
					last;
				}
				
			}
			
			unless($found){
				print STDERR "------------------------------------\n";
				print STDERR "no head outside multi-word token found, cannot convert, in sentence $i, token $j\n";
				print STDERR "sentence: \n";
				for(my $j=1;$j<= $retok_sentence_size;$j++){
					my $retok_line = $retok_sentence->{$j};
					my ($word_r,$lem_r,$cpos_r,$pos_r) = split('\t',$retok_line);
					my $word = $ancora_sentence->{$j};
					print STDERR " a=".$word->{word}.":=".$word_r." ";
				}
				print STDERR "\n------------------------------------\n";
				next;
				#exit(0);
			}	
			
			#print "2multi token id in ancora: $headword_in_multi_word\n";
			# multi_token_id = id of token that is the head of the new multitoken -> get morphs, dep, head form this token
			#print "head of multi token is $multi_token_id_in_ancora, ancora line nr $ancora_linenr\n";
			my $ancora_head_word = $ancora_sentence->{$headword_in_multi_word};
			$merged_token{tokid}=$j;
			$merged_token{word}= $word_r;
			$merged_token{lem}= $lem_r;
			$merged_token{cpos}= $cpos_r;
			$merged_token{pos}= $pos_r;
			my $morphstring = &eaglesToMorph($pos_r);
			$merged_token{morphs}= $morphstring;
			$merged_token{dep}= $ancora_head_word->{dep};
			my $multi_headid = $ancora_head_word->{head};
			$merged_token{head}= $multi_headid;
			#print STDERR "assigned head $multi_headid to multi word $word_r, ancora word: ".$ancora_sentence->{$headword_in_multi_word}->{word}."\n";
			#print STDERR "word s:19->".$headdix{"s1:19"}->{word}."with tokid ".$headdix{"s1:19"}->{tokid}."\n";
		
		
			# set all headkeys of tokens in multiword to this token
			my $originallinenr_start = $ancora_word->{originaltokid};
			my $originallinenr_end = $ancora_head_word->{originaltokid};
			for(my $tokennr= $originallinenr_start ;$tokennr<= $originallinenr_end;$tokennr++){
				#print STDERR "adapting headkeys to multitoken:  $tokennr\n";
				my $headkey = "s".$i.":".$tokennr;
				$headdix{$headkey} = \%merged_token;
				#print STDERR "headkey $headkey now points to merged: ".$merged_token{word}." with tokid ".$merged_token{tokid}."\n";
			}
			
			# all following heads -= length of multi word token
			
			#print STDERR "ancora line nr: before multi $ancora_linenr, length multi $length_multi_token\n";
			$ancora_linenr += $length_multi_token;
			#print STDERR "ancora line nr: after multi $ancora_linenr\n";
			my $deleted = $length_multi_token;
			my @sorted_ancora_keys = sort id_sort keys %headdix;
			#print "after multi word $word_r\n\n";
			#print STDERR "adapting keys from s".$i.":".($multi_word_end+1)." to ".scalar(@sorted_ancora_keys)."\n";
			
			for(my $ancora_word_key_nr= ($originallinenr_end+1); $ancora_word_key_nr<=scalar(@sorted_ancora_keys); $ancora_word_key_nr++ ){
				my $ancora_word_key = "s".$i.":".$ancora_word_key_nr;
				my $ancora_word = $headdix{$ancora_word_key};
				#print STDERR "ancora word $ancora_word_key: ".$ancora_word->{word}." tokid ".$ancora_word->{tokid}." deleted: $deleted, length multitoken: $length_multi_token\n";
				my $new_tokid = ($ancora_word->{tokid}-$deleted );
				$ancora_word->{tokid} = $new_tokid;
				#print STDERR "new ancora word $ancora_word_key: ".$ancora_word->{word}." tokid ".$ancora_word->{tokid}."\n";
				
				
			}
			
		}
		$ancora_linenr++;
		$merged_sentence{$j} = \%merged_token;

		
	}
	foreach my $key (sort {$a <=> $b} keys %merged_sentence){
		#print STDERR "key: $key\n";
		my $merged_token = $merged_sentence{$key};
		
		
		my $headid = $merged_token->{head};
		unless($headid eq '0'){
	#		#get acutal head, in case there was an elliptic token
			my $headkey = "s".$i.":".$headid;
			my $headword = $headdix{$headkey};
			$headid = $headword->{tokid};
			#my $test = $headdix{"s1:19"};
		    #print STDERR "prep a tokid: ".$test->{tokid}." word: ".$test->{word}."\n";
			#print STDERR "word: ".$merged_token->{word}." has head with headkey $headkey id from dix ".$headid."\n";
		}

		
		#print STDERR "head id: ".$merged_token->{head}." for word ".$merged_token->{word}."\n";
		# head of sentence -> =0, doesnt have one now since no s_:0 token in headdix-> set here
#		if($merged_token->{dep} eq 'sentence' and !(defined $merged_token->{head})){
#			$merged_token->{head} = '0';
#		}
		
		my $pos = substr($merged_token->{pos},0,2);
		
		if($merged_token->{tokid} eq ''){
				print STDERR "------------------------------------\n";
		
				print STDERR "sentence: merged has no token id\n";
				for(my $j=1;$j<= $retok_sentence_size;$j++){
					my $retok_line = $retok_sentence->{$j};
					my ($word_r,$lem_r,$cpos_r,$pos_r) = split('\t',$retok_line);
					my $word = $ancora_sentence->{$j};
					print STDERR " a=".$word->{word}.":=".$word_r." ";
				}
				print STDERR "\n------------------------------------\n";
			exit(0);
		}
		print $merged_token->{tokid}."\t".$merged_token->{word}."\t".$merged_token->{lem}."\t".$merged_token->{cpos}."\t".$pos."\t".$merged_token->{morphs}."\t".$headid."\t".$merged_token->{dep}."\t_\t_"."\n";
		

	}
	print "\n";

}
#empty line at end to make maltparser happy
print "\n";

sub id_sort {
	my ($sentence_id_a,$original_ancora_line_a) = split(':', $a);
	my ($sentence_id_b,$original_ancora_line_b) = split(':', $b);
	
	if($original_ancora_line_a> $original_ancora_line_b){
		return 1;
	}
	elsif($original_ancora_line_b > $original_ancora_line_a){
		return -1;
	}
	return 0;
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
		
		my $person = substr($eaglesTag,3,1);
		my $gender = substr($eaglesTag,4,1);
		my $number = substr($eaglesTag,5,1);
		my $possessor = substr($eaglesTag,6,1);
		
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
		 my $gender = substr($eaglesTag,3,1);
		 my $number = substr($eaglesTag,4,1);
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
		
		my $person = substr($eaglesTag,5,1);
		my $number = substr($eaglesTag,6,1);
		my $gender = substr($eaglesTag,7,1);
		
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
		
		my $person = substr($eaglesTag,3,1);
		my $gender = substr($eaglesTag,4,1);
		my $number = substr($eaglesTag,5,1);
		my $caseLetter = substr($eaglesTag,6,1);
		my $possessornum = substr($eaglesTag,7,1);
		my $politeness = substr($eaglesTag,8,1);
		
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
		my $gender = substr($eaglesTag,3,1);
		my $number = substr($eaglesTag,4,1);
		
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
		$morphstring = "punct=slash" if ($eaglesTag eq 'Fp');
		# (	Fpa, )	Fpt: punct=bracket
		$morphstring = "punct=slash" if ($eaglesTag eq 'Fpt' or $eaglesTag eq 'Fpa');
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
		print STDERR "no morphstring assigned to tag: $eaglesTag\n";
		$morphstring = "_";
	}
	
	#print STDERR "$eaglesTag, $morphstring\n";
	return $morphstring;
	
	
}




