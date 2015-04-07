
#!/usr/bin/perl

use strict;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';


#!/usr/bin/perl

# print out sentences from disambiguated xfst
# in case a word still remains ambiguous: print first option as default

use strict;
use utf8;
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';


#print "$order\t$wordform\t_\t$pos\t$pos\t$morphstring\t$head\t$label\t_\t_\n";

my $index=1;

# needs fully disambiguated xfst
my $line=1;

while(<STDIN>){
		#print "line $line\t\t";
		
		if (/#EOS/)
		{
			print "$index\tVROOT\t_\t_\t_\t_\t0\tsentence\t_\t_\n\n";
			$index=1;
		}
		# words that don't have an analysis
		elsif(/\+\?/){
			my ($word, $rest)= split(/\t/);
			print "$index\t$word\t_\t_\t_\t_\t_\t_\t_\t_\n";
		}
		else
		{	
			unless(/^\s*$/){
				my ($word, $analysis) = split(/\t/);
				#print $form."\t";
				
				my @IGs = split(/\Q[^DB]\E/, $analysis);
	
				
				foreach my $ig (@IGs){
					print "$index\t";

					my @morphemeforms = ($ig =~ m/([A-Za-zñéóúíáäöüÑÁÉÍÓÚÄÖÜ']+?[ºª\.]?)\[/g );
					my $form ="";
					foreach my $m (@morphemeforms){
						$form .= $m;
					}
					if($ig =~ /\[\$.|CARD/){
						$form = $word;
					}
					
					if($ig =~ /^\[--\]/){
						print "-$form\t";
					}
					else{
						print $form."\t";
					}
					# no lemma, print "_"
					print "_\t";
				
				    # special case PrnPers, contains '+', special case word '-'
					my @posTags = ($ig =~ m/\[([^\+=\]\-]+|PrnPers[^\]]+|\$\-)\]/g);
					if(@posTags[0] =~ /^\$/ ){
						$posTags[0] = '$.';
					}

					my @morphemetags  = ($ig =~ m/\[(\+.+?)\]/g );
					
					if(@posTags[0] =~ /Root|^Prn|^Part/ or @posTags[0] eq 'NP'){
						    # for roots: pos is always Root, and morph tag is the type of root (NRoot, VRoot etc)
						    unshift(@morphemetags, @posTags[0]);
							#$morphemetags[0] = @posTags[0];
							@posTags[0] = "Root";
					}
					 # print pos and cpos (same)
					my $pos = @posTags[0];
					for(my $i=1;$i<scalar(@posTags);$i++){

						$pos .= "_".@posTags[$i];
					}
					print "$pos\t$pos\t";
					
					#if root: get trans=translation given and print after pos-morphtag-pairs
					my $translation;
					if($ig =~  /\[=.+\]/ ){
						($translation) = ($ig =~ m/\[=([A-Za-zñéóúíáüÑ'_,]+?)\]/ );
						push(@morphemetags, $translation);
				  		push(@posTags, "trans");
					}
					
					if(scalar(@morphemetags) == 0){
						print "_\t";
					}
					else{
						# print pos-morphtag-pairs, Root=VRoot|VDeriv=+Rflx_Int etc.
						for(my $i=0;$i<scalar(@posTags);$i++){
							
							# last element, add \t
							if($i== (scalar(@posTags)-1)){
								print @posTags[$i]."=".@morphemetags[$i]."\t";
							}
							else{
								print @posTags[$i]."=".@morphemetags[$i]."|";
							}
						}
					}
					
					# head and label, empty
					print "_\t_\t_\t_";
					
					print "\n";
					$index++;
				}
				
				
				
				#print "igs: @IGs\n";
				
				#my ($root) = $analysis =~ m/^([^\[]+?)\[/ ;
				#print "$root\n";

			}
		}
		
$line++;
		
}
		

