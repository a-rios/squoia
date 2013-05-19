#!/usr/bin/perl

# Utilities

use strict;


sub splitDate{
	my $dateform = $_[0];
	# Dates: [W] (not CARD nor NN because dates are automatically mapped to [W], the lemma written with digits and placeholders)
	# Format: [wd:dd/mm/yyyy:hh.min:(am|pm)]; wd=(L|M|X|J|V|S|D)
	# Examples:
	#	[??:??/11/1969:??.??:??] with lemma "noviembre_de_1969"
	#	[??:26/09/1992:03.00:pm] with lemma "las_tres_de_la_tarde_del_26_de_septiembre_de_1992"
	#	[s:xix] for "siglo_XIX"
	
	my %daterecord;
	if ($dateform =~ /\[s:([cdimvx]+)\]/ ) {
		$daterecord{"siglo"} = $1;
	}
	elsif ($dateform =~ /\[(L|M|X|J|V|S|D|\?\?):(\d{1,2}|\?\?)\/(\d{1,2}|\?\?)\/(\d{2,4}|\?\?):(\d\d|\?\?)\.(\d\d|\?\?):(am|pm|\?\?)\]/ ) {
		$daterecord{"semdia"} = $1 if ($1 ne "??");
		$daterecord{"dia"} = $2 if ($2 ne "??");
		$daterecord{"mes"} = $3 if ($3 ne "??");
		$daterecord{"anno"} = $4 if ($4 ne "??");
		$daterecord{"hora"} = $5 if ($5 ne "??");
		$daterecord{"min"} = $6 if ($6 ne "??");
		$daterecord{"ampm"} = $7 if ($7 ne "??");
	}
	return \%daterecord;
}

sub getMaxNodeRef{
	my $dom = $_[0];

	my $maxRef = 0;
	my @nodes = $dom->findnodes('descendant::NODE');
	foreach my $node (@nodes) {
		my $ref = $node->getAttribute('ref');
		if (int($ref) > $maxRef) {
			$maxRef = int($ref);
		}
	}
	return $maxRef;
}

sub getMaxChunkRef{
	my $dom = $_[0];

	my $maxRef = 0;
	my @chunks = $dom->findnodes('descendant::CHUNK');
	foreach my $chunk (@chunks) {
		my $ref = $chunk->getAttribute('ref');
		if (int($ref) > $maxRef) {
			$maxRef = int($ref);
		}
	}
	return $maxRef;
}

sub getParentChunk{
	my $node = $_[0];

	my $chunkparent = @{$node->findnodes('ancestor::CHUNK[1]')}[0];
	return $chunkparent;
}

sub getNodesOfSingleChunk{
	my $chunk = $_[0];

	my @intraChunkNodes = ();
	my @candidates = $chunk->getElementsByTagName('NODE');
	foreach my $node (@candidates) {
		my $chunkparent = &getParentChunk($node);
		if ($chunkparent->isSameNode($chunk)) {
			push(@intraChunkNodes,$node);
		}
	}
	return @intraChunkNodes;
}

sub compAttrValue{
	my $node = $_[0];
	my $attrName = $_[1];
	my $valueStr = $_[2];

	return 0 if not $node;
	return 0 if not $node->hasAttribute($attrName);
	my $attribute = $node->getAttribute($attrName);

	if ($valueStr =~ /^\/([^\/]+)\/$/) {
		my $value = $1;
		#print STDERR "regex comparing $attribute value with $value\n";
		#return ( $attribute =~ m/$value/ );
		if ($attribute =~ m/$value/ )
			{return 1;}
		else
			{return 0;}
	}
	else {
		#print STDERR "string comparing $attribute value with $valueStr\n";
		#return ($attribute eq $valueStr);
		if ($attribute eq $valueStr)
			{return 1;}
		else
			{return 0;}
		
	}
}

sub isRelClause{
	my $verbChunk = $_[0];
	# if this is a relative clause: attribute 'verform' is already set
#	print STDERR "relclause test: ".$verbChunk->toString;
#	print STDERR "\n isrelClause: ".$verbChunk->exists('child::NODE[starts-with(@verbform,"rel")]');
	return $verbChunk->exists('child::NODE[starts-with(@verbform,"rel")]');
}

sub getFiniteVerb{
	my $verbchunk = $_[0];
	# finite verb is the one with a person marking (1,2,3)
	my $verb = @{$verbchunk->findnodes('child::NODE[starts-with(@mi,"V") and (contains(@mi,"3") or contains(@mi,"2") or contains(@mi,"1")) ][1]')}[-1];
	my $verb2Cand = @{$verbchunk->findnodes('child::NODE/NODE[starts-with(@mi,"V") and (contains(@mi,"3") or contains(@mi,"2") or contains(@mi,"1")) ][1]')}[-1];
	my $verb3Cand = @{$verbchunk->findnodes('child::NODE/NODE/NODE[starts-with(@mi,"V") and (contains(@mi,"3") or contains(@mi,"2") or contains(@mi,"1")) ][1]')}[-1];
	if($verb)
	{
		return $verb;
	}
	elsif($verb2Cand)
	{
		return $verb2Cand;	
	}
	elsif($verb3Cand)
	{
		return $verb3Cand;	
	}
	else
	{
		print STDERR "finite verb not found in: \n ";
		print STDERR $verbchunk->toString();
		print STDERR "\n";
		return 0;
	}	
	
}

sub hasSubj{
	my $relClauseNode = $_[0];
	
	return ($relClauseNode->exists('CHUNK[@type="grup-verb" and @si="vsubord"]/CHUNK[@si="subj"]'));
}

sub splitConditionsIntoArray{
	my $conditionString = $_[0];
			
	#split conditions and operators
	my @conditionsWithEmptyfields = split( /(xpath\{[^\}]+\})/, $conditionString);	
	#my @conditionsWithEmptyfields = split( /(\!|&&|\|\||\)|\()/, $conditionString);	
				
	#remove empty fields resulted from split
	my @conditionsToSplit = grep {$_} @conditionsWithEmptyfields; 
	
	my @conditions=();
	for my $cond (@conditionsToSplit)
	{
		if($cond =~ /xpath/)
		{
			push(@conditions,$cond);
		}
		else
		{
			#remove whitespaces in string of conditions
			$cond =~ s/\s//g;
			my @notXPathConds = split( /(\!|&&|\|\||\)|\()/, $cond);
			push(@conditions,@notXPathConds);
		}
	}
	#print STDERR  @conditions[0];
	my @conditionsWithoutEmptyFields= grep {$_} @conditions;
	#print "conditions::: @conditionsWithoutEmptyFields\n";
	return @conditionsWithoutEmptyFields;
}


# retrieve all childs of a node of type NODE (not CHUNKS)
sub getAllChildNODES{	
	my $wordnode = $_[0];
		my @children = $wordnode->childNodes();

		my @NODES =();
		foreach my $child (@children) {
			if ($child->nodeName eq 'NODE')
			{
			push(@NODES, $child);				
			}
		}
				
	return @NODES;
	
}

sub mergeArrays{
	my $oldSequence = $_[0];
	my $newSequence = $_[1];
	
	my $newHeadPos = &getPos($newSequence,'head');
	my $oldHeadPos = &getPos($oldSequence,'head');

	
#	print STDERR "old sequence: @{$oldSequence}\n";
#	print STDERR "new sequence: @{$newSequence}\n";

		
	# work through new order on the left of the head, comparing 2 by 2 elements
	# arrange old sequence according to this, start with head
	# start rearranging the elements on the left side of the head in newSequence

	#get operator of head (+ or .), in special variable $1
	@{$newSequence}[$newHeadPos] =~ /(\+|\.)/;
	my $precedingOperator = $1;
	my $precedingElement = @{$oldSequence}[$oldHeadPos];
	
if($newHeadPos > 0)
{
	for (my $i=$newHeadPos-1;$i>=0;$i--)
		{
			my ( $emptyField, $operator,$variable) = split(/(\+|\.)/,@{$newSequence}[$i]);
			if ($emptyField)
			{
				#print STDERR "operator: $operator, emptyF: $emptyField, variable: $variable\n";
				$variable = $emptyField;

			}		 
			#print STDERR "operator: $operator, emptyF: $emptyField, variable: $variable, prec Op: $precedingOperator\n";
			if (&getPos($oldSequence,$variable)!= -1)
			{
				my $oldPosition = &getPos($oldSequence,$variable);
				#remove element from old sequence
				splice (@{$oldSequence},$oldPosition,1);
				#adjust head position
				#print STDERR "changed old sequence: @{$oldSequence}\n";
			
				# if previous operator is '+', insert this element into old sequence right before the previous element from new sequence
				if($precedingOperator eq '+')
				{
					my $precedingPosition = &getPos($oldSequence,$precedingElement);
					splice (@{$oldSequence},$precedingPosition,0,$variable);
					$precedingOperator = $operator;
					$precedingElement = $variable;
				}
				# if previous operator is '.', check if there's an unmatched element in old sequence in between
				# if so, check position before that and until finding the next matched element (variable does not start with 'y')
				elsif($precedingOperator eq '.')
				{
					
					my $precedingPosition = &getPos($oldSequence,$precedingElement);
				
					#print STDERR "prec pos: $precedingPosition, element match:";
					if($precedingPosition>0)
					{	
						$precedingPosition--;
						print STDERR @{$oldSequence}[$precedingPosition] =~ /y.*/;
						while(@{$oldSequence}[$precedingPosition] =~ /y.*/ && $precedingPosition >0)
						{
							$precedingPosition--;
						}
						#print STDERR ",prec pos after while: $precedingPosition\n";
					}
					splice (@{$oldSequence},$precedingPosition,0,$variable);
					#print STDERR "after insertion: @{$oldSequence}\n";
					$precedingOperator = $operator;
					$precedingElement = $variable;
				}
			}
				

		}
}

if($newHeadPos<scalar(@{$newSequence}))
{		
		# now do the same thing with the elements right of the head in newSequence
		
		# reset oldHeadPos to values of head in oldSequence (that's the starting point) 
		$oldHeadPos = &getPos($oldSequence, 'head');
		my $precedingElement = @{$oldSequence}[$oldHeadPos];
	
		for (my $i=$newHeadPos+1;$i<scalar(@{$newSequence});$i++)
		{
			my ( $emptyField, $operator,$variable) = split(/(\+|\.)/,@{$newSequence}[$i]);
			if ($emptyField)
			{
				#print STDERR "operator: $operator, emptyF: $emptyField, variable: $variable\n";
				$variable = $emptyField;

			}		 
			#print STDERR "operator: $operator, emptyF: $emptyField, variable: $variable, prec Op: $precedingOperator\n";
			if (&getPos($oldSequence,$variable)!= -1)
			{
				my $oldPosition = &getPos($oldSequence,$variable);
				#remove element from old sequence
				splice (@{$oldSequence},$oldPosition,1);
				
				#print STDERR "changed old sequence2: @{$oldSequence}\n";
			
				# if previous operator is '+', insert this element into old sequence right after the previous element from new sequence
				if($operator eq '+')
				{
					my $precedingPosition = &getPos($oldSequence,$precedingElement);
					splice (@{$oldSequence},$precedingPosition+1,0,$variable);
					#print STDERR "inserted old sequence2: @{$oldSequence}\n";
					$precedingElement = $variable;
				}
				# if previous operator is '.', check if there's an unmatched element in old sequence in between
				# if so, check position after that and until finding the next matched element (variable does not start with 'y')
				elsif($operator eq '.')
				{
					
					my $precedingPosition = &getPos($oldSequence,$precedingElement);
				
					#print STDERR "prec pos: $precedingPosition, element match:";
					if($precedingPosition<scalar(@{$oldSequence}))
					{	
						$precedingPosition++;
						print STDERR @{$oldSequence}[$precedingPosition] =~ /y.*/;
						while(@{$oldSequence}[$precedingPosition] =~ /y.*/ && $precedingPosition<scalar(@{$oldSequence}))
						{
							$precedingPosition++;
						}
						#print STDERR ",prec pos after while: $precedingPosition\n";
					}
					splice (@{$oldSequence},$precedingPosition,0,$variable);
					#print STDERR "after insertion: @{$oldSequence}\n";
					$precedingElement = $variable;
				}
			}
				

		}
}
		
	
	 #print STDERR "changed complete old sequence: @{$oldSequence}\n";	
	 return $oldSequence;
	
}

			#insert at new position in old sequence, test if there are elements that are not included in rule (variables y1-yn)
			# between this element and the next one, if so, consider operator
sub insertIntoArray{
	my $arrayref=$_[0];
	my $element = $_[1];
	my $index = $_[2];
	print STDERR "@{$arrayref}\n";
	
}


sub getPos{
	my $arrayref=$_[0];
	my $element = $_[1];
	my $index = 0;
	++$index until @{$arrayref}[$index]  =~ /(\.|\+)?$element/ or $index > scalar(@{$arrayref});
	if($index>scalar(@{$arrayref}))
	{
		#print STDERR "Error: variable not in array\n";
		return -1;
	}
	else{return $index;}
}

my %mapNodeHash =	(
	'my'		=> '.',
	'child'		=> 'child::NODE',
	'firstchild'=> 'child::NODE[1]',
	'parent'	=> '..',
	'lsibling'	=> 'preceding-sibling::NODE',
	'rsibling'	=> 'following-sibling::NODE',
	'chunkchild'	=> 'child::CHUNK',
	'chunkparent'	=> 'ancestor::CHUNK[1]'
		);

my %mapChunkHash =	(
	'my'		=> '.',
	'child'		=> 'child::CHUNK',
	'firstchild'=> 'child::CHUNK[1]',
	'firstchild'=> 'child::CHUNK[1]',
	'chunkgrandchild'=> 'descendant::CHUNK[2]',
	'descendant'=> 'descendant::CHUNK',
	'parent'	=> '..',
	'chunkparent'	=> 'ancestor::CHUNK[1]',
	'chunkgrandparent'	=> 'ancestor::CHUNK[2]',
	'lsibling'	=> 'preceding-sibling::CHUNK',
	'rsibling'	=> 'following-sibling::CHUNK'
		);

sub mapPath2XPath{
	my $pathStr = $_[0];
	my $mapref = $_[1];

#	my %maphash = %$mapref;
	my @path = split( /\./, $pathStr );
	
	my $xpath = ".";
	foreach my $step (@path) {
#		if ($maphash{$step}) {
#			$xpath = $xpath . "/" . $maphash{$step};
		if ($mapref->{$step}) {
			$xpath = $xpath . "/" . $mapref->{$step};
		}
		else {
			die "wrong step \"$step\" in node/chunk path \"$pathStr\"";
		}
	}
	return $xpath;
}

sub getRelatedChunks{
	my $srcChunk = $_[0];
	my $pathStr = $_[1];

	my $xpath = &mapPath2XPath($pathStr,\%mapChunkHash);
	print STDERR "xpath to related chunks: $xpath\n";
	my @candidates = $srcChunk->findnodes($xpath);
	print STDERR scalar(@candidates). " candidates\n";
	return @candidates;
}

sub getRelatedNodes{
	my $srcNode = $_[0];
	my $nodePathStr = $_[1];

	my $xpath = &mapPath2XPath($nodePathStr,\%mapNodeHash);
	print STDERR "$xpath\n";
	my @candidates = $srcNode->findnodes($xpath);
	print STDERR scalar(@candidates). " candidates\n";
	return @candidates;
}

sub getTargetNode{
	my $srcNode = $_[0];
	my $nodePath = $_[1];
	
	my $trgNode = $srcNode;
	my $pathStep;
	if ($pathStep = shift(@$nodePath)) {
		print STDERR "path step: $pathStep\n";
		# NODE is self
		if ( $pathStep eq 'my' ) {
			$trgNode = $srcNode;
		}
		# NODE is parent
		elsif ( $pathStep eq 'parent' ) { 
			$trgNode = $srcNode->parentNode;
		}
		# child of node is sibling of SYN (but NODE, not SYN) ?TODO?
	#	elsif ( $pathStep eq 'child' )    
	#	{ 
	#		my $boolean = 0;
	#		my @children = $wordnode->childNodes();
	#		foreach my $child (@children) {
	#			
	#			# if there is a NODE child, test if condition is met
	#			if (   $child->nodeName eq 'NODE'
	#				&& &compAttrValue($child->getAttribute($attribute), $value) )
	#			{ $boolean = 1; }
	#		}
	#		$cond = $boolean;
	#	}
		# left sibling NODE
		elsif ( $pathStep eq 'lsibling' ) {       
			$trgNode = $srcNode->previousNonBlankSibling();
		}
		 # get right sibling of node
		elsif ( $pathStep eq 'rsibling' ) {          
			$trgNode = $srcNode->nextNonBlankSibling();
		}
		# first chunk above NODE is chunkparent
		elsif ( $pathStep eq 'chunkparent' ) { 
			$trgNode = @{$srcNode->findnodes('ancestor::CHUNK[1]')}[0];
		}	
		else
		{
			die "Undefined node path: $pathStep";
		}
		$trgNode = &getTargetNode($trgNode,$nodePath);
	}
	return $trgNode;	
}

sub evalConditionsTest{
	my $conditions = $_[0];
	my @copyConditions = @{$conditions};
	my $srcNode = $_[1];
	my $trgNode = $_[2];
	
	foreach my $cond (@copyConditions) {
		print STDERR "condition: $cond ";
		my ( $nodePathAttr, $value ) = split( '=', $cond );
		my @nodePath = split( /\./, $nodePathAttr );
		my $nodeAttr = pop(@nodePath);
		print STDERR "node path: @nodePath\n";
		print STDERR "node attribute: $nodeAttr\n";
		# no condition given, treat as false ?TODO?
		if ( $nodeAttr eq '-' ) {
			$cond= 0; 
		}
		elsif( $nodeAttr eq '!' or $nodeAttr eq '&&' or $nodeAttr eq '||' or $nodeAttr eq '(' or $nodeAttr eq ')') {
			$cond = $nodeAttr;
		}
		else {
			$trgNode = &getTargetNode($srcNode, \@nodePath);
			$cond = &compAttrValue($trgNode->getAttribute($nodeAttr),$value);
		}		
	}
	my $resultCond = eval "@copyConditions";
	return $resultCond;
}

sub isAbsolutePath{
	my $path = $_[0];

	if ($path =~ /^\//) {
		return 1;
	}
	else {
		return 0;
	}
}

sub isCongruentHeadRelClause{
	my $headNode =$_[0];
	my $finiteVerb = $_[1];
	
	my $verbMI = $finiteVerb->getAttribute('mi');
	my $verbPerson = substr ($verbMI, 4, 1);
	my $verbNumber = substr ($verbMI, 5, 1);
	
	my $headMI = $headNode->getAttribute('mi');
	my $nounPerson;
	my $nounNumber;
	
	# if persprn, get person
	if($headMI =~ /^PP/)
	{
		$nounPerson = substr ($headMI, 2, 1);
	}
	else
	{
		$nounPerson = '3';
	}
	# if coordination (coordinated np or pp) -> set number to plural
	if($headNode->exists('child::NODE[@rel="coord"]') or $headNode->parentNode->exists('parent::CHUNK[@type="coor-n"]') or $headNode->parentNode->parentNode->exists('parent::CHUNK[@type="coor-sp"]') )
	{
		$nounNumber = 'P';
	}
	else
		{
			$nounNumber = substr ($headMI, 3, 1);
			# proper names have no number, assume singular
			if($nounNumber eq '0')
			{
				#if number unknown, leave as is
				$nounNumber = 'S';
			}
		}
	
#	my $verbform = $finiteVerb->getAttribute('form');
#	my $nounform = $headNode->getAttribute('form');
#	print STDERR "$nounform:$verbform  verbprs:$verbPerson, verbnmb:$verbNumber, nounPrs:$nounPerson, nounNumb:$nounNumber\n";
	
	if($nounPerson eq $verbPerson && $nounNumber eq $verbNumber)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

sub evalConditions{
	my $conditions = $_[0];
	my @copyConditions = @{$conditions};
	my $wordnode = $_[1];
	
				foreach my $cond (@copyConditions) {
				
					#print STDERR $wordnode->getAttribute('prep');
					#print STDERR "\ncond: $cond \n";
					my ( $nodeAttr, $value ) = split( '=', $cond );
					my ( $noderef, $attribute ) = split( /\./, $nodeAttr );

					# xpath is given
					if ( $noderef =~ /^xpath/) {
						my $boolean = 0;
						my ($xpath,$xpathStr) = split('xpath{', $cond);
						$xpathStr =~ s/\}//;
						#print STDERR "xpath string: $xpathStr\n";
						my @pathnodes = $wordnode->findnodes($xpathStr);
						#print STDERR "xpath $xpathStr has ".scalar(@pathnodes)." nodes\n";
						# absolute path is given, check if the start node is one of the resulting nodes
						if (&isAbsolutePath($xpathStr)) {
							#print STDERR "xpath $xpathStr is absolute\n";
							foreach my $pathnode (@pathnodes) {
								if ( $pathnode->isSameNode($wordnode)) {
									$boolean = 1;
									last;
								}
							}
							$cond = $boolean;
						}
						 # relative path, check if it leads to a node
						else {
							#print STDERR "xpath $xpathStr is relative\n";
							# this doesn't work, need to explicitely assign 0!!!! 
							# empty value can't be evaluated by eval!!!
							#$cond = (scalar(@pathnodes) > 0);
							if((scalar(@pathnodes) > 0)){$cond =1;}
							else{$cond=0;}
							
						}
					}
					# no condition given, treat as false and consider probability
					elsif ( $noderef eq '-' )
					{
						$cond= 0; 
					}
					elsif( $noderef eq '!' or $noderef eq '&&' or $noderef eq '||' or $noderef eq '(' or $noderef eq ')')
					{
						$cond = $noderef;
					}
					# NODE is self
					elsif ( $noderef eq 'my' )   
					{
						$cond = &compAttrValue($wordnode, $attribute, $value);
					}
					# NODE is parent
					elsif ( $noderef eq 'parent' ) 
					{ 
						my $parent = $wordnode->parentNode;
						$cond = &compAttrValue($parent, $attribute, $value);
					}
					# child of node is sibling of SYN (but NODE, not SYN)
					elsif ( $noderef eq 'child' )    
					{ 
						my $boolean = 0;
						my @children = $wordnode->childNodes();
						foreach my $child (@children) {
							
							# if there is a NODE child, test if condition is met
							if (   $child->nodeName eq 'NODE'
								&& &compAttrValue($child, $attribute, $value) )
							{ $boolean = 1; }
						}
						$cond = $boolean;
					}
					# left sibling NODE
					elsif ( $noderef eq 'lsibling' )
					{       
						my $lsibling = $wordnode->previousNonBlankSibling();
						$cond = &compAttrValue($lsibling, $attribute, $value);
					}
					 # get right sibling of node
					elsif ( $noderef eq 'rsibling' )
					{       
						my $rsibling = $wordnode->nextNonBlankSibling();
						$cond = &compAttrValue($rsibling, $attribute, $value);
					}
					# first chunk above NODE is chunkparent
					elsif ( $noderef eq 'chunkparent' ) 
					{ 
						my $chunkparent = @{$wordnode->findnodes('ancestor::CHUNK[1]')}[0];
						$cond = &compAttrValue($chunkparent, $attribute, $value);
					}
					# first chunk above chunkparent NODE is chunkgrandparent
					elsif ( $noderef eq 'chunkgrandparent' ) 
					{ 
						my $chunkparent = @{$wordnode->findnodes('ancestor::CHUNK[1]')}[0];
						if ($chunkparent) {
							my $chunkgrandparent = @{$chunkparent->findnodes('ancestor::CHUNK[1]')}[0];
							$cond = &compAttrValue($chunkgrandparent, $attribute, $value);
						}
						else {
							$cond = 0;
						}
					}
					# CHUNK child of chunk
					elsif ( $noderef eq 'chunkchild' )    
					{ 
						my $boolean = 0;
						my @children = $wordnode->childNodes();
						foreach my $child (@children) {
							
							# if there is a CHUNK child, test if condition is met
							if (   $child->nodeName eq 'CHUNK'
								&& &compAttrValue($child, $attribute, $value) )
							{ $boolean = 1; }
						}
						$cond = $boolean;
					}
					else
					{
						#print STDERR "Undefined node reference: $noderef\n";
					}
					
				}
				
				
		 				
 				my $resultCond = eval "@copyConditions";
 				#print STDERR "-@$conditions-";
 				#print STDERR "resultsConditions: @copyConditions::: $resultCond\n";
			return $resultCond;


}

sub getHeadNoun($;$){
	my ($relClause, $parentchunk) = @_;
	
	if(!defined($parentchunk))
	{
		$parentchunk = $relClause->parentNode();
	}	
#	print STDERR $parentchunk->getAttribute('type');
#	print STDERR "\n";
	my $headNoun;
	
	#if preceded by single noun
	if($parentchunk->exists('self::CHUNK[@type="sn"]'))
	{#print STDERR "1\n";
		# if head noun is a demonstrative pronoun (doesn't ocurr? TODO: check)
		# old: head noun = noun or prsprn -> atm, prsprn no chunk
		#$headNoun = @{$parentchunk->findnodes('descendant::NODE[starts-with(@mi,"N") or starts-with(@mi,"PP")][1]')}[-1];
		$headNoun = @{$parentchunk->findnodes('descendant::NODE[starts-with(@mi,"N") or starts-with(@mi,"PP")][1]')}[-1];
	}

	#assure that head noun is above rel-clause (in cases of wrong analysis)
	if($headNoun && &isAncestor($relClause,$headNoun))
		{
			undef($headNoun);
		}
	#if head noun is defined, return 
	if($headNoun)
	{
		return $headNoun;
	}
	else
	{   #get sentence id
		my $sentenceID = $relClause->findvalue('ancestor::SENTENCE/@ord');
		print STDERR "Wrong analysis in sentence nr. $sentenceID? head chunk is: ";
		print STDERR $parentchunk->toString();
		return -1;
	}
}

sub isAncestor{
	my $relClause = $_[0];
	my $headNoun = $_[1];
	
	my $headNounOrd = $headNoun->getAttribute('ord');
	my $xpath = 'descendant::NODE[@ord="'.$headNounOrd.'"]';
	

	return($relClause->exists($xpath));
}
	
	
sub getMainVerb{
	my $relClause = $_[0];
	
	# main verb is always the first child of verb chunk	
	my $verb = @{$relClause->findnodes('child::NODE[starts-with(@mi,"V")][1]')}[-1];
	if($verb)
	{
		return $verb;
	}
	else
	{
		#get sentence id
		my $sentenceID = $relClause->findvalue('ancestor::SENTENCE/@ord');
		print STDERR "main verb not found in sentence nr. $sentenceID: \n ";
		print STDERR $relClause->toString();
		print STDERR "\n";
	}
}

return 1;
