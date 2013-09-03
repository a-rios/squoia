use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';
use Storable;

my @words;
my $newWord=1;
my %suggestions;

my $num_args = $#ARGV + 1;
if ($num_args != 1) {
  print STDERR "\nUsage: perl getSuggestions.pl -1 (output of chain.bin) or -2 (output of fmed) \n";		
  exit;
}

my $mode = $ARGV[0];

if($mode eq '-1')
{
	while(<STDIN>)
	{
			if (/^$/)
			{
				$newWord=1;
			}
			else
			{	
				s/\n//g;
				my ($form, $suggestion) = split(/\t/);
				#print $form."\n";
			
			
				if($newWord)
				{
					my @analyses = ( $suggestion ) ;
					my @word = ($form, \@analyses);
					push(@words,\@word);
				}
				else
				{
					my $thisword = @words[-1];
					my $analyses = @$thisword[1];
					unless(grep {$_ =~ /\Q$suggestion\E/} @$analyses){
						push(@$analyses, $suggestion);
					}
				}
				$newWord=0;	
		 }
			
	}


	store \@words, 'spellcheckedWords';
	
	foreach my $word (@words)
	{
			my $suggestions = @$word[1];
			my $form = @$word[0];
			if(grep {$_ =~ /\Q+?\E/} @$suggestions)
			{
				print "$form\n";
			}
	}
}

if($mode eq '-2')
{
	my $i=0;
	my $new=1;
	my $corr;
	my $spellcheckedWord;
	my @spellcheckedWords;
	my %spellings;
	while(<STDIN>)
	{
	 	unless(/Cost\[f\]:/ or /^Calculating\sheuristic/ or /^Using\sconfusion\smatrix/ ) 
		{		 
			 if (/^$/) {
		 	 	$new = 1;
			 }
			 else
			 {
			 	chomp;
			 	if ($new) 
			 	{
				   $corr = $_;
				   $new = 0;
				 }
				else 
				{
				   $spellcheckedWord = $_;
				   if ($i==0 or ($spellcheckedWords[$i-1] ne $spellcheckedWord))
				   {
					    $spellcheckedWords[$i] = $spellcheckedWord;
					    $i++;
				   }
				   $spellings{$spellcheckedWord}{$corr}=1;
				}
			 }
		}	
	}
			
#	foreach my $spword (@spellcheckedWords) 
#	{
#		 print "$spword:\n";
#		 
#		 foreach $corr (keys %{$spellings{$spword}}) {
#		  print "\t$corr\n";
#		 }
#	}
	
	
	my $wordsref = retrieve('spellcheckedWords');
	@words = @$wordsref;
	
	foreach my $word (@words)
	{
			my $suggestions = @$word[1];
			my $form = @$word[0];
			print "$form:\n";
			if(grep {$_ =~ /\Q+?\E/} @$suggestions)
			{
				foreach my $corr (keys %{$spellings{$form}}) {
				  print "\t$corr\n";
				}
			}
			else{
				foreach my $s (@$suggestions)
				{
					print  "\t$s\n";
				}
			}
	}
}
#foreach my $word (@words)
#{
#		my $suggestions = @$word[1];
#		my $form = @$word[0];
#		
#		print STDERR "word: $form ";
#		foreach my $s (@$suggestions){
#			print STDERR "$s ";
#		}
#		print STDERR "\n";
#}