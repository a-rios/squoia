#!/usr/bin/perl


use utf8;                  # Source code is UTF-8
#use open ':utf8';
use Storable; # to retrieve hash from disk
#binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
#use File::Spec::Functions qw(rel2abs);
#use File::Basename;
#my $path = dirname(rel2abs($0));
#require "$path/../util.pl";

#read xml from STDIN
my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

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
				my $lem = $v->findvalue('word/text()');
				my $sublem;
				my $form;
				my $linker;
			
				foreach my $child (@verbChildren)
				{ #print $child->toString()."\n---------------------------------------------\n";
					
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
					elsif($child->exists('child::children/terminal[label[text()="s.subj" or text()="s.subj_obj" or text()="s.subj_iobj"] ]') || $child->exists('word[text()="KAN"]') )
					{
						$form = "finite";
						$sublem = $child->findvalue('word/text()');
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
					elsif($child->exists('child::children/terminal/label[text()="ns"]') && $form eq '' && !&isHabitualPast($child) )
					{
						$sublem = $child->findvalue('word/text()');
						my $nominalizer = @{$child->findnodes('child::children/terminal[label[text()="ns"]]')}[0];
						my $nsmorph = $nominalizer->findvalue('child::word/text()');
						$form = $nsmorph;
					}
					#else{print "child: ".$child->findvalue('word/text()');}
					#print STDOUT lc("$lem\t$sublem\t$form\t$linker\n");
					print STDOUT "$lem\t$sublem\t$form\t$linker\n";
					$form = '';
					$linker = '';
				}
				
			}
	}	
print "\n";
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
