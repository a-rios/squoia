#!/usr/bin/perl

use utf8;                  # Source code is UTF-8
use open ':utf8';
use Storable; # to retrieve hash from disk
binmode STDIN, ':utf8';
#binmode STDOUT, ':utf8';
use strict;
use XML::LibXML;
 use Error qw(:try);

#read xml from STDIN
#my $parser = XML::LibXML->new({encoding => 'utf-8'});
my $dom    = XML::LibXML->load_xml( IO => *STDIN);

foreach my $sentence  ( $dom->getElementsByTagName('s'))
{
	# attach chay/kay/jaqay to following root, if no suffixes are in between, as 'det'
	my @determiners = $sentence->findnodes("descendant::terminal[morph/tag[text()='PrnDem']]");
	foreach my $det (@determiners)
	{
		my $nextSibling = @{$det->findnodes("following-sibling::*[1]")}[-1];
		if($nextSibling && $nextSibling->exists("morph/tag[contains(., 'NRoot')] or (morph/tag[contains(., 'VRoot')] and morph/tag[text()='NS']) or morph/tag[text()='NP']"))
		{
			
			&insertNode($nextSibling,$det);
			&setLabel($det,'det');
		}
	}

	
	# attach numerals as quant to following NRoot, if not preceded by another NRootNUM 
	#(in this case, it's a complex number, leave for manual annotation), set label to 'qnt'
	# huk gets no label, as it can be used to mark indefiniteness as well, in this case the label would be  'mod', not 'qnt'
	my @numbers = $sentence->findnodes("descendant::terminal[morph/tag[text()='NRootNUM']]");
	
	foreach my $num  (@numbers)
	{
			my $nextSibling = @{$num->findnodes("following-sibling::*[1]")}[-1];
			if($nextSibling && $nextSibling->exists("morph/tag[contains(., 'NRoot')] or (morph/tag[contains(., 'VRoot')] and morph/tag[text()='NS']) or morph/tag[text()='NP']"))
			{
				&insertNode($nextSibling,$num);
				
				if(!$num->exists("word[text()='huk' or text()='huq' or text()='Huk' or text()='Huq' ]"))
				{
					&setLabel($num,'qnt');
				}
			}
	}
	
	
	# attach topic suffix to its root as 'topic'
	my @topics = $sentence->findnodes("descendant::terminal[morph/tag[text()='+Top' or text()='+QTop']]");

	foreach my $top (@topics)
	{
		my $root = @{$top->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
		&insertNode($root,$top);
		&setLabel($top, 'topic');
		
		# if root is chay -> chayqa, insert label 'linker' into root
		if($root->exists("word[starts-with(.,'chay') or starts-with(.,'Chay')]") )
		{
			&setLabel($root,'linker');
		}
	}
	
	# negation -chu, if its root is a verbal root, attach -chu to its root as 'neg', else leave for manual annotation
	my @negations =  $sentence->findnodes("descendant::terminal[morph/tag[text()='+Intr_Neg']]");
	foreach my $neg (@negations)
	{
		my $vroot = @{$neg->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
		if($vroot->exists("pos[contains(.,'VS')] or morph/tag[text()='VRoot']"))
		{
			&insertNode($vroot,$neg);
			&setLabel($neg, 's.neg')
		}

	}
	
	# -pas: if its root is an interrogative pronoun -> attach it as 'mod'
	# else: attach to root, but leave label for manual annotation
	my @additives =  $sentence->findnodes("descendant::terminal[morph/tag[text()='+Add']]");
	foreach my $add (@additives)
	{
		my $root = @{$add->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
		&insertNode($root,$add);
		if($root->exists("morph/tag[text()='PrnInterr']"))
		{
			&setLabel($add, 'mod')
		}

	}
	
	# -ña: attach to its root, unless preceded by -lla, then attach to lla (-llaña -> special meaning)
	my @discontinuatives =  $sentence->findnodes("descendant::terminal[morph/tag[text()='+Disc']]");
	foreach my $disc (@discontinuatives)
	{
		my $prevSibling = @{$disc->findnodes("preceding-sibling::*[1]")}[-1];
			# check if preceded by -lla (+Lim)
			if($prevSibling->exists("morph/tag[text()='+Lim_Aff']"))
			{
				&insertNode($prevSibling, $disc);
				&setLabel($disc, 'mod');
			}
			else
			{	
				my $root = @{$disc->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
			
				&insertNode($root,$disc);
				&setLabel($disc, 'mod')
			}
	}
	
	# -lla, -ya and -raq: attach to root as 'mod'
	my @modifiers = $sentence->findnodes("descendant::terminal[morph/tag[text()='+Lim_Aff' or text()='+Emph' or text()='+Cont'] and pos[text()='Amb'] ]");
	foreach my $mod (@modifiers)
	{
		my $root = @{$mod->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
		&insertNode($root,$mod);
		&setLabel($mod, 'mod');
	}
	
	# -taq: attach to root, but leave label for manual annotation
	my @taqs = $sentence->findnodes("descendant::terminal[morph/tag[text()='+Con_Intr'] ]");
	foreach my $taq (@taqs)
	{
		my $root = @{$taq->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
		&insertNode($root,$taq);
	}
	
	# attach possessive suffixes: if preceded by a nominalizing suffix, attach to this as 's.poss.subj', if no NS, attach to root as 's.poss'
	my @possessives = $sentence->findnodes("descendant::terminal[pos[contains(., 'NPers')]]");
		
		foreach my $poss (@possessives)
		{
			my $prevSibling = @{$poss->findnodes("preceding-sibling::*[1]")}[-1];
			# check if preceded by NS
			if($prevSibling->exists("pos[contains(., 'NS')]"))
			{
				&insertNode($prevSibling, $poss);
				&setLabel($poss, 's.poss.subj');
			}
			# else attach to root
			else
			{
				my $nroot = @{$poss->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
				&insertNode($nroot,$poss);
				&setLabel($poss, 's.poss');
			}
		}
	
	# nominaliations: nominalizing suffixes depende on their root as 'ns'
	my @nominalizingSuffixes = $sentence->findnodes("descendant::terminal[pos[starts-with(.,'NS')]]");
		
		#find corresponding root and attach ns to the root
		foreach my $ns (@nominalizingSuffixes)
		{
			my $vroot = @{$ns->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];

			&insertNode($vroot,$ns);
			&setLabel($ns, 'ns');
			# if -pti/qti, -spa or -stin -> insert label 'sub' in root, except with hina (hinaspa) -> label is 'linker'
			if($ns->exists("morph/tag[contains(.,'SS') or text()='+DS']") && !$vroot->exists("word[contains(.,'hina') or contains(., 'Hina')]"))
			{
				&setLabel($vroot, 'sub');
			}
			elsif($ns->exists("morph/tag[contains(.,'SS') or text()='+DS']") && $vroot->exists("word[contains(.,'hina') or contains(., 'Hina')]"))
			{
				&setLabel($vroot, 'linker');
			}
		}
	
	# causative and reflexive: depend on their root as 'mod'
	my @causAndRflx = $sentence->findnodes("descendant::terminal[morph/tag[text()='+Caus' or text()='+Rflx_Int']]");
		#find corresponding root and attach ns to the root
		foreach my $causrflx (@causAndRflx)
		{
			my $vroot = @{$causrflx->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
			
			&insertNode($vroot,$causrflx);
			&setLabel($causrflx, 'mod');
			
		}
		
	# attach aspect suffix to root as 'mod', except if in IG with person suffix (e.g. -shani), in this case, the label is set according to person suffix(es)
	my @aspects = $sentence->findnodes("descendant::terminal[morph/tag[text()='+Prog'] and not(pos[contains(.,'VPers')])]");
		#find corresponding root and attach ns to the root
		foreach my $asp (@aspects)
		{
			my $vroot = @{$asp->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
			
			&insertNode($vroot , $asp);
			&setLabel($asp, 'mod');
			
		}
	
	# attach object and subject markers to their root (correct in almost all cases, 
	# except with 'object raising', but those are rare and need to be manually checked)
	# also, we annotate indirect objects have to be checked manually
	my @vpers = $sentence->findnodes("descendant::terminal[pos[contains(.,'VPers')]]");
	
	foreach my $personsuffix (@vpers)
	{
		my $vroot = @{$personsuffix->findnodes("preceding-sibling::terminal[pos[contains(.,'Root')]]")}[-1];
		&insertNode($vroot,$personsuffix);
		
		#object markers, exclude portmanteau forms
		if($personsuffix->exists("child::morph/tag[text()='+1.Obj' or text()='+2.Obj']"))
		{
			&setLabel($personsuffix, 's.obj');
		}
		# subject markers, exclude portmanteau forms
		elsif($personsuffix->exists("child::morph/tag[contains(.,'Subj') and not(contains(.,'Obj'))]"))
		{
			&setLabel($personsuffix, 's.subj');
		}
		# portmanteau forms
		else
		{
			&setLabel($personsuffix,'s.subj_obj')	
		}
		
	}
	
	
	
	#get all terminal nodes that are case suffixes and make them the head of their noun
	my @caseSuffixes = $sentence->findnodes("descendant::terminal[pos[text()='Cas'] or word[text()='-yuq'] or word[text()='-sapa'] ]");
	foreach my $cs (@caseSuffixes)
	{
		# get terminal node that contains root of this word
		#my $root = @{$cs->findnodes("preceding-sibling::terminal/pos[text()='Root']/..")}[-1];
		my $root = @{$cs->findnodes("preceding-sibling::terminal/pos[contains(., 'Root')]/..")}[-1];
		
		# check if preceding node is also a case suffix, if it is, leave for manual annotation
		my $prevSibling = my $prevSibling = @{$cs->findnodes("preceding-sibling::*[1]")}[-1];
		if(!$prevSibling->exists("pos[text()='Cas']"))
		{
			&insertNode($cs,$root);
		
			#set label for root (can be s.arg or s.arg.claus), distinction only with case suffixes, not with -yuq/-sapa		
			if($cs->exists("child::pos[text()='Cas']") and $root->exists("child::morph/tag[contains(.,'VRoot')]"))
			{
				&setLabel($root,'s.arg.claus')
			}
			else
			{
				&setLabel($root,'s.arg');
			}
			#$sentence->removeChild($root)
		}
		
		;
	}
	
	# postposition -manta pacha 
	my @pachas = $sentence->findnodes("descendant::terminal[word[text()='pacha'] and pos[text()='NRoot']]");

	foreach my $pacha (@pachas)
	{
		my $prevSibling = @{$pacha->findnodes("preceding-sibling::*[1]")}[-1];
		#print "$prevSibling\n";
			# check if preceded by -manta, and check if preceding sibling exists: pacha is not a suffix, thus might be the first word in the sentence
			if($prevSibling && $prevSibling->exists("morph/tag[text()='+Abl']"))
			{
				&insertNode($pacha, $prevSibling);
				&setLabel($prevSibling, 'p.arg');
				&setLabel($pacha, 'tmp');
			}
	}
	
	# hina as postposition (if preceded by NRoot or case suffix)
	my @hinas = $sentence->findnodes("descendant::terminal[word[text()='hina'] and morph/tag[text()='Part_Sim']]");
	
	foreach my $hina (@hinas)
	{
		my $prevSibling = @{$hina->findnodes("preceding-sibling::*[1]")}[-1];
		my $grandparent = $hina->parentNode->parentNode;
			# check if preceded by directly by NRoot or case suffix, and check if preceding sibling exists: hina is not a suffix, thus might be the first word in the sentence 
			if($prevSibling && $prevSibling->exists("pos[text()='Cas'] or morph/tag[contains(.,'NRoot')]") && !$prevSibling->exists("word[text()='Pero' or text()='pero']"))
			{
				&insertNode($hina,$prevSibling);
				&setLabel($prevSibling, 'p.arg');
				&setLabel($hina, 'comp');
			}
			
			# if directly preceded by -chu -> -chu hina 'it seems that, i believe that..' -> epistemic modifier 
			# annotate -chu --mod-- hina --epst-- verb (don't attach to verb, too error prone, leave for manual annotation)
			elsif($prevSibling && $prevSibling->exists("morph/tag[text()='+Intr_Neg']"))
			{
				&insertNode($hina, $prevSibling);
				&setLabel($prevSibling, 'mod');
				&setLabel($hina, 'epst');
			}
			
			# -chu might depend on preceding verb as 's.neg'
			elsif($prevSibling && $prevSibling->exists("morph/tag[contains(.,'VRoot') or contains(.,'VS')]") && $prevSibling->exists("children/terminal/morph/tag[text()='+Intr_Neg']"))
			{
				my $chu = @{$prevSibling->findnodes("children/terminal[morph/tag[text()='+Intr_Neg']]")}[-1];
				&insertNode($hina,$chu);
				&insertNode($prevSibling,$hina);
				&setLabel($chu, 'mod');
				&setLabel($hina, 'epst');
			}
			
			# hina might be s.arg to a case suffix, in this case, get previous sibling of parent
			elsif($grandparent->exists("pos[text()='Cas']") )
			{
				my $OriginalPrecedingSibling = @{$grandparent->findnodes("preceding-sibling::*[1]")}[-1];
				#check if preceded by noun or case suffix
				if($OriginalPrecedingSibling && $OriginalPrecedingSibling->exists("pos[text()='Cas'] or morph/tag[contains(.,'NRoot')]") && !$OriginalPrecedingSibling->exists("word[text()='Pero' or text()='pero']"))
				{
					&insertNode($hina,$OriginalPrecedingSibling);
					&setLabel($OriginalPrecedingSibling, 'p.arg');
					&setLabel($hina, 'comp');
				}
				# -chu hina-raq -> hina might be child of a case suffix here too
				elsif($OriginalPrecedingSibling && $OriginalPrecedingSibling->exists("morph/tag[text()='+Intr_Neg']"))
				{
					&insertNode($hina,$OriginalPrecedingSibling);
					&setLabel($OriginalPrecedingSibling, 'mod');
					&setLabel($hina, 'epst');
				}	
				
				# verb -chu -hina -ta, possible (?)
#				elsif($OriginalPrecedingSibling && $OriginalPrecedingSibling->exists("morph/tag[contains(.,'VRoot') or contains(.,'VS')]") && $OriginalPrecedingSibling->exists("children/terminal/morph/tag[text()='+Intr_Neg']"))
#				{
#					my $chu = @{$OriginalPrecedingSibling->findnodes("children/terminal[morph/tag[text()='+Intr_Neg']]")}[-1];
#					&insertNode($hina,$chu);
#					&insertNode($OriginalPrecedingSibling,$grandparent);
#					&setLabel($chu, 'mod');
#					&setLabel($grandparent, 'epst');
#				}
			}
		}
	
	# ukhu, k'uchu, pata, hawa
	my @postpositions = $sentence->findnodes("descendant::terminal[word[starts-with(., 'ukhu') or starts-with(.,'pata') or starts-with(.,'hawa')]]");
	
	foreach my $postpos (@postpositions)
	{
			my $prevSibling = @{$postpos->findnodes("preceding-sibling::*[1]")}[-1];
			my $grandparent = $postpos->parentNode->parentNode;
			# check if preceded by directly by NRoot: ukhu etc are not suffixes, thus might be the first word in the sentence 
			if($prevSibling && $prevSibling->exists("morph/tag[contains(.,'NRoot')]") && !$prevSibling->exists("word[text()='Pero' or text()='pero']"))
			{
				&insertNode($postpos,$prevSibling);
				&setLabel($prevSibling, 'p.arg');
			}
			# postposition might be s.arg to a case suffix, in this case, get previous sibling of parent
			elsif($grandparent->exists("pos[text()='Cas']") )
			{
				my $OrginalPrecedingSibling = @{$grandparent->findnodes("preceding-sibling::*[1]")}[-1];
				#print $OrginalPrecedingSibling;
				if($OrginalPrecedingSibling && $OrginalPrecedingSibling->exists("morph/tag[contains(.,'NRoot')]") && !$OrginalPrecedingSibling->exists("word[text()='Pero' or text()='pero']"))
				{
					&insertNode($postpos,$OrginalPrecedingSibling);
					&setLabel($OrginalPrecedingSibling, 'p.arg');
				}
			}			
	}
	
	#agentive forms
	# if -q form followed by finite form of copula -> attach -q verbform to copula as 'hab'
	my @agentives = $sentence->findnodes("descendant::terminal[morph/tag[text()='+Ag']]");

	foreach my $ag (@agentives)
	{
		my $vroot = $ag->parentNode->parentNode;
		my $followingSiblingOfParent = @{$vroot->findnodes("following-sibling::*[1]")}[-1];
		
		if($followingSiblingOfParent && $followingSiblingOfParent->exists("translation[text()='=ser'] and children/terminal[label[contains(.,'subj')]]"))
		{
			&insertNode($followingSiblingOfParent, $vroot);
			&setLabel($vroot, 'hab');
		}
	}
	
	# genitive forms: attach genitive suffix to following noun as 'poss', if this noun bears an 's.poss'
	my @genitives = $sentence->findnodes("descendant::terminal[morph/tag[text()='+Gen']]");
	
	foreach my $gen (@genitives)
	{
		my $followingSibling = @{$gen->findnodes("following-sibling::*[1]")}[-1];
		my $followingSiblingsChild = @{$followingSibling->findnodes("children/terminal[1]")}[-1];
				
		# check if folliwing word is a noun and bear a possessive suffix, if next word is a case suffix, check if the condition applies to its child (the noun)
		if($followingSibling && $followingSibling->exists("(morph/tag[contains(.,'NRoot')] or children/terminal/pos[text()='NS']) and children/terminal/label[text()='s.poss']"))
		{
			&insertNode($followingSibling,$gen);
			&setLabel($gen,'poss');
		}
		elsif($followingSibling && $followingSiblingsChild && $followingSibling->exists("pos[text()='Cas']") && $followingSiblingsChild->exists("(morph/tag[contains(.,'NRoot')] or children/terminal/pos[text()='NS']) and children/terminal/label[text()='s.poss']"))
		{
			&insertNode($followingSiblingsChild,$gen);
			&setLabel($gen,'poss');
		}
		
		# same check, but if possessive suffix depends as 's.poss.subj', set label of possesive noun to 'poss.subj'
		elsif($followingSibling && $followingSibling->exists("(morph/tag[contains(.,'NRoot')] or children/terminal/pos[text()='NS']) and children/terminal/label[text()='s.poss.subj']"))
		{
			&insertNode($followingSibling,$gen);
			&setLabel($gen,'poss.subj');
		}
		elsif($followingSibling && $followingSiblingsChild && $followingSibling->exists("pos[text()='Cas']") && $followingSiblingsChild->exists("(morph/tag[contains(.,'NRoot')] or children/terminal/pos[text()='NS']) and children/terminal/children/terminal/label[text()='s.poss.subj']"))
		{
			&insertNode($followingSiblingsChild,$gen);
			&setLabel($gen,'poss.subj');
		}
		
	}
	
	# set label of evidential to 'ev'
	my @evidentials = $sentence->findnodes("descendant::terminal[morph/tag[contains(.,'+DirE') or contains(.,'+Asmp') or contains(., '+IndE') ]]");
	
	foreach my $ev (@evidentials)
	{
		&setLabel($ev,'ev');
	}
	
	# set label of Spanish conjunctions to 'linker' (y,o,u,pero..)
	my @spanishLinkers = $sentence->findnodes("descendant::terminal[word[text()='pero' or text()='Pero' or text()='y' or text()='o' or text()='u' or text()='entonces' or text()='Entonces' ]]");
	
	foreach my $spanishLinker (@spanishLinkers)
	{
		&setLabel($spanishLinker,'linker');
	}
	
	
	# annotate huq(k) kaq noun -> huq -- pred --kaq --mod --noun
	my @huqs = $sentence->findnodes("descendant::terminal[word[text()='huk' or text()='huq' or text()='Huk' or text()='Huq']]");
	
	foreach my $huq (@huqs)
	{
		my $nextSibling = @{$huq->findnodes("following-sibling::*[1]")}[-1];
		if($nextSibling && $nextSibling->exists("word[text()='ka'] and morph/tag[contains(.,'VRoot')]"))
		{
			my $nextSiblingsChild = @{$nextSibling->findnodes("children/terminal[1]")}[-1];
			if($nextSiblingsChild && $nextSiblingsChild->exists("morph/tag[text()='+Ag']"))
			{
				&insertNode($nextSibling, $huq);
				&setLabel($huq,'pred');
				
				# check if nextSibling of kaq is a noun, might also be a case suffix with a noun as child. 
				# attach huq kaq only to nominal roots, not nominalized verbs, as in this case, it might be a subject instead of a modifier
				my $followingSiblingOfNextSibling = @{$nextSibling->findnodes("following-sibling::*[1]")}[-1];
				if($followingSiblingOfNextSibling && $followingSiblingOfNextSibling->exists("morph/tag[contains(.,'NRoot')]"))
				{
					&insertNode($followingSiblingOfNextSibling, $nextSibling);
					&setLabel($nextSibling, 'mod');
				}
				elsif($followingSiblingOfNextSibling && $followingSiblingOfNextSibling->exists("pos[text()='Cas']"))
				{
					my $childOfCaseSuffix = @{$followingSiblingOfNextSibling->findnodes("children/terminal[1]")}[-1];
					if($childOfCaseSuffix && $childOfCaseSuffix->exists("morph/tag[contains(.,'NRoot')]"))
					{
						&insertNode($childOfCaseSuffix,$nextSibling);
						&setLabel($nextSibling,'mod');
					}
				}
			}
		}
	}
	
#	print $sentence->getAttribute('id');
#	print "\n";
}

my $corpus= @{$dom->getElementsByTagName('corpus')}[0];
$corpus->setAttribute('xmlns','http://ufal.mff.cuni.cz/pdt/pml/');

# print new xml to stdout
my $docstring = $dom->toString;
$docstring=~ s/\n\s+\n/\n/g;

print STDOUT $docstring;

#insert a node as child, check if node has already children
sub insertNode{
	my $parent = $_[0];
	my $child = $_[1];

if($parent->exists('children'))
		{
			my $children = @{$parent->find('children')}[0];
			$children->appendChild($child);
		}
else
		{
			my $children = $dom->createElement('children');
			$parent->appendChild($children);
			$children->appendChild($child);
		}
	
}

sub setLabel{
	my $node = $_[0];
	my $labeltext = $_[1];
	my $label= @{$node->getChildrenByLocalName('label')}[0];
	$label->removeChildNodes();
	$label->appendText($labeltext);
}