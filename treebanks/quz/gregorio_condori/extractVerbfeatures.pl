#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;

#read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

my %mapMorphsToFeatures = (
	'+Inf'		=> 'infinitive',
	'+Perf'		=> 'perfect',
	'+Obl'		=> 'obligative',
	'+Ag'		=> 'agentive',
	'+SS'		=> 'SS',
	'+DS'		=> 'DS'
);

my %mapMorphsToClasses = (
	'+Inf'		=> 1,
	'+Perf'			=> 2,
	'+Obl'		=> 3,
	'+Ag'			=> 4,
	'+SS'	=> 5,
	'+DS'		=> 6,
	'finite'		=> 7,
);

#print STDOUT "\n######################################################################################################\n";
#
#print STDOUT "##   head verb\t head translation\t subord verb\t subord translation\t form\t linker     ##\n";
#print STDOUT "######################################################################################################\n\n";

foreach my $nt ($dom->getElementsByTagName('nonterminal'))
{
	# TODO: NRoot+verbalizing, done
	my @verbs = $nt->findnodes('descendant::children/terminal[(pos[text()="DUMMY" or text()="Root_VS"] or morph/tag[text()="VRoot"]) and not(word[text()="hina" or text()="paqari" or text()="Hina" or text()="Paqari"]) ]');
	#print STDOUT "sentence: ".$nt->findvalue('ancestor::s/@id')."\n";

	foreach my $v (@verbs)
	{
			my @verbChildren = &getVerbalChildren($v);
			if(scalar(@verbChildren)>0)
			{
				my $lem;
				my $trans;
				my $sublem;
				my $subtrans;
				my $form;
				my $linker;
				if(&isHabitualPastKAN($v) )
				{
					$lem = $v->findvalue('child::children/terminal[label/text()="hab"]/word/text()');
					$trans = $v->findvalue('child::children/terminal[label/text()="hab"]/translation/text()');
				}
				# KAN but no habitual past
				elsif($v->exists('child::word[text()="KAN"]'))
				{
					$lem = "ka";
					$trans = "ser";
				}
				else
				{
					$lem = $v->findvalue('word/text()');
					$trans = $v->findvalue('translation/text()');
				}
				
				$trans =~ s/=//;
			
				foreach my $child (@verbChildren)
				{ #print "\n-----------------".$child->findvalue('word/text()')."::".$child->findvalue('order/text()')."-------------------\n";
					
					# if this is a  'hab' form, print lemma from 'hab', not copula
					# with hab -> habitual past, finite form, get lemma from 'hab' verb
					# DON'T print this: it's not a subordinated verb!
					if(&isHabitualPast($child) )
					{
						next;
#						$lem = $child->findvalue('child::word/text()');
#						$sublem = $lem;
#						$form = "finite";
					}
					elsif($child->exists('child::children/terminal[label[text()="s.subj" or text()="s.subj_obj" or text()="s.subj_iobj"] ]') || &isHabitualPastKAN($child) ||  $child->exists('child::word[text()="KAN" or text()="haku" or text()="Haku"]') )
					{
						$form = "finite";
						if($child->exists('child::word[text()="KAN"]'))
						{
							$sublem = "ka";
							$subtrans = "ser";
						}
						else
						{
							$sublem = $child->findvalue('word/text()');
							$subtrans = $child->findvalue('translation/text()');
							$subtrans =~ s/=//;
						}
						my $linkernode = @{$child->findnodes('child::children/terminal[label[text()="linker"]]')}[0];
						if($linkernode)
						{
							$linker = $linkernode->findvalue('child::word/text()');
							if($linker =~ /[Cc]hay/ && $linkernode->exists('children/terminal/label[text()="topic"]'))
							{
								$linker = $linker."qa";
							}
							# chaymi, chaysi -> ignore evidentiality, match everything to chaymi
							elsif($linker =~ /[Cc]hay/ && $linkernode->exists('discourse[text()="FOCUS"]'))
							{
								$linker = $linker."mi";
							}
						}
					}
					elsif($child->exists('child::children/terminal/label[text()="ns"]') && $form eq '' )
					{ 
						$sublem = $child->findvalue('word/text()');
						$subtrans = $child->findvalue('translation/text()');
						$subtrans =~ s/=//;
						my $nominalizer = @{$child->findnodes('child::children/terminal[label[text()="ns"]]')}[0];
						my $nsmorph = $nominalizer->findvalue('child::morph/tag[1]/text()');
						$form = $nsmorph;
					}
						$form = $mapMorphsToClasses{$form};
						
						# print all information
						#print STDOUT lc("$form 1:$lem 2:$trans 3:$sublem 4:$subtrans 5:$linker");
						# don't print subordinated lemma and translation
#						print STDOUT lc("$form 1:$lem 2:$trans 3:$linker");
						
#						if($linker ne '')
#						{
#							print :lc(" 5:$linker");
#						}
#						print "\n";
						# string with binary values:
						print "$form 1:";
						&printAsBinaryNumbers($lem);
						print " 2:";
						&printAsBinaryNumbers($trans);
						print " 3:";
						&printAsBinaryNumbers($sublem);
						print " 4:";
						&printAsBinaryNumbers($subtrans);
						print " 5:";
						&printAsBinaryNumbers($linker);
						
						print "\n";
						
						#print STDOUT "$form".lc("\t$lem\t$trans\t$sublem\t$subtrans\t$linker")."\n";
						
					
					$form = '';
					$linker = '';
				}
				
			}
	}	
#print "\n";
}


sub getVerbalChildren{
	my $verb = $_[0];
	my @directverbs = $verb->findnodes('child::children/terminal[ (pos[text()="DUMMY"] or morph/tag[text()="VRoot"]) and label[not(text()="co")  and not(text()="aux")] and word[not(text()="hina" or text()="paqari" or text()="Hina" or text()="Paqari")] ]');
	my @subVerbsWithCase =  $verb->findnodes('children/terminal/children/terminal[label[text()="s.arg.claus"]]');
	#print "subv".scalar(@subVerbsWithCase);
	 push(@directverbs,@subVerbsWithCase);
	return @directverbs;
	#return $verb->findnodes('child::children/terminal[ (pos[text()="DUMMY"] or morph/tag[text()="VRoot"]) and label[not(text()="co")  and not(text()="aux")] and word[not(text()="hina")] ]');
}

sub isHabitualPast{
	my $terminal = $_[0];
	return $terminal->exists('child::label[text()="hab"]');
}

sub isHabitualPastKAN{
	my $terminal = $_[0];
	#print "\n-----------------".$terminal->findvalue('word/text()')."::".$terminal->findvalue('order/text()')."-------------------\n";
	return $terminal->exists('child::children/terminal/label/text()="hab"') &&  $terminal->exists('child::word[text()="KAN" or text()="ka"]') ;
}

#sub mapMorphs{
#	my $morph = $_[0];
#	
#	return
#}


sub printAsBinaryNumbers{
	my $string = $_[0];

	if($string ne '')
	{
		my $strLength = length($string);
		#my @bytes = unpack("b128",$string);
		my @bytes = unpack("b64",$string);
		print "1@bytes";
		#my $pretty = join(" ", pack("b64",@bytes));
		#print $pretty;
	}
	else
	{
		print "0";
	}
}


