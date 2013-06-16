#!/usr/bin/perl

use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';

# check if paramenter was given, either:
# -train (disambiguated input, add class in last row)
# -test (input to be disambiguated, leave last row empty)

my $num_args = $#ARGV + 1;
if ($num_args > 1) {
  print STDERR "\nUsage:  perl xfstToCrf.pl -1/-2/-3\n";	
  print STDERR "-1: NS/VS, -2: nominal+verbal morph disamb, 3: independent suffixes disamb\n";	
  exit;
}

my $mode = $ARGV[0];
unless($mode eq '-1' or $mode eq '-2' or $mode eq '-3' or !$mode){
	print STDERR "\nUsage:  perl xfstToCrf.pl -1/-2/-3\n";	
 	print STDERR "-1: NS/VS, -2: nominal+verbal morph disamb, 3: independent suffixes disamb\n";	
  	exit;
}


my @words;
my $newWord=1;
my $index=0;

my @words;
my $newWord=1;
my $index=0;

my $storedWords;


while(<STDIN>){
		
		if (/^$/)
		{
			$newWord=1;
		}
		else
		{	
			my ($form, $analysis) = split(/\t/);
		
			my ($pos) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$)/ ;
			
			my ($root) = $analysis =~ m/^([^\[]+?)\[/ ;
			#print "$root\n";
			
			if($pos eq ''){
				if($form eq '#EOS'){
					$pos = '#EOS';
				}
				else{
					$pos = "ZZZ";
				}
			}
			
			my @morphtags =  $analysis =~ m/(\+.+?)\]/g ;
			
			my $allmorphs='';
			foreach my $morph (@morphtags){
				$allmorphs = $allmorphs.$morph;
			}
		
			#print "allmorphs: $allmorphs\n";
			#print "morphs: @morphtags\n\n";
		
			#print "$form: $root morphs: @morphtags\n";
			my %hashAnalysis;
			$hashAnalysis{'pos'} = $pos;
			$hashAnalysis{'morph'} = \@morphtags;
			$hashAnalysis{'string'} = $_;
			$hashAnalysis{'root'} = $root;
	    	$hashAnalysis{'allmorphs'} = $allmorphs;
	    
			if($newWord)
			{
				my @analyses = ( \%hashAnalysis ) ;
				my @word = ($form, \@analyses);
				push(@words,\@word);
				$index++;
			}
			else
			{
				my $thisword = @words[-1];
				my $analyses = @$thisword[1];
				push(@$analyses, \%hashAnalysis);
			}
			$newWord=0;	
	 }
		
}
if($mode eq '-1')
{
	# get NS/ VS ambiguities
	foreach my $word (@words){
		my $analyses = @$word[1];
		my @possibleClasses = ();
		my $actualClass;
		my $allmorphs = @$analyses[0]->{'allmorphs'};
		my $string = @$analyses[0]->{'string'};
		
		# VERBAL morphology, with possible NS, TODO: delete unambiguous cases (followed by Case/Number)?
		# -sqayki
		if($allmorphs =~ /\Q+Perf+2.Sg.Poss\E/ || $allmorphs =~ /\Q+1.Sg.Subj_2.Sg.Obj.Fut\E/ || $allmorphs =~ /\Q+IPst+1.Sg.Subj_2.Sg.Obj\E/ )
		{
				push(@possibleClasses, "Perf");
				push(@possibleClasses, "Fut");
				push(@possibleClasses, "IPst");
				if($allmorphs =~ /Perf/){$actualClass = "Perf";}
				elsif($allmorphs =~  /Fut/){$actualClass = "Fut";}
				elsif($allmorphs =~ /IPst/ ){$actualClass = "IPst";}
		}
		# -sqaykichik
		elsif($allmorphs =~ /\Q+Perf+2.Pl.Poss\E/ || $allmorphs =~ /\Q+1.Sg.Subj_2.Pl.Obj.Fut\E/ || $allmorphs =~ /\Q+IPst+1.Sg.Subj_2.Pl.Obj\E/ )
		{
				push(@possibleClasses, "Perf");
				push(@possibleClasses, "Fut");
				push(@possibleClasses, "IPst");
				if($allmorphs =~ /Perf/){$actualClass = "Perf";}
				elsif($allmorphs =~  /Fut/){$actualClass = "Fut";}
				elsif($allmorphs =~ /IPst/ ){$actualClass = "IPst";}
		}
		# -sqa
		elsif(($allmorphs =~ /Perf/ && $string !~ /Cas|Num|Poss/ )|| ($allmorphs =~ /\+IPst/ && $allmorphs !~ /1|2/ ) || $allmorphs =~ /\Q+3.Sg.Subj.IPst\E/)
		#elsif( $allmorphs =~ /Perf/ || $allmorphs =~ /\+IPst/  || $allmorphs =~ /\Q+3.Sg.Subj.IPst\E/)
		{
				push(@possibleClasses, "IPst");
				if($allmorphs =~ /IPst/  ){$actualClass = "IPst";}
				
				push(@possibleClasses, "Perf");
				if($allmorphs =~ /Perf/  ){$actualClass = "Perf";}
			
		}
		
		# -yman
		elsif($allmorphs =~ /\Q+1.Sg.Subj.Pot\E/ || $allmorphs =~ /\Q+Inf+Dat_Ill\E/)
		{
			push(@possibleClasses, "Pot");
			push(@possibleClasses, "Inf");
			if($allmorphs =~ /Inf/  ){$actualClass = "Inf";}
			elsif($allmorphs =~ /Pot/  ){$actualClass = "Pot";}
		}
			
		# -ykuna
		elsif($allmorphs =~ /\Q+Inf+Pl\E/ || $allmorphs =~ /\Q+Aff+Obl\E/)
		{
			push(@possibleClasses, "Inf");
			push(@possibleClasses, "Aff_Obl");
			if($allmorphs =~ /\Q+Inf+Pl\E/ ){$actualClass = "Inf";}
			elsif($allmorphs =~ /Aff\+Obl/  ){$actualClass = "Aff_Obl";}
		}
		# -kuna
		elsif($allmorphs =~ /\Q+Pl\E/ || $allmorphs =~ /\Q+Rflx_Int+Obl\E/)
		{
			push(@possibleClasses, "Pl");
			push(@possibleClasses, "Rflx_Obl");
			if($allmorphs =~ /\Q+Pl\E/  ){$actualClass = "Pl";}
			elsif($allmorphs =~ /\Q+Rflx_Int+Obl\E/ ){$actualClass = "Rflx_Obl";}
		}
		# NOMINAL morphology, with possible VS
		# -cha(y/n), TODO: delete Vdim here? 
		elsif($allmorphs =~ /\Q+Fact\E/ ||$allmorphs =~ /\Q+Dim\E/ || $string =~ /VS.+Vdim/)
		{
				push(@possibleClasses, "Fact");
				push(@possibleClasses, "Dim");
				if($allmorphs =~  /\Q+Fact\E/){$actualClass = "Fact";}
				elsif($allmorphs =~ /\Q+Dim\E/){$actualClass = "Dim";}
				elsif($allmorphs =~ /\Q+Vdim\E/){$actualClass = "Vdim";}
		}
		# -y
		elsif($allmorphs =~ /\Q+2.Sg.Subj.Imp\Q/|| ($allmorphs =~ /Inf/ && $string !~ /Cas|Poss|Num/ ) )
		#elsif($allmorphs =~ /\Q+2.Sg.Subj.Imp\Q/|| $allmorphs =~ /Inf/  )
		{
				push(@possibleClasses, "Imp");
				push(@possibleClasses, "Inf");
				if($allmorphs =~  /Imp/){$actualClass = "Imp";}
				elsif($allmorphs =~ /Inf/ ){$actualClass = "Inf";}
		}
	
	
		# else: other ambiguities, leave
		else
		{
				push(@possibleClasses, "ZZZ");
				# TODO test what's better...
				$actualClass = "none";
				#$actualClass = @$analyses[0]->{'pos'};
		}
	
		push(@$word, \@possibleClasses);
		push(@$word, $actualClass);
		#print @$word[0].": @possibleClasses\n";
		#print "actual: $actualClass\n\n";	
	}
}

if($mode eq '-2')
{
	# get nominal/verbal ambiguities
	foreach my $word (@words){
		my $analyses = @$word[1];
		my @possibleClasses = ();
		my $actualClass;
		my $allmorphs = @$analyses[0]->{'allmorphs'};
		my $string = @$analyses[0]->{'string'};
		
		# VERBAL morphology
		# -sun
		if($allmorphs =~ /\Q+1.Pl.Incl.Subj.Imp\E/ || $allmorphs =~ /\Q+1.Pl.Incl.Subj.Fut\E/ )
		{
			push(@possibleClasses, "Imp");
			push(@possibleClasses, "Fut");
			if($allmorphs =~  /Imp/){$actualClass = "Imp";}
			elsif($allmorphs =~ /Fut/ ){$actualClass = "Fut";}
		}
		# -sqaykiku
		elsif($allmorphs =~ /\Q+IPst+1.Pl.Excl.Subj_2.Sg.Obj\E/ || $allmorphs =~ /\Q+1.Pl.Excl.Subj_2.Sg.Obj.Fut\E/)
		{
				push(@possibleClasses, "IPst");
				push(@possibleClasses, "Fut");
				if($allmorphs =~ /Fut/ ){$actualClass = "Fut";}
				elsif($allmorphs =~ /IPst/  ){$actualClass = "IPst";}
		}
		# -nqa
		elsif($allmorphs =~ /\Q+3.Sg.Subj+Top\E/ || $allmorphs =~ /\Q+3.Sg.Subj.Fut\E/ )
		{
			push(@possibleClasses, "Top");
			push(@possibleClasses, "Fut");
			if($allmorphs =~  /Top/){$actualClass = "Top";}
			elsif($allmorphs =~ /Fut/ ){$actualClass = "Fut";}
		}
		
		# NOMINAL morphology, with possible VS
		# -nkuna
		elsif($allmorphs =~ /\Q+3.Pl.Poss+Pl\E/ || $allmorphs =~ /\Q+3.Sg.Poss+Pl\E/ )
		{
				push(@possibleClasses, "Sg");
				push(@possibleClasses, "Pl");
				if($allmorphs =~  /\Q+3.Pl.Poss+Pl\E/ ){$actualClass = "Pl";}
				elsif($allmorphs =~ /\Q+3.Sg.Poss+Pl\E/ ){$actualClass = "Sg";}
		}
		# -ykuna
		elsif($allmorphs =~ /\Q+1.Pl.Excl.Poss+Pl\E/ || $allmorphs =~ /\Q+1.Sg.Poss+Pl\E/ )
		{
			push(@possibleClasses, "Sg");
			push(@possibleClasses, "Pl");
			if($allmorphs =~  /\Q+1.Pl.Excl.Poss+Pl\E/ ){$actualClass = "Pl";}
			elsif($allmorphs =~ /\Q+1.Sg.Poss+Pl\E/ ){$actualClass = "Sg";}
		}
		# else: other ambiguities, leave
		else
		{
				push(@possibleClasses, "ZZZ");
				# TODO test what's better...
				$actualClass = "none";
				#$actualClass = @$analyses[0]->{'pos'};
		}
	
		push(@$word, \@possibleClasses);
		push(@$word, $actualClass);
		#print @$word[0].": @possibleClasses\n";
		#print "actual: $actualClass\n\n";
	}

}

if($mode eq '-3')
{	
	# check remaining ambiguities
	# disambiguate indepenent suffixes 
	foreach my $word (@words){
		my $analyses = @$word[1];
		my @possibleClasses = ();
		my $actualClass;
		my $allmorphs = @$analyses[0]->{'allmorphs'};
		my $string = @$analyses[0]->{'string'};
		
			# -n
			if( ($allmorphs =~ /\Q+3.Sg.Poss\E/ && $string !~ /3\.Sg\.Poss.*(Cas|Pl)/ ) || ($allmorphs =~ /\Q+DirE\E/  && $string =~ /n\[Amb/ && $string !~ /Cas|Num.+DirE/) )
			#if( $allmorphs =~ /\Q+3.Sg.Poss\E/ || $allmorphs =~ /\Q+DirE\E/  && $string =~ /n\[Amb/  )
			{
				push(@possibleClasses, "DirE");
				push(@possibleClasses, "Poss");
				if($allmorphs =~  /DirE/){$actualClass = "DireE";}
				elsif($allmorphs =~ /Poss/ ){$actualClass = "Poss";}
			}
			# -pis
			elsif($allmorphs =~ /\Q+Loc+IndE\E/ || ($allmorphs =~ /\Q+Add\E/ && $string !~ /Add.*(IndE|DirE|Asmp)/) )
			#elsif($allmorphs =~ /\Q+Loc+IndE\E/ || $allmorphs =~ /\Q+Add\E/  )
			{
				push(@possibleClasses, "Loc_IndE");
				push(@possibleClasses, "Add");
				if($allmorphs =~ /\Q+Loc+IndE\E/){$actualClass = "Loc_IndE";}
				elsif($allmorphs =~ /Add/ ){$actualClass = "Add";}
			}
			# -s with Spanish roots: Plural or IndE (e.g. derechus)
			elsif($allmorphs =~ /\QNRootES][^DB][--]s[Amb][+IndE]\E/ && $string =~ /s\[NRootES/ )
			{
				push(@possibleClasses, "Pl");
				push(@possibleClasses, "IndE");
				if($allmorphs =~ /\Q+IndE\E/){$actualClass = "IndE";}
				else{$actualClass = "Pl";}	
			}
			# else: lexical ambiguities, leave
			else
			{
				push(@possibleClasses, "ZZZ");
				# TODO test what's better...
				$actualClass = "none";
				#$actualClass = @$analyses[0]->{'pos'};
			}
	
		push(@$word, \@possibleClasses);
		push(@$word, $actualClass);
		#print @$word[0].": @possibleClasses\n";
		#print "actual: $actualClass\n\n";
	}
}

my $lastlineEmpty=0;

# print all words, unambiguous ones with class 'none'
#foreach my $word (@words){
#	my $analyses = @$word[1];
#	my $form = @$word[0];
#	my $possibleClasses = @$word[2];
#	my $correctClass = @$word[3];
#	
#	if($form eq '#EOS' ){
#		unless($lastlineEmpty == 1){
#			print "\n";
#			$lastlineEmpty =1;
#			next;
#		}
#	}
#	else
#	{
#		print "$form\t";
#		$lastlineEmpty =0;
#		# uppercase/lowercase?
#
##		elsif(substr($form,0,1) eq uc(substr($form,0,1))){
##			print "uc\t";
##		}
##		# lowercase
##		else{
##			print "lc\t";
##		}
#		print @$analyses[0]->{'pos'}."\t";
#
#
#		my $nbrOfClasses =0;
#		# possible classes
#		foreach my $class (@$possibleClasses){
#			print "$class\t";
#			$nbrOfClasses++;
#		}
#		
#		while($nbrOfClasses<4){
#			print "ZZZ\t";
#			$nbrOfClasses++;
#		}
#
#		#possible morph tags: take ALL morph tags into account 
#		my $printedmorphs='';
#		my $nbrOfMorph =0;
#		foreach my $analysis (@$analyses){
#			my $morphsref = $analysis->{'morph'};
#			#print $morphsref;
#			foreach my $morph (@$morphsref){
#			unless($printedmorphs =~ /\Q$morph\E/){
#			print "$morph\t";
#				$printedmorphs = $printedmorphs.$morph;
#				$nbrOfMorph++;
#				}
#			}
#		}
#		while($nbrOfMorph<10){
#			print "ZZZ\t";
#			$nbrOfMorph++;
#		}
#	
#		
#		print "$correctClass";
#
#	
#		print "\n";
#	}
#}

# print only ambiguous words, with context as features

for (my $i=0;$i<scalar(@words);$i++){
	my $word = @words[$i];
	my $analyses = @$word[1];
	my $form = @$word[0];
	my $possibleClasses = @$word[2];
	my $correctClass = @$word[3];
	
   if(scalar(@$possibleClasses)>1){
		print "$form\t";

		print @$analyses[0]->{'pos'}."\t";

		my $nbrOfClasses =0;
		# possible classes
		foreach my $class (@$possibleClasses){
			print "$class\t";
			$nbrOfClasses++;
		}
		
		while($nbrOfClasses<4){
			print "ZZZ\t";
			$nbrOfClasses++;
		}

		#possible morph tags: take ALL morph tags into account 
		my $printedmorphs='';
		my $nbrOfMorph =0;
		foreach my $analysis (@$analyses){
			my $morphsref = $analysis->{'morph'};
			#print $morphsref;
			foreach my $morph (@$morphsref){
			unless($printedmorphs =~ /\Q$morph\E/){
			print "$morph\t";
				$printedmorphs = $printedmorphs.$morph;
				$nbrOfMorph++;
				}
			}
		}
		while($nbrOfMorph<10){
			print "ZZZ\t";
			$nbrOfMorph++;
		}
	
		# print context words (preceding)
		for (my $j=$i-1;$j>($i-3);$j--)
		{
			my $word = @words[$j];
			my $analyses = @$word[1];
			my $form = @$word[0];
			
			print "$form\t";
			print @$analyses[0]->{'pos'}."\t";
			#print morphs of context words
			my $printedmorphs='';
			my $nbrOfMorph =0;
			foreach my $analysis (@$analyses){
				my $morphsref = $analysis->{'morph'};
				#print $morphsref;
				foreach my $morph (@$morphsref){
				unless($printedmorphs =~ /\Q$morph\E/){
				print "$morph\t";
					$printedmorphs = $printedmorphs.$morph;
					$nbrOfMorph++;
					}
				}
			}
			while($nbrOfMorph<10){
				print "ZZZ\t";
				$nbrOfMorph++;
			}
		}
		
		# print context words (following)
		for (my $j=$i+1;$j<($i+3);$j++)
		{
			my $word = @words[$j];
			my $analyses = @$word[1];
			my $form = @$word[0];
			
			print "$form\t";
			print @$analyses[0]->{'pos'}."\t";
			#print morphs of context words
			my $printedmorphs='';
			my $nbrOfMorph =0;
			foreach my $analysis (@$analyses){
				my $morphsref = $analysis->{'morph'};
				#print $morphsref;
				foreach my $morph (@$morphsref){
				unless($printedmorphs =~ /\Q$morph\E/){
				print "$morph\t";
					$printedmorphs = $printedmorphs.$morph;
					$nbrOfMorph++;
					}
				}
			}
			while($nbrOfMorph<10){
				print "ZZZ\t";
				$nbrOfMorph++;
			}
		}
		print "$correctClass";
		print "\n\n";
	}
}

