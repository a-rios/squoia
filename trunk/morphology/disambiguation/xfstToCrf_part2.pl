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
	# if a word has more than one analysis that differ only in length of the root by 1, and last letter is -q/-y/-n 
	# delete the one with the shorter root (e.g. millay -> milla -y/millay, qapaq-> qapa-q/qapaq, allin -> alli -n/ allin)
	foreach my $word (@words)
	{
		
		my $analyses = @$word[1];
		my $form = @$word[0];
		
		if(scalar(@$analyses)>1)
		{
			for(my $j=0;$j<scalar(@$analyses);$j++) 
			{
				my $analysis = @$analyses[$j];
				my $root = $analysis->{'root'};
				#print "$root ";
				#check if contained in following roots
				for(my $k=$j+1;$j<$k;$k--) 
				{
					my $analysis = @$analyses[$k];
					my $postroot = $analysis->{'root'};
					#print "$postroot ";
					if($postroot =~ /\Q$root\E[yqn]$/)
					{
						splice (@{$analyses},$j,1);	
						$j--;
						#print "1 to delete $root, compared with $postroot\n";
						last;	
					}
					elsif($root eq 'u' && $postroot eq 'o')
					{
						splice (@{$analyses},$j,1);	
						$j--;
						#print "1 to delete $root, compared with $postroot\n";
						last;	
					}
					else
					{
						#check if contained in preceding roots
						for(my $k=0;$k<$j;$k++) 
						{
							my $analysis = @$analyses[$k];
							my $preroot = $analysis->{'root'};
							#print "2 $root vs. $preroot \n";
							if($preroot =~ /\Q$root\E[yqn]$/)
							{
								splice (@{$analyses},$j,1);	
								$j--;
								#print "2 to delete $root, compared with $preroot\n";
							}
							elsif($root eq 'u' && $preroot eq 'o')
							{
								splice (@{$analyses},$j,1);	
								$j--;
								#print "2 to delete $root, compared with $postroot\n";
								last;	
							}
						}
					}
				}
				
				# if analysis differ in -kama +Dist vs. +Term -> take +Term, delete +Dist
				my $morphs = $analysis->{'morph'};
				#print "@$morphs\n";
				if(grep {$_ =~ /Dist/} @$morphs){
					# check if later analysis has +Term
					for(my $k=$j+1;$j<$k;$k--) 
					{
						my $analysis = @$analyses[$k];
						my $postmorphs = $analysis->{'morph'};
						if(grep {$_ =~ /Term/} @$postmorphs){
							splice (@{$analyses},$j,1);	
							$j--;
							#print "2 to delete @$morphs\n";
							#print "compared with @$postmorphs\n";
							last;
						}
					}
					# check if previuous analysis has +Term
					for(my $k=0;$k<$j;$k++) 
					{
						my $analysis = @$analyses[$k];
						my $premorphs = $analysis->{'morph'};
						if(grep {$_ =~ /Term/} @$premorphs){
							splice (@{$analyses},$j,1);	
							$j--;
							#print "2 to delete @$morphs\n";
							#print "compared with @$premorphs\n";
							last;
						}
					}
				}
				
				#print "\n";
			}
		}
	}


	# get NS / VS ambiguities
	foreach my $word (@words)
	{
		my $analyses = @$word[1];
		my @possibleClasses = ();
		
		if(scalar(@$analyses)>1)
		{
			# VERBAL morphology
			# -sqayki
			if(&containedInOtherMorphs($analyses,"+Perf","+1.Sg.Subj_2.Sg.Obj.Fut"))
			{
				push(@possibleClasses, "Perf");
				push(@possibleClasses, "Fut");
				if(&containedInOtherMorphs($analyses,"+Perf","+IPst+1.Sg.Subj_2.Sg.Obj")){
					push(@possibleClasses, "IPst");
				}
			}
			# -sqaykichik
			elsif(&containedInOtherMorphs($analyses,"+Perf","+1.Sg.Subj_2.Pl.Obj.Fut"))
			{
				push(@possibleClasses, "Perf");
				push(@possibleClasses, "Fut");
				if(&containedInOtherMorphs($analyses,"+Perf","+IPst+1.Sg.Subj_2.Pl.Obj")){
					push(@possibleClasses, "IPst");
				}
			}
			# -sqa
			elsif(&containedInOtherMorphs($analyses,"+Perf","+IPst") || &containedInOtherMorphs($analyses,"+Perf","+3.Sg.Subj.IPst") )
			{
				push(@possibleClasses, "IPst");
				push(@possibleClasses, "Perf");
			}
			# -y
			elsif(&containedInOtherMorphs($analyses,"+2.Sg.Subj.Imp","+Inf"))
			{
				push(@possibleClasses, "Imp");
				push(@possibleClasses, "Inf");
			}
			# -yman
			elsif(&containedInOtherMorphs($analyses,"+1.Sg.Subj.Pot","+Inf+Dat_Ill"))
			{
				push(@possibleClasses, "Pot");
				push(@possibleClasses, "Inf");
			}
			# -ykuna
			elsif(&containedInOtherMorphs($analyses,"+Inf+Pl","+Aff+Obl"))
			{
				push(@possibleClasses, "Inf");
				push(@possibleClasses, "Aff_Obl");
			}
#			# -nakuna
#			elsif(&containedInOtherMorphs($analyses,"+Obl+Pl","+Rzpr+Rflx_Int+Obl"))
#			{
#				push(@possibleClasses, "Obl_Pl");
#				push(@possibleClasses, "Rzpr_Rflx_Obl");
#			}
			# -kuna
			elsif(&containedInOtherMorphs($analyses,"+Pl","+Rflx_Int+Obl"))
			{
				push(@possibleClasses, "Pl");
				push(@possibleClasses, "Rflx_Obl");
			}
			# -cha
			elsif(&containedInOtherMorphs($analyses,"+Fact","+Dim"))
			{
				push(@possibleClasses, "Fact");
				push(@possibleClasses, "Dim");
				# should not be a verb, but you never know..
				if(&containedInOtherMorphs($analyses,"+Dim","+Vdim+Rflx_Int+Obl") or &containedInOtherMorphs($analyses,"+Fact","+Vdim") ){
					push(@possibleClasses, "Vdim");
				}
			}
			
			# else: other ambiguities, leave
			else
			{
				push(@possibleClasses, "ZZZ");
			}
		}
		# unambiguous forms: use pos tag, should help with context (hopefully)
		else
		{
			push(@possibleClasses, "ZZZ");
			#push(@possibleClasses, @$analyses[0]->{'pos'});
		}
		push(@$word, \@possibleClasses);
		#print @$word[0].": @possibleClasses\n";
		
	}
}

if($mode eq '-2')
{
	# get verbal / nominal ambiguities
	foreach my $word (@words){
		my $analyses = @$word[1];
		my @possibleClasses = ();
		
		if(scalar(@$analyses)>1)
		{
			# VERBAL morphology
			
			# -sun
			if(&containedInOtherMorphs($analyses,"+1.Pl.Incl.Subj.Imp","+1.Pl.Incl.Subj.Fut"))
			{
				push(@possibleClasses, "Imp");
				push(@possibleClasses, "Fut");
			}
			# -nqa
			elsif(&containedInOtherMorphs($analyses,"+3.Sg.Subj+Top","+3.Sg.Subj.Fut"))
			{
				push(@possibleClasses, "Top");
				push(@possibleClasses, "Fut");
			}
			# -sqaykiku
			elsif(&containedInOtherMorphs($analyses,"+IPst+1.Pl.Excl.Subj_2.Sg.Obj","+1.Pl.Excl.Subj_2.Sg.Obj.Fut"))
			{
				push(@possibleClasses, "IPst");
				push(@possibleClasses, "Fut");
			}
			# NOMINAL morphology
			# -nkuna
			elsif(&containedInOtherMorphs($analyses,"+3.Pl.Poss+Pl","+3.Sg.Poss+Pl"))
			{
				push(@possibleClasses, "Sg");
				push(@possibleClasses, "Pl");
			}
			# -ykuna
			elsif(&containedInOtherMorphs($analyses,"+1.Pl.Excl.Poss+Pl","+1.Sg.Poss+Pl"))
			{
				push(@possibleClasses, "Sg");
				push(@possibleClasses, "Pl");
			}
	
			# else: other ambiguities, leave
			else
			{
				push(@possibleClasses, "ZZZ");
			}
		}
		# unambiguous forms: use pos tag, should help with context (hopefully)
		else
		{
			push(@possibleClasses, "ZZZ");
			#push(@possibleClasses, @$analyses[0]->{'pos'});
		}
		push(@$word, \@possibleClasses);
		#print @$word[0].": @possibleClasses\n";
		
	}
	
}

if($mode eq '-3')
{
	# get ambiguities in independent suffixes
	foreach my $word (@words){
		my $analyses = @$word[1];
		my @possibleClasses = ();
		
		if(scalar(@$analyses)>1)
		{
			# -n
			if(&containedInOtherMorphs($analyses,"+DirE","+3.Sg.Poss") )
			{
				push(@possibleClasses, "DirE");
				push(@possibleClasses, "Poss");
			}
			# -pis
			elsif(&containedInOtherMorphs($analyses,"+Loc+IndE","+Add"))
			{
				push(@possibleClasses, "Loc_IndE");
				push(@possibleClasses, "Add");
			}
	
			# -s with Spanish roots: Plural or IndE (e.g. derechus)
			elsif(!&notContainedInMorphs($analyses, "+IndE"))
			{
				foreach my $analisis(@$analyses)
				{
					my $string = $analisis->{'string'};
					if($string =~ /s\[NRootES/  )
					{
						push(@possibleClasses, "Pl");
						push(@possibleClasses, "IndE");
					}
				}
				
			}
			# else: lexical ambiguities, leave
			else
			{
				push(@possibleClasses, "ZZZ");
			}
		}
		# unambiguous forms: use pos tag, should help with context (hopefully)
		else
		{
			push(@possibleClasses, "ZZZ");
			#push(@possibleClasses, @$analyses[0]->{'pos'});
		}
		push(@$word, \@possibleClasses);
		#print @$word[0].": @possibleClasses\n";
		
	}
	
}

my $lastlineEmpty=0;

foreach my $word (@words){
	my $analyses = @$word[1];
	#my $analysis = @$analyses[0];
	#print "pos:".$analysis->{'pos'}."\n";
	#my $analysis2 = @$analyses[1];
	#print $analysis2->{'pos'}."\n";
	my $form = @$word[0];
	my $possibleClasses = @$word[2];
	
	if($form eq '#EOS' ){
		unless($lastlineEmpty == 1){
			print "\n";
			$lastlineEmpty =1;
			next;
		}
	}
	else
	{
		print "$form\t";
		$lastlineEmpty =0;
		# uppercase/lowercase?

#		elsif(substr($form,0,1) eq uc(substr($form,0,1))){
#			print "uc\t";
#		}
#		# lowercase
#		else{
#			print "lc\t";
#		}
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
	

	
		print "\n";
	}
}


sub containedInOtherMorphs{
	my $analyses = $_[0];
	my $string1 = $_[1];
	my $string2 = $_[2];
	
	for(my $j=0;$j<scalar(@$analyses);$j++) 
	{
		my $analysis = @$analyses[$j];
		my $allmorphs = $analysis->{'allmorphs'};
		#print "morphs: $allmorphs  string: $string1\n";
		if($allmorphs =~ /\Q$string1\E/)
		{	
			# check if later analysis has +Term
			for(my $k=$j+1;$j<$k;$k--) 
			{
				my $analysis2 = @$analyses[$k];
				my $postmorphs = $analysis2->{'allmorphs'};
				#print "next: $postmorphs\n";
				if($postmorphs =~ /\Q$string2\E/ )
				{		
					#print "2 found $allmorphs\n";
					#print "2compared with $postmorphs\n";
					return 1;
				}
			}
			# check if previuous analysis has +Term
			for(my $k=0;$k<$j;$k++) 
			{
				my $analysis3 = @$analyses[$k];
				my $premorphs = $analysis3->{'allmorphs'};
				#print "prev: $premorphs\n";
				if($premorphs =~ /\Q$string2\E/)
				{
					#print "3 found $allmorphs\n";
					#print "3 compared with $premorphs\n";
					return 1;
				}
			}
		}
	}
	return 0;
}

sub notContainedInMorphs{
	my $analyses = $_[0];
	my $string = $_[1];
	
	foreach my $analysis (@$analyses)
	{
		my $allmorphs = $analysis->{'allmorphs'};
		if($allmorphs =~ /\Q$string\E/){
			return 0;
		}
	}
	return 1;
}
