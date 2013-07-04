
#!/usr/bin/perl

use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';

my $num_args = $#ARGV;



my @words;
my $newWord=1;
my $index=0;

while(<>)
{
	if (/^$/)
	{
		$newWord=1;
	}
	else
	{	
		my ($form, $analysis) = split(/\t/);
	
		my ($root) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$)/ ;
		
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
		
		my @morphtags =  $analysis =~ m/(\+.+?)\]/g ;
	
		#print "$form: $root morphs: @morphtags\n";
		my %hashAnalysis;
		$hashAnalysis{'pos'} = $root;
		$hashAnalysis{'morph'} = \@morphtags;
		$hashAnalysis{'string'} = $_;
		$hashAnalysis{'guessed'} = $guessed;
    
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


# for guessed roots: keep only the analyses with the shortest possible root

foreach my $word (@words){
	my $analyses = @$word[1];
	my $form = @$word[0];

	# find guessed roots
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
			print $stringTest;
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
		
		print "shortest: $shortestRoot, $length\n\n";
		
	}

}