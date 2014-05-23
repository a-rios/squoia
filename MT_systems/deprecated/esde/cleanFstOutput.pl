#!/usr/bin/perl
						
use strict;

# List of POS tags to separate the word form from the tag
my $POSre = "_(\\\$|ADJ[AD]_|ADV|APPR(ART)?|APPO|APZR|ART|CARD|ITJ|KOU[IS]|KON|KOKOM|NE_|NN_|PDS|PDAT|PIS|PIAT|PIDAT|PPER|PPOSS|PPOSAT|PRELS|PRELAT|PRF|PWS|PWAT|PWAV|PAV|PTK(ZU|NEG|VZ|ANT|A)|TRUNC|V[AMV](FIN|INF|IMP|IZU|PP)_)";

# APPRART: contractions of preposition with definite article
# compulsary for the following forms: am, beim, im, vom, zum und zur
my %apprart = ();
$apprart{"an"}{"dem"} = "am";
$apprart{"bei"}{"dem"} = "beim";
$apprart{"in"}{"dem"} = "im";
$apprart{"von"}{"dem"} = "vom";
$apprart{"zu"}{"dem"} = "zum";
$apprart{"zu"}{"der"} = "zur";

sub getWordForm{
	my $outfst = $_[0];

	$outfst =~ s/<[^>]+>//g;	# get rid of the xml tags
	$outfst =~ s/^_//g;		# word form is the first string between "_"
	$outfst =~ s/_.*//g;		# eliminate the rest

	return $outfst;	
}

sub printWordForms{
	my $outarrayref = $_[0];

	my $sentence = "";
	my $len = @$outarrayref;
	for (my $i=0; $i < $len; $i++) {
		my $wordform = $outarrayref->[$i]->[-1];
		#print STDERR "$wordform\n";
##		if ($apprart{$wordform} and $i+1 < $len) {
##			my $nextform = $outarrayref->[$i+1]->[0];
##			my $contractedform = $apprart{$wordform}{$nextform};
##			if ($apprart{$wordform}{$nextform}) {
##				print STDERR "$contractedform ";
##				$sentence .= "$contractedform ";
##				$i++;
##				next;
##			}
##		}
		# print the last word form alternative #TODO: have some probabilistic preferences?
		print STDERR "$wordform ";
		$sentence .= "$wordform ";
	}
	$sentence =~ s/\ban dem\b/am/g;
	$sentence =~ s/\bbei dem\b/beim/g;
	$sentence =~ s/\bin dem\b/im/g;
	$sentence =~ s/\bvon dem\b/vom/g;
	$sentence =~ s/\bzu der\b/zur/g;
	$sentence =~ s/\bzu dem\b/zum/g;

	print STDOUT $sentence;
}

my @outarray = ();
my $prev_infst = "";
my $wordForm = "";
while(<>) {
	#print STDERR $_;
	chomp;
	if (/^$/) {	# flookup puts an empty line between words
		#print STDERR "eow\n";
		#print STDERR "---\n";
		$prev_infst="";
		next;
	}
	my ($infst,$outfst) = split /\t/;
	#print STDERR "$outfst\n";
	if ($infst =~ /^$/) {	# empty line between sentence has been "generated" as "\t\+\?", i.e. $infst = "" and $outfst="+?"
		#print STDERR "EOS\n";
		&printWordForms(\@outarray);
		print STDOUT "\n";
		@outarray = ();
	}
	elsif ($infst eq $prev_infst) {
		#print STDERR "alternative entry\n";
		# push further word form alternatives into array
		$wordForm = &getWordForm($outfst);
		push(@{$outarray[-1]},$wordForm);
	}
	elsif ($outfst =~ /\+\?/) {
		#print STDERR "not generatable: ";
		if ($infst =~ /^\*/) {		# begins with an asterisk, i.e. is unknown so print the whole string as "lemma"
			#print STDERR "unknown $infst\n";
			push(@outarray,["$infst"]);
		}
		else {
			print STDERR "$infst ";
			my ($lemma,$rest) = split(/$POSre/,$infst);
			print STDERR "with lemma $lemma\n";
 			#my ($lemma,$pos) = split(/_/,$infst); # TODO: Named entities have also underscores; check this before cutting only the first part of the NE!
			$lemma =~ s/\|//g;	# eliminate the separable verb prefix mark "|" still present in infinitive forms
			#print STDERR "$lemma\n";
			push(@outarray,["$lemma"]);
		}
	}
	else {
		my $wordForm = &getWordForm($outfst);
		#print STDERR "OK: $wordForm\n";
		push(@outarray,["$wordForm"]);		
	}
	$prev_infst = $infst;
	#print STDERR "---\n";
}

