#!/usr/bin/perl


use strict;
use utf8;
use XML::LibXML;
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
			
			$linenr = $linenr-$prevelliptic;
			my %word = ( tokid => $linenr,
						 word => $word_a,
						 lem => $lem_a,
						 cpos => $cpos_a,
						 pos => $pos_a,
						 morphs => $morphs,
						 head => $head,
						 dep => $dep
			);
		#	print "saved: $word_a, tokid: $linenr, with head $head, linenr was $linenr, prev elliptic was $prevelliptic with key $headkey\n";
			
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
#		print "tokid: ".$word->{tokid}.", word: ".$word->{word}."\n";
#	}
#}

# adapt multi-token
for(my $i=1;$i<=$count_sent_a;$i++){
	my $ancora_sentence = $sents_ancora{$i};
	my $retok_sentence = $sents_retok{$i};
	
	my $ancora_sentence_size = keys %{$ancora_sentence};
	my $retok_sentence_size = keys %{$retok_sentence};

	my %merged_sentence =();
	
	
	#my $larger = ($ancora_sentence_size >= $retok_sentence_size) ? $ancora_sentence_size : $retok_sentence_size;
	if($retok_sentence_size> $ancora_sentence_size ){
		print "retok size is larger than ancora size, in sentence $i!\n";
		exit(0);
	}
	
	#foreach my $linenr (sort {$a <=> $b} keys %{$ancora_sentence}){
	my $ancora_linenr=1;
	for(my $j=1;$j<= $retok_sentence_size;$j++)
	{
		my $ancora_word = $ancora_sentence->{$ancora_linenr};
		#print "tokid: ".$word->{tokid}.", word: ".$word->{word}."\n";
		my $retok_line = $retok_sentence->{$j};
		chomp($retok_line);
		my ($word_r,$lem_r,$cpos_r,$pos_r) = split('\t',$retok_line);
		
		my $word_a =  $ancora_word->{word};
		my %merged_token =();
		#print "word_a: $word_a\n";
		
		if($word_r eq $word_a){
			$merged_token{tokid}=$j;
			$merged_token{word}= $word_r;
			$merged_token{lem}= $lem_r;
			$merged_token{cpos}= $cpos_r;
			$merged_token{pos}= $pos_r;
			$merged_token{dep}= $ancora_word->{dep};
			$merged_token{morphs}= $ancora_word->{morphs};
			
			# find acutal head, in case there was an elliptic token
			my $headid = $ancora_word->{head};
			my $headkey = "s".$i.":".$headid;
			my $headword = $headdix{$headkey};
			$headid = $headword->{tokid};
			$merged_token{head}= $headid;		

		}
		elsif($word_r =~ /$word_a/)
		{
		#	print "multiword: $word_r, $word_a\n";
			#get number of contracted tokens in ancora
			my $multi_word_end=$j+1;
			my ($next_word_r,$rest) = split('\t', $retok_sentence->{$multi_word_end});
			#my ($nr,$next_word_a,$rest_a) = split('\t', $ancora_sentence->{$multi_word_end});
			my $next_word_a = $ancora_sentence->{$multi_word_end}->{word};
			while($next_word_a ne $next_word_r){
				$multi_word_end++;
				$next_word_a = $ancora_sentence->{$multi_word_end}->{word};
				
			}
			# we stopped at beginning of next word -> -1
			$multi_word_end -=1;
		#	print "multi word ends at: $multi_word_end\n";
			# get the head: head is the one with a head relation to a token id outside the multi-word
			my $ancora_headid = $ancora_word->{head};
			#get acutal head, in case there was an elliptic token
			my $headkey = "s".$i.":".$ancora_headid;
			my $headword = $headdix{$headkey};
			my $multi_headid = $headword->{tokid};
		#	print "multi_headid: $multi_headid, ancora_linenr: $ancora_linenr,  multi_word_end: $multi_word_end \n";

				
			my $found=0;
			my $headword_in_multi_word;
			for(my $multi_token_id_in_ancora= $ancora_linenr; $multi_token_id_in_ancora<= $multi_word_end; $multi_token_id_in_ancora++){
				my $thisword =  $ancora_sentence->{$multi_token_id_in_ancora};
				my $multi_headid = $thisword->{head};

				#get acutal head, in case there was an elliptic token
				my $headkey = "s".$i.":".$multi_headid;
				my $headword = $headdix{$headkey};
				$multi_headid = $headword->{tokid};
				#print "testing token ".$thisword->{word}." with head: $multi_headid  ".$thisword->{head}."with headkey: $headkey\n";
				#print "tokid of multi word head: $multi_headid, -- $ancora_linenr, -- $multi_word_end\n";
				if($multi_headid<$ancora_linenr || $multi_headid > $multi_word_end ){
					
#					print "eval true: for testing token ".$thisword->{word}." with head: $multi_headid  ".$thisword->{head}."with headkey: $headkey\n";
#					print "multihead_id = $multi_headid, j: $j\n";
#					print "1multi token id in ancora: $multi_token_id_in_ancora\n";
					$found=1;
					$headword_in_multi_word = $multi_token_id_in_ancora;
					last;
				}
				
			}
			
			unless($found){
				print STDERR "no head outside multi-word token found, cannot convert, in sentence $i, token $j\n";
				exit(0);
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
			$merged_token{morphs}= $ancora_head_word->{morphs};
			#get acutal head, in case there was an elliptic token
			my $multi_headid = $ancora_head_word->{head};
			my $headkey = "s".$i.":".$multi_headid;
			my $headword = $headdix{$headkey};
			$multi_headid = $headword->{tokid};
			$merged_token{head}= $multi_headid;
			$merged_token{dep}= $ancora_head_word->{dep};

			my $length_multi_token = $multi_word_end-$ancora_linenr;
			$ancora_linenr += $length_multi_token;
			
			# set all headkeys of tokens in multiword to this token
			for(my $tokennr=$j;$tokennr<= $multi_word_end;$tokennr++){
				my $headkey = "s".$i.":".$tokennr;
				$headdix{$headkey} = \%merged_token;
			}
			
			# all following heads -= length of multi word token
			my $deleted = $length_multi_token;
			my @sorted_ancora_keys = sort id_sort keys %headdix;
			#print "after multi word $word_r\n\n";
			for(my $ancora_word_key_nr= ($multi_word_end+1); $ancora_word_key_nr<scalar(@sorted_ancora_keys); $ancora_word_key_nr++ ){
				my $ancora_word_key = "s".$i.":".$ancora_word_key_nr;
				my $ancora_word = $headdix{$ancora_word_key};
			#	print "ancora word $ancora_word_key: ".$ancora_word->{word}." tokid ".$ancora_word->{tokid}." deleted: $deleted, length multitoken: $length_multi_token\n";
				my $new_tokid = ($ancora_word->{tokid}-$deleted );
				$ancora_word->{tokid} = $new_tokid;
			#	print "new ancora word $ancora_word_key: ".$ancora_word->{word}." tokid ".$ancora_word->{tokid}."\n";
				
				
			}
			
			
		}
		$ancora_linenr++;
		$merged_sentence{$j} = \%merged_token;

		
	}
	foreach my $key (sort {$a <=> $b} keys %merged_sentence){
		#print "key: $key\n";
		my $merged_token = $merged_sentence{$key};
		
		
#		my $headid = $merged_token->{head};
#		#get acutal head, in case there was an elliptic token
#		my $headkey = "s".$i.":".$headid;
#		my $headword = $headdix{$headkey};
#		$headid = $headword->{tokid};
		
		# head of sentence -> =0, doesnt have one now since no s_:0 token in headdix-> set here
		if($merged_token->{dep} eq 'sentence' and !(defined $merged_token->{head})){
			$merged_token->{head} = 0;
		}
		
		print $merged_token->{tokid}."\t".$merged_token->{word}."\t".$merged_token->{lem}."\t".$merged_token->{cpos}."\t".$merged_token->{pos}."\t".$merged_token->{morphs}."\t".$merged_token->{head}."\t".$merged_token->{dep}."\n";
		

	}
	print "\n";

}

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
 	