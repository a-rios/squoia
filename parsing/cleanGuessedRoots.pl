
#!/usr/bin/perl

use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';

my $num_args = $#ARGV;

if ( $num_args != 1) {
  print STDERR "\nUsage: perl cleanGuessedRoots.pl -aya/-cuz -pis/-pas\n";
  exit;
  }

my $evid = shift @ARGV;
if($evid ne '-aya' and $evid ne '-cuz'){
	print STDERR "invalid option for evidential: $evid , possible options are -aya (-m) or cuz (-n) \n";
	exit;
}

my $add = shift @ARGV;

if($add ne '-pis' and $add ne '-pas'){
	print STDERR "invalid option for additive: $add , possible options are -pis or -pas \n";
	exit;
}

my @words;
my $newWord=1;
my $index=0;
my $analysisStrings ="";

while(<>)
{
	if (/^$/)
	{
		$newWord=1;
		$analysisStrings ="";
	}
	else
	{	
		my ($form, $analysis) = split(/\t/);
		
		# if there is another analysis that is exactly the same: delete one of them
		unless($analysisStrings =~ /\Q##$_##\E/)
		{
			$analysisStrings .= "##$_##";
			my ($root) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$|AdvES|PrepES|ConjES)/ ;
			#print "$analysis\n";
			
			if($root eq ''){
				if($form eq '#EOS'){
					$root = '#EOS';
				}
				else{
					$root = "ZZZ";
				}
			}
			
			my $guessed = 0;
			if($analysis =~ m/(VRootG|NRootG)/){
				$guessed = 1;
			}
			my $np=0;
			if($analysis =~ m/\[NP\]/){
				$np = 1;
			}
			
			my @morphtags =  $analysis =~ m/(\+.+?)\]/g ;
		
			#print "$form: $root morphs: @morphtags\n";
			my %hashAnalysis;
			$hashAnalysis{'pos'} = $root;
			$hashAnalysis{'morph'} = \@morphtags;
			$hashAnalysis{'string'} = $_;
			$hashAnalysis{'guessed'} = $guessed;
			$hashAnalysis{'form'} = $form;
	    
			if($newWord)
			{
				my @analyses = ( \%hashAnalysis ) ;
				#my @word = ($form, \@analyses);
				my @word = $np==1 ? ($form, \@analyses, $np) : ($form, \@analyses);
				push(@words,\@word);
				$index++;
			}
			else
			{
				my $thisword = @words[-1];
				my $analyses = @$thisword[1];
				push(@$analyses, \%hashAnalysis);
				if($np){
					@$thisword[2] =1;
				}
			}
		}
		$newWord=0;	
	 }
	
}


# for guessed roots: keep only the analyses with the shortest possible root

foreach my $word (@words){
	my $analyses = @$word[1];
	my $form = @$word[0];
	my $isNP = @$word[2] ? @$word[2] : 0;
	
	#delete all VRootG's that are Spanish nouns (ending in something like -ito, ión etc)
	for(my $j=0;$j<scalar(@$analyses);$j++) {
			my $analysis = @$analyses[$j];
			my $string = @$analyses[$j]->{'string'};
			
			# if this is a proper names, delete guessed roots
			if($isNP && $analysis->{'guessed'}){
				splice (@{$analyses},$j,1);	
				$j--;
				last;
			}
			# if evid=aya -> delete all analyses where -n has been analysed as DirE
			if($evid eq '-aya' && $string =~ /\Q[^DB][--]m[Amb][+DirE\E/ && scalar(@$analyses)>1){
				splice (@{$analyses},$j,1);	
				$j--;
				#print STDERR "deleted analysis: $string \n";
			}
			# if add=pas -> delete all analyses where -pis has been analysed as +add
			if($add eq '-pas' && $string =~ /\@PISadd/ && scalar(@$analyses)>1){
				# analysis of this word with pis=additive and remove it
				# TODO, insert flag in xfst, -> denk dra z lösche bi de web analyse!
				splice (@{$analyses},$j,1);	
				$j--;
				#print STDERR "deleted analysis: $string \n";
			}			
			
			# if both analysis as -pata and -pa -ta -> delete -pa -ta
			if( $string =~ /\Q]pa[Cas][+Gen][^DB][--]ta[Cas][+Acc]\E/ && scalar(@$analyses)>1 && &hasPata($analyses) ){
				splice (@{$analyses},$j,1);	
				$j--;
			}
			
			my ($root) = ($string =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
			my ($rootPos) = ($string =~ m/\[(.*?Root.*?)\]/ );
#			if($root =~ /iento$/){
#				print "$j: $rootPos : $root: $string";
#			}
			
			if($root =~ /ist[ao]$|ado$|ero$|illo$|ito$|zuel[ao]$|[ai]zo$|simo$|aco$|acho$|ajo$|ismo$|icio$|ancia$|crata$|cracia$|cidio$|cida$|ble$|átic[ao]$|arquía$|iento$|into$|io$/ && $rootPos eq 'VRootG'){
				#get word form, in case this is the only analysis
				my $wordform = @$analyses[$j]->{'form'};
				#print $wordform."\n";
				if(scalar(@$analyses) == 1){
					@$analyses[0]->{'string'} = "$wordform\t$wordform\t\+\?\n";
					@$analyses[0]->{'guessed'} = 0;
				}
				else{
					splice (@{$analyses},$j,1);	
					$j--;
				}
			}
			# delete 3.Sg.Poss  analysis
			if($string =~ /\Qio[NRootG][^DB][--]n[NPers][+3.Sg.Poss]\E/ or $string =~ /\Qó[NRootG][^DB][--]n[NPers][+3.Sg.Poss]\E/ or $string =~ /\Qcho[NRootG][^DB][--]n[NPers][+3.Sg.Poss]\E/ or $string =~ /\Qio[VRootG][^DB][--]n[VPers][+3.Sg.Subj]\E/ or $string =~ /\Qcho[VRootG][^DB][--]n[VPers][+3.Sg.Subj]\E/  )
			{
				#get word form, in case this is the only analysis
				my $wordform = @$analyses[$j]->{'form'};
				#print $wordform."\n";
				if(scalar(@$analyses) == 1){
					@$analyses[0]->{'string'} = "$wordform\t$wordform\t\+\?\n";
					@$analyses[0]->{'guessed'} = 0;
				}
				else{
					splice (@{$analyses},$j,1);	
					$j--;
				}
			}
			# delete  DirE analysis
			if($string =~ /\Qio[NRootG][^DB][--]m[Amb][+DirE]\E/ or $string =~ /\Qó[NRootG][^DB][--]m[Amb][+DirE]\E/ or $string =~ /\Qcho[NRootG][^DB][--]m[Amb][+DirE]\E/ ) 
			{
				#get word form, in case this is the only analysis
				my $wordform = @$analyses[$j]->{'form'};
				if(scalar(@$analyses) == 1){
					@$analyses[0]->{'string'} = "$wordform\t$wordform\t\+\?\n";
					@$analyses[0]->{'guessed'} = 0;
				}
				else{
					splice (@{$analyses},$j,1);	
					$j--;
				}
			}
			# delete IndE analysis
			if($string =~ /\Qti[NRootG][^DB][--]s[Amb][+IndE]\E/ or $string =~ /\Qe[NRootG][^DB][--]s[Amb][+IndE]\E/ or $string =~ /\Qo[NRootG][^DB][--]s[Amb][+IndE]\E/ or $string =~ /\Qa[NRootG][^DB][--]s[Amb][+IndE]\E/  )
			{
				#get word form, in case this is the only analysis
				my $wordform = @$analyses[$j]->{'form'};
				if(scalar(@$analyses) == 1){
					@$analyses[0]->{'string'} = "$wordform\t$wordform\t\+\?\n";
					@$analyses[0]->{'guessed'} = 0;
				}
				else{
					splice (@{$analyses},$j,1);	
					$j--;
				}
			}
	}
	#find proper names -> find longest root  (can be more than one!)
	if($isNP){
		my $string = @$analyses[0]->{'string'};
		my ($longestRoot) = ($string =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
		my $length = length($longestRoot);
		
		# find longest root
		for(my $j=0;$j<scalar(@$analyses);$j++) {
			my $analysis = @$analyses[$j];
			my $stringTest = $analysis->{'string'};
			#print $stringTest;
			my ($longestRootTest) = ($stringTest =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
			if(length($longestRootTest)>$length && length($longestRootTest)>2){
				$longestRoot = $longestRootTest;
				$length = length($longestRootTest);
			}
			# if root in first analysis was only 2
			elsif($length<3){
				$longestRoot = $longestRootTest;
				$length = length($longestRootTest);
			}
		}
		
		#print "shortest: $shortestRoot, $length\n";
		#delete all analyses with other roots than $shortestRoot
		for(my $j=0;$j<scalar(@$analyses);$j++) {
			my $analysis = @$analyses[$j];
			my $stringTest = $analysis->{'string'};
			my ($longestRootTest) = ($stringTest =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
			unless($longestRoot eq $longestRootTest){
				splice (@{$analyses},$j,1);	
				$j--;
				#print "remove: $stringTest";
			}
		}
	}
	
	# find guessed roots -> take shortest (can be more than one!)
	if(@$analyses[0]->{'guessed'} == 1){
		#print @$analyses[0]->{'string'}."\n";
		my $string = @$analyses[0]->{'string'};
		my ($shortestRoot) = ($string =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
		my $length = length($shortestRoot);
		#print $shortestRoot." length: ".length($shortestRoot)."\n";
		
		# find shortest root
		for(my $j=0;$j<scalar(@$analyses);$j++) {
			my $analysis = @$analyses[$j];
			my $stringTest = $analysis->{'string'};
			#print $stringTest;
			my ($shortestRootTest) = ($stringTest =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
			if(length($shortestRootTest)<$length && length($shortestRootTest)>2){
				$shortestRoot = $shortestRootTest;
				$length = length($shortestRootTest);
			}
			# if root in first analysis was only 2
			elsif($length<3){
				$shortestRoot = $shortestRootTest;
				$length = length($shortestRootTest);
			}
		}
		
		#print "shortest: $shortestRoot, $length\n";
		#delete all analyses with other roots than $shortestRoot
		for(my $j=0;$j<scalar(@$analyses);$j++) {
			my $analysis = @$analyses[$j];
			my $stringTest = $analysis->{'string'};
			my ($shortestRootTest) = ($stringTest =~ m/([A-Za-zñéóúíáüÑ']+?)\[/ );
			unless($shortestRoot eq $shortestRootTest){
				splice (@{$analyses},$j,1);	
				$j--;
				#print "remove: $stringTest";
			}
		}
		
#		print "after deletion: \n";
#		for(my $j=0;$j<scalar(@$analyses);$j++) {
#			my $analysis = @$analyses[$j];
#			print $analysis->{'string'};
#		}
#		print "\n";
		
	}

}

sub hasPata{
	my $analyses = $_[0];
	foreach my $analysis (@$analyses){
		if($analysis->{'string'} =~ /--\]pata\[NRoot/){
			return 1;
		}
	}
	return 0;
}
	
	foreach my $word (@words){
		my $analyses = @$word[1];
		foreach my $analysis (@$analyses){
			print $analysis->{'string'};
		}
		print "\n";
	}
	
