#!/usr/bin/perl
						
use strict;

# example of FST output
#die_ART_Def.Fem.Nom.Sg	die_ART
#Mutter_NN_Fem.Nom.Sg.*	<CLASS><MUTTER/></CLASS>_Mutter_NN_Fem.Nom.Sg.*
#essen_VVFIN_3.Sg.Pres.Ind	<CLASS><M1=/><3/><M2=/><2/><M3=/><12/><M4=/><12/><M5=/><1/><M6=/><2/><M7=/><0/></CLASS>_isst_VVFIN_3.Sg.Pres.Ind
#nicht_ADV	+?
#immer_ADV	+?
#sehr_ADV	+?
#reif_ADJD_Pos	<CLASS><OLIFC.90/></CLASS>_reif_ADJD_Pos
#die_ART_Def.*.Akk.Pl	die_ART
#Apfel_NN_Masc.Akk.Pl.*	<CLASS><VATER/></CLASS>_Äpfel_NN_Masc.Akk.Pl.*
#	+?

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

	#my $index = 0;
	my $len = @$outarrayref;
	for (my $i=0; $i < $len; $i++) {
		my $wordform = $outarrayref->[$i]->[-1];
		if ($apprart{$wordform} and $i+1 < $len) {
			my $nextform = $outarrayref->[$i+1]->[0];
			my $contractedform = $apprart{$wordform}{$nextform};
			if ($apprart{$wordform}{$nextform}) {
				print STDOUT "$contractedform ";
				$i++;
				next;
			}
		}
		# print the last word form alternative #TODO: have some probabilistic preferences?
		print STDOUT "$wordform ";
	}
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
			#print STDERR "$infst ";
			my ($lemma,$pos) = split(/_/,$infst); # TODO: Named entities have also underscores; check this before cutting only the first part of the NE!
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

