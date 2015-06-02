#!/usr/bin/perl

use strict;
use utf8;
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDERR, ':utf8';
binmode STDOUT, ':utf8';

my $num_args = $#ARGV;

if ( $num_args > 0) {
  print STDERR "\nUsage: perl disambXfst2lm.pl \n";
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
	}
	else
	{	
		my ($form, $analysis) = split(/\t/);
		

			my ($roottag) = $analysis =~ m/(ALFS|CARD|NP|NRoot|Part|VRoot|PrnDem|PrnInterr|PrnPers|SP|\$|AdvES|PrepES|ConjES)/ ;
			
			my $rootform;
			my @morphs;
			my @morphforms;
			my @morphtags;
			#print $analysis."\n";
			if($analysis =~ /\[VS\]/)
			{
				my @rootAndmorphs = split ('VS\]\[\+.+?\]', $analysis);
				my @rootforms = (@rootAndmorphs[0] =~ m/([A-Za-zñéóúíáüäöÑ']+?)\[/g) ;
				foreach my $r (@rootforms){
					$rootform .= $r;
				}
				@morphs = split('\[--\]' , @rootAndmorphs[1]);
				#@morphforms = (@rootAndmorphs[1] =~ m/([A-Za-zñéóúíáüäöÑ']+?)\[/g) ;
				@morphtags =  (@rootAndmorphs[1] =~ m/(\+.+?)\]/g );
				#print "root only: $rootform, @morphforms\n";
			}
			elsif($analysis =~ /\[\$.\]/){
				($rootform) = ($analysis =~  /(.)\[\$.\]/ );
			}
			elsif($analysis =~ /\[CARD\]/){
				($rootform) = ($analysis =~  /(.)\[CARD\]/ );
			}
			elsif($_ =~ /\+\?/){
				$rootform = $form;
			}
			else{
				($rootform) = ($analysis =~ m/^([A-Za-zñéóúíáüäöÑ']+?)\[/) ;
				@morphs = split('\[--\]' , $analysis);
				@morphtags =  $analysis =~ m/(\+.+?)\]/g ;
				#@morphforms = ($analysis =~ m/([A-Za-zñéóúíáüäöÑ']+?)\[/g) ;
			
			}
			
			#print "root: $rootform morphs: @morphtags\n";
			
			#print "$analysis\n";
			
			
			
			my $guessed = 0;
			if($analysis =~ m/(VRootG|NRootG)/){
				$guessed = 1;
			}
			my $np=0;
			if($analysis =~ m/\[NP\]/){
				$np = 1;
			}
			
			# replace certain tags of specific suffixes 
			$analysis =~ s/\Q[--]tiya[VDeriv][+Sml]\E/\Q[--]tiya[VDeriv][+Disk]\E/g; 
			$analysis =~ s/\Q[--]niraq[NDeriv][+Sim]\E/\Q[--]niraq[NDeriv][+Siml]\E/g; 
			$analysis =~ s/\Qnya[VDeriv][+Cont]\E/\Qnya[VDeriv][+VCont]\E/g; 
			
			
			
			foreach my $mtag (@morphtags){
				$mtag =~ s/\+Priv/\+Abss/g;
				$mtag =~ s/\+Asmp_Emph/\+Asmpemph/g;
				$mtag =~ s/\+Cis_Trs/\+Cis/g;
				$mtag =~ s/\+Con_Inst/\+Instr/g;
				$mtag =~ s/\+Con_Intr/\+Intr/g;
				$mtag =~ s/\+Dat_Ill/\+Dat/g;
				$mtag =~ s/\+Dir_Emph/\+DirEemph/g;
				$mtag =~ s/\+Intr_Neg/\+Neg/g;
				$mtag =~ s/\+IndE_Emph/\+IndEemph/g;
				$mtag =~ s/\+Intr_Neg/\+Neg/g;
				$mtag =~ s/\+Lim_Aff/\+Lim/g;
				$mtag =~ s/\+Rflx_Int/\+Rflx/g;
				$mtag =~ s/\+Rgr_Iprs/\+Iprs/g;
				$mtag =~ s/\+SS_sim/\+SSsim/g;
			}



		
			#print "$form: $rootform morphs: @morphtags\n";
			my %hashAnalysis;
			$hashAnalysis{'pos'} = $roottag;
			$hashAnalysis{'morph'} = \@morphtags;
			$hashAnalysis{'string'} = $_;
			$hashAnalysis{'guessed'} = $guessed;
			$hashAnalysis{'form'} = $form;
			$hashAnalysis{'rootform'} = $rootform;
	    
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
		$newWord=0;	
	 }
	
}

foreach my $word (@words){
	my $analyses = @$word[1];
	my $form = @$word[0];
	my $isNP = @$word[2] ? @$word[2] : 0;
	my $rootform =  @$analyses[0]->{'rootform'} ;
	my @morphs = @{@$analyses[0]->{'morph'} } ;
	my $string =  @$analyses[0]->{'string'} ;
	
	# split portmanteau verb suffixes
	#.Fut (MT: sometimes (if 'ir a'..)+Fut)
	#.Hab  (MT: sometimes (if 'suele+inf') +Hab)
	#.Imp (MT: sometimes +Imp)
	## --> ignore
	
	#my $analysis = @$analyses[0];
	if($isNP){
		print "NP ";
		&printMorphs(\@morphs);
	}
	elsif($form =~ /#EOS/){
		print "\n";
	}
	else{
		print "$rootform ";
		&printMorphs(\@morphs);
	}
	
}

sub printMorphs{
	my @morphs = @{$_[0]};
	my $hasWA = 0;
	my $hasSU =0;
	foreach my $m (@morphs){
		if($m eq '+1.Obj'){
			$hasWA=1;
		}
		elsif($m eq '+2.Obj'){
			$hasSU=1;
		}
		#print "$m ";
		# portmanteau forms: obj-subj
		if($m =~ /Subj\_.+Obj/){
			my ($subj, $obj) = split('_', $m);
			# if no number assigned, assume singular
			if($subj eq '+3.Subj' && $obj =~ /Fut$/){
				$subj = '+3.Sg.Subj +Fut'
			}
			elsif($subj eq '+3.Subj' && $obj =~ /Imp$/){
				$subj = '+3.Sg.Subj +Imp'
			}
			# check if already -wa or -su present, if not, print $obj
			if($obj =~ /^\+1/ && !$hasWA){
				print "$obj $subj ";
			}
			elsif($obj =~ /^\+2/ && !$hasSU){
				print "$obj $subj ";
			}
			# if already -wa or -su in morphs: print only subj
			else{
				print "$subj ";
			}
			#print "OBJ:$obj SUBJ:$subj ";
		}
		else{
			print "$m ";
		}
	}
}
	
	
	
	