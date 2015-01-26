#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
#use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';
use strict;
use XML::LibXML;

#read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

# remove xmlns
#$dom->documentElement()->removeAttribute( 'XML::LibXML::Namespace::xmlns' );
$dom->documentElement()->setAttribute( 'xmlns' , '' );

my $num_args = $#ARGV + 1;
if ($num_args != 1) {
	print STDERR "usage: pml2xfst -norm/-wild\n";
	exit;
}
my $mode = $ARGV[0];

#print $dom->documentElement();

my %mapTagsToSuffixFormsNormalized = (	
  	'+Abl'         => 'manta',
     '+Abtmp'         => 'pacha',
     '+Acc'         => 'ta',
     '+Add'         => 'pas',
     '+Aff'         => 'yk[ua]',
     '+Ag'         => 'q',
     '+Aprx'         => 'niq',
     '+Asmp'         => 'ch(a)?',
     '+Asmp_Emph'         => 'chá',
     '+Ass'         => 'ysi',
     '+Aug'         => 'su',
     '+Autotrs'         => 'lli',
     '+Ben'         => 'paq',
     '+Caus'         => 'chi',
     '+Char'         => 'ti|li',
     '+Cis_Trs'         => 'm(u)?',
     '+Cont'         => 'nya|raq',
     '+Con_Inst'         => 'wan',
     '+Con_Intr'         => 'taq',
     '+DS'         => 'pti',
     '+Dat_Ill'         => 'man',
     '+Def'         => 'puni',
     '+Des'         => 'naya',
     '+Desesp'         => 'pasa',
     '+Dim'         => 'cha',
     '+Dir'         => 'rk[ua]|rp[ua]|tata|thapi|kipa|kata|qa',
     '+DirE'         => 'm(i)?',
     '+DirE_Emph'         => 'má',
     '+Disc'         => 'ña',
     '+Dist'         => 'kama',
     '+Distr'         => 'nka',
     '+Dub'         => 's[iu]na',
     '+Emph'         => 'y[aá]',
     '+Fact'         => 'cha',
     '+Gen'         => 'p(a)?',
     '+IPst'         => 'sqa',
     '+Iclsv'         => '(ni)?ntin',
     '+Inch'         => 'ri',
     '+IndE'         => 's(i)?',
     '+IndE_Emph'         => 'sá',
     '+Inf'         => 'y',
     '+Int'         => '[yr]pari',
     '+Intrup'         => '(y)?kacha',
     '+Intr_Neg'         => 'chu',
     '+Intsoc'         => 'pura',
     '+Kaus'         => 'rayku',
     '+Lim_Aff'         => 'lla',
     '+Loc'         => 'pi',
     '+MPoss'         => 'sapa',
     '+MRep'         => '(r)?paya',
     '+Multi'         => 'rqari',
     '+NPst'         => 'rqa',
     '+Neg'         => 'chu',
     '+Obl'         => 'na',
     '+Perdur'         => 'raya',
     '+Perf'         => 'sqa',
     '+Pl'         => 'kuna',
     '+Posi'         => 'mpa',
     '+Poss'         => '(ni)?yuq',
     '+Pot'         => 'man',
     '+Priv'         => 'nnaq',
     '+Prog'         => 'chka',
     '+Proloc'         => '(ni)?nta',
     '+QTop'         => 'ri',
     '+Rel'         => 'n',
     '+Rem'         => 'ymana',
     '+Rep'         => 'pa',
     '+Res'         => '(r)?iki',
     '+Reub'         => 'na',
     '+Rflx_Int'         => 'k[ua]',
     '+Rgr_Iprs'         => 'p[ua]',
     '+Rptn'         => 'rq[ua]',
     '+Rzpr'         => 'na',
     '+SS'         => 'spa',
     '+SS_Sim'         => 'stin',
     '+Sim'         => 'hina|nira[qy]?|rikuq',
     '+Sml'         => 'tiya|(y)?kacha',
     '+Soc'         => 'puwan',
     '+Stat_Multi'         => 'yqari',
     '+Term'         => 'kama',
     '+Top'         => 'qa',
     '+Trs'         => 'ya',
     '+Vdim'         => 'cha',
     '+1.Obj'         => 'wa',
     '+1.Poss'         => '(ni)?y',
     '+1.Pl.Excl.Poss'         => '(ni)?yku',
     '+1.Pl.Excl.Subj'         => 'yku',
     '+1.Pl.Excl.Subj.Fut'         => 'saqku',
     '+1.Pl.Excl.Subj_2.Sg.Obj'         => 'ykiku',
     '+1.Pl.Excl.Subj_2.Sg.Obj.Fut'         => 'sqaykiku',
     '+1.Pl.Incl.Poss'         => '(ni)?nchik',
     '+1.Pl.Incl.Subj'         => 'nchik',
     '+1.Pl.Incl.Subj.Fut'         => 'sun(chik)?',
     '+1.Pl.Incl.Subj.Pot'         => 'chwanchik|waqninchik',
     '+1.Pl.Incl.Subj.Imp'         => 'sun',
     '+1.Sg.Poss'         => '(ni)?y',
     '+1.Sg.Subj'         => 'ni',
     '+1.Sg.Subj.Fut'         => 'saq',
     '+1.Sg.Subj.Pot'         => 'yman',
     '+1.Sg.Subj_2.Pl.Obj'         => 'ykichik',
     '+1.Sg.Subj_2.Pl.Obj.Fut'         => 'sqaykichik',
     '+1.Sg.Subj_2.Sg.Obj'         => 'yki',
     '+1.Sg.Subj_2.Sg.Obj.Fut'         => 'sqayki',
     '+2.Obj'         => 'su',
     '+2.Pl.Poss'         => '(ni)?ykichik',
     '+2.Pl.Subj'         => 'nkichik',
     '+2.Pl.Subj.Pot'         => 'waqchik',
     '+2.Pl.Subj_1.Sg.Obj.Imp'         => 'waychik',
     '+2.Sg.Subj.Imp'         => 'y',
     '+2.Pl.Subj.Imp'         => 'ychik',
     '+2.Sg.Poss'         => '(ni)?yki',
     '+2.Sg.Subj'         => 'nki',
     '+2.Sg.Subj.Pot'         => 'waq',
     '+2.Sg.Subj_1.Pl.Excl.Obj'         => 'nkiku',
     '+2.Sg.Subj_1.Pl.Obj.Imp'         => 'yku',
     '+3.Poss'         => '(ni)?n',
     '+3.Pl.Subj.IPst'         => 'sqaku',
     '+3.Pl.Poss'         => '(ni)?nku',
     '+3.Pl.Subj'         => 'nku',
     '+3.Pl.Subj.Fut'         => 'nqaku',
     '+3.Pl.Subj.Hab'         => 'qku',
     '+3.Pl.Subj.Pot'         => 'nmanku',
     '+3.Pl.Subj_2.Sg.Obj'         => 'sunkiku',
     '+3.Pl.Subj.NPst'         => 'rqaku',
     '+3.Pl.Subj.Imp'         => 'chunku',
     '+3.Sg.Subj.IPst'         => 'sqa',
     '+3.Sg.Subj.Imp'         => 'chun',
     '+3.Subj_1.Pl.Excl.Obj'         => 'wanku',
     '+3.Sg.Subj.NPst'         => 'rqa',
     '+3.Sg.Poss'         => '(ni)?n',
     '+3.Sg.Subj'         => 'n',
     '+3.Sg.Subj.Fut'         => 'nqa',
     '+3.Subj_1.Pl.Excl.Obj.Fut'         => 'wanqaku',
     '+3.Subj_1.Pl.Incl.Obj'         => 'nchik',
     '+3.Subj_1.Pl.Incl.Obj.Fut'         => 'sunchik',
     '+3.Subj_2.Pl.Obj'         => 'ykichik',
     '+3.Subj_2.Sg.Obj'         => 'sunki|nki',
	);


my %mapTagsToSuffixFormsNotNormalized = (	
  	'+Abl'         => 'manta',
     '+Abtmp'         => 'pacha',
     '+Acc'         => 'ta',
     '+Add'         => 'pas|pis',
     '+Aff'         => 'y(k)?[ua]|y',
     '+Ag'         => 'q',
     '+Aprx'         => 'n[ie]q',
     '+Asmp'         => 'ch(a)?',
     '+Asmp_Emph'         => 'chá',
     '+Ass'         => 'ysi|schi',
     '+Aug'         => 'su',
     '+Autotrs'         => 'lli',
     '+Ben'         => 'paq',
     '+Caus'         => 'chi',
     '+Char'         => 'ti|li',
     '+Cis_Trs'         => 'm(u)?|n',
     '+Cont'         => 'nya|raq',
     '+Con_Inst'         => 'wan',
     '+Con_Intr'         => 'taq',
     '+DS'         => '[qp]ti',
     '+Dat_Ill'         => 'man',
     '+Def'         => 'puni',
     '+Des'         => 'naya',
     '+Desesp'         => 'pasa',
     '+Dim'         => 'cha|ka',
     '+Dir'         => 'rk[ua]|rp[ua]|tata|thapi|kipa|kata|qa',
     '+DirE'         => 'm(i)?|n',
     '+DirE_Emph'         => 'má',
     '+Disc'         => 'ña',
     '+Dist'         => 'kama',
     '+Distr'         => 'nka',
     '+Dub'         => 's[iu]na',
     '+Emph'         => 'y[aá]',
     '+Fact'         => 'cha',
     '+Gen'         => 'p(a)?|q',
     '+IPst'         => 'sqa',
     '+Iclsv'         => '([nñ]i)?ntin',
     '+Inch'         => 'ri',
     '+IndE'         => 's(i)?',
     '+IndE_Emph'         => 'sá',
     '+Inf'         => 'y',
     '+Int'         => '[yr]pari',
     '+Intrup'         => '(y)?kacha',
     '+Intr_Neg'         => 'chu',
     '+Intsoc'         => 'pura',
     '+Kaus'         => 'rayku',
     '+Lim_Aff'         => 'lla',
     '+Loc'         => 'pi',
     '+MPoss'         => 'sapa',
     '+MRep'         => '(r)?paya',
     '+Multi'         => 'rqari',
     '+NPst'         => 'r(q)?a',
     '+Neg'         => 'chu',
     '+Obl'         => 'na',
     '+Perdur'         => 'raya',
     '+Perf'         => 'sqa',
     '+Pl'         => 'kuna',
     '+Posi'         => 'mpa',
     '+Poss'         => '([nñ]i)?y[uo]q',
     '+Pot'         => 'man',
     '+Priv'         => 'nnaq',
     '+Prog'         => 'chka|sha|sa|sya',
     '+Proloc'         => '([nñ]i)?nta',
     '+QTop'         => 'ri',
     '+Rel'         => 'n',
     '+Rem'         => 'ymana',
     '+Rep'         => 'pa',
     '+Res'         => '(r)?iki',
     '+Reub'         => 'na',
     '+Rflx_Int'         => 'k[ua]',
     '+Rgr_Iprs'         => 'p[ua]',
     '+Rptn'         => 'r(q)?[ua]',
     '+Rzpr'         => 'na',
     '+SS'         => 'spa',
     '+SS_Sim'         => 'stin',
     '+Sim'         => 'hina|nira[qy]?|rikuq',
     '+Sml'         => 'tiya|(y)?kacha',
     '+Soc'         => 'puwan|piwan',
     '+Stat_Multi'         => 'yqari',
     '+Term'         => 'kama',
     '+Top'         => 'qa',
     '+Trs'         => 'ya',
     '+Vdim'         => 'cha',
     '+1.Obj'         => 'wa',
     '+1.Poss'         => '([nñ]i)?y',
     '+1.Pl.Excl.Poss'         => '([nñ]i)?yku',
     '+1.Pl.Excl.Subj'         => 'yku',
     '+1.Pl.Excl.Subj.Fut'         => 'saqku',
     '+1.Pl.Excl.Subj_2.Sg.Obj'         => 'ykiku',
     '+1.Pl.Excl.Subj_2.Sg.Obj.Fut'         => 'sqaykiku',
     '+1.Pl.Incl.Poss'         => '([nñ]i)?nchi[ksqj]',
     '+1.Pl.Incl.Subj'         => 'nchi[ksqj]',
     '+1.Pl.Incl.Subj.Fut'         => 'sun(chi[ksqj])?',
     '+1.Pl.Incl.Subj.Pot'         => 'chwanchi[ksqj]|waqninchi[ksqj]',
     '+1.Pl.Incl.Subj.Imp'         => 'sun',
     '+1.Sg.Poss'         => '([nñ]i)?y',
     '+1.Sg.Subj'         => 'ni',
     '+1.Sg.Subj.Fut'         => 'saq',
     '+1.Sg.Subj.Pot'         => 'yman',
     '+1.Sg.Subj_2.Pl.Obj'         => 'ykichi[ksqj]',
     '+1.Sg.Subj_2.Pl.Obj.Fut'         => 'sqaykichi[ksqj]',
     '+1.Sg.Subj_2.Sg.Obj'         => 'yki',
     '+1.Sg.Subj_2.Sg.Obj.Fut'         => 'sqayki',
     '+2.Obj'         => 'su',
     '+2.Pl.Poss'         => '([nñ]i)?ykichi[ksqj]',
     '+2.Pl.Subj'         => 'nkichi[ksqj]',
     '+2.Pl.Subj.Pot'         => 'waqchi[ksqj]',
     '+2.Pl.Subj_1.Sg.Obj.Imp'         => 'waychi[ksqj]',
     '+2.Sg.Subj.Imp'         => 'y',
     '+2.Pl.Subj.Imp'         => 'ychi[ksqj]',
     '+2.Sg.Poss'         => '([nñ]i)?yki',
     '+2.Sg.Subj'         => 'nki',
     '+2.Sg.Subj.Pot'         => 'waq',
     '+2.Sg.Subj_1.Pl.Excl.Obj'         => 'nkiku',
     '+2.Sg.Subj_1.Pl.Obj.Imp'         => 'yku',
     '+3.Poss'         => '([nñ]i)?n',
     '+3.Pl.Subj.IPst'         => 'sqaku',
     '+3.Pl.Poss'         => '([nñ]i)?nku',
     '+3.Pl.Subj'         => 'nku',
     '+3.Pl.Subj.Fut'         => 'nqaku',
     '+3.Pl.Subj.Hab'         => 'qku',
     '+3.Pl.Subj.Pot'         => 'nmanku',
     '+3.Pl.Subj_2.Sg.Obj'         => 'sunkiku',
     '+3.Pl.Subj.NPst'         => 'rqaku',
     '+3.Pl.Subj.Imp'         => 'chunku',
     '+3.Sg.Subj.IPst'         => 'sqa',
     '+3.Sg.Subj.Imp'         => 'chun',
     '+3.Subj_1.Pl.Excl.Obj'         => 'wanku',
     '+3.Sg.Subj.NPst'         => 'rqa',
     '+3.Sg.Poss'         => '([nñ]i)?n',
     '+3.Sg.Subj'         => 'n',
     '+3.Sg.Subj.Fut'         => 'nqa',
     '+3.Subj_1.Pl.Excl.Obj.Fut'         => 'wanqaku',
     '+3.Subj_1.Pl.Incl.Obj'         => 'nchi[ksqj]',
     '+3.Subj_1.Pl.Incl.Obj.Fut'         => 'sunchi[ksqj]',
     '+3.Subj_2.Pl.Obj'         => 'ykichi[ksqj]',
     '+3.Subj_2.Sg.Obj'         => 'sunki|nki',
	);


foreach my $sentence  ( $dom->getElementsByTagName('s'))
{
	# for debugging:
	print STDERR "sentence: ".$sentence->getAttribute('id')."\n";
	
	my @terminals = $sentence->findnodes('descendant::terminal');
	#print "length terminals: ".scalar(@terminals)."\n";
	
	# sort by order
	my @sorted = sort { @{$a->findnodes('order')}[0]->textContent <=> @{$b->findnodes('order')}[0]->textContent } @terminals;

	my $wordform = '';
	my $analysis ='';

	for(my $i=0; $i<scalar(@sorted); $i++)
	{	
		my $terminal = @sorted[$i];
		my $posNode = @{$terminal->findnodes('pos')}[0];
		# do not print DUMMY's
		unless( $posNode && $posNode->textContent eq 'DUMMY')
		{
			my $token = @{$terminal->findnodes('word')}[0]->textContent;
			#print STDERR "terminal: ".@{$t->findnodes('word')}[0]->textContent."  ".@{$t->findnodes('order')}[0]->textContent."\n";
			#print "acutal token: $token \n";
			if( &isNewWord($token) and $i != scalar(@sorted)-1 and $i>0 ){
				# delete [^DB] after last suffix
				$analysis =~ s/(\[\^DB\])?\[--\]$//;
				#print "w $i: $wordform\t$analysis";
				print "$wordform\t$analysis";
				print "\n\n";
				
				$wordform = $token; 
				$analysis =	&getAnalysis($terminal);
			}
			# last token: print
			elsif($i == scalar(@sorted)-1 ){
				# new word: print last word, then print this
				if(&isNewWord($token)){
					# delete [^DB] after last suffix
					$analysis =~ s/(\[\^DB\])?\[--\]$//;
					print "$wordform\t$analysis\n\n";
					$wordform = $token;
					$analysis = &getAnalysis($terminal);
					print "$wordform\t$analysis\n\n";
				}
				#if part of the previous word:
				else{
					# delete '-' in morphemes
					$token =~ s/^-(.)/\1/;
					$wordform .= $token;
					$analysis .= &getAnalysis($terminal);
					# delete [^DB] after last suffix
					$analysis =~ s/(\[\^DB\])?\[--\]$//;
					#print "last $i: $wordform\t$analysis\n\n";
					print "$wordform\t$analysis\n\n";
				}
			}
			else{
				$token =~ s/^-//;
				$wordform .= "$token";
				$analysis .= &getAnalysis($terminal);
				#print "sdss $wordform";
			}
		}
	}
	
	print "#EOS\t#EOS\t+?\n\n";	
}

sub getAnalysis{
	my $terminal = $_[0];
	my $token = @{$terminal->findnodes('word')}[0]->textContent;
	$token =~ s/^-(.+)/\1/;
	my $pos = @{$terminal->findnodes('pos')}[0]->textContent;
	my @pos = split('_',$pos);
	my @tags = $terminal->findnodes('child::morph/tag');
	my $analysis = '';
	#$analysis = $token;
	if($pos =~ 'Root')
	{
		# in roots:
		# start backwards, with the last suffix in DB, so we can match the suffix form in $token
		for(my $i = scalar(@pos)-1; $i>=1;$i--)
		{
			my $p = @pos[$i];
			my $morphtag = @tags[$i]->textContent;
			my $morphformregex = ($mode eq '-norm')? $mapTagsToSuffixFormsNormalized{$morphtag} : $mapTagsToSuffixFormsNotNormalized{$morphtag};
			# match at the end of the string
			#my ($morphform) = $token =~ m/(\Q$morphformregex\E)$/;
			my $morphform;
			
			($morphform) = lc($token) =~ m/($morphformregex)\E$/;
			if(!$morphform){
				print STDERR "root: could not find $morphformregex for $morphtag in $token\n";
				exit;
			}
			$token =~ s/$morphform$//i;
			
			if($i<scalar(@pos)-1){
				$analysis = $morphform."[".$p."][".@tags[$i]->textContent."][--]".$analysis;
			}
			# last suffix in terminal -> DB
			else{
				$analysis .= $morphform."[".$p."][".@tags[$i]->textContent."][^DB][--]" ;
			}
		}
		if(@{$terminal->findnodes('translation')}[0]){
			my $translation = @{$terminal->findnodes('translation')}[0]->textContent;
			$analysis = ($analysis ne '') ? $token."[".@tags[0]->textContent."][$translation][--]".$analysis : $token."[".@tags[0]->textContent."][$translation][^DB][--]" ;
		}
		else{
			$analysis = ($analysis ne '') ? $analysis = $token."[".@tags[0]->textContent."][--]".$analysis : $analysis = $token."[".@tags[0]->textContent."][^DB][--]";
			#$analysis = $token."[".@tags[0]->textContent."][--]".$analysis; 
		}
		
	}
	elsif($pos eq 'SP'){
		$analysis .= "[SP]";
	}
	else{
		for(my $i=0; $i<scalar(@pos);$i++)
		{
			my $p = @pos[$i];
			# if morpheme(s)
			if(@tags[$i])
			{
				my $morphtag = @tags[$i]->textContent;
				if($morphtag eq '+3.Sg.Subj.IPst' or $morphtag eq '+3.Sg.Subj.NPst' or $morphtag eq '+3.Pl.Subj.IPst' or $morphtag eq '+3.Pl.Subj.NPst'){
					$p = "Tns_VPers";
					$i++;
				}
				my $morphformregex = ($mode eq '-norm')? $mapTagsToSuffixFormsNormalized{$morphtag} : $mapTagsToSuffixFormsNotNormalized{$morphtag};
				my $morphform;
				($morphform) = lc($token) =~ m/^($morphformregex)\E/;
				
				if(!$morphform){
					print STDERR "could not find $morphformregex for $morphtag in $token, at $i, id: ".$terminal->getAttribute('id')."\n";
					exit;
				}
				$token =~ s/^$morphform//i;
				if($i<scalar(@pos)-1){
					$analysis .= $morphform."[".$p."][".$morphtag."][--]";
				}
				# last suffix in terminal -> DB
				else{
					$analysis .= $morphform."[".$p."][".$morphtag."][^DB][--]";
				}
			}
			# else: punctuation:
			# .		.[$.]
			else{
				$analysis = $token."[".$p."]";
			}
		}
	}
	return $analysis;
	
}

sub isNewWord{
	my $string = $_[0];
	#print STDERR "returning $string".($string !~ /^-.+/)."\n";
	return ($string !~ /^-.+/)
}

