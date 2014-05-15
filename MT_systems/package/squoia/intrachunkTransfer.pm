#!/usr/bin/perl

# syntactic transfer between nodes within a chunk
# intramove file format:
# 1. Descendant node condition:
#	Defines which nodes to take information from.
# 2. Descendant node attribute:
#	Which source attribute to copy.
# 3. Ancestor chunk/node condition:
#	Restricts the chunk or node to which the information is moved.
# 4. Ancestor chunk/node attribute:
#	The attribute in which the information should be put.
# 5. Direction:
#	In which direction the information is propagated, i.e.
#	down or up the tree
# 6. Write mode:
#	Can be one of three, either:
#	no-overwrite (do not overwrite previous information),
#	overwrite (overwrite previous information),
#	concat (concatenate information to any previously existing).

# 1			2		3		4		5		6
# descendantCond	descendantAttr	ancestorCond	ancestorAttr	direction	writeMode
package squoia::intrachunkTransfer;
use strict;
use utf8;

sub main{
	my $dom = ${$_[0]};
	my %intraConditions = %{$_[1]};

	foreach my $chunk ( $dom->getElementsByTagName('CHUNK') ) {
	#	print STDERR "chunk ". $chunk->getAttribute('ref'). " of type " . $chunk->getAttribute('type')."\n";
		my @intranodes = squoia::util::getNodesOfSingleChunk($chunk);
		foreach my $node (@intranodes) {
			#print STDERR "  node ". $node->getAttribute('ref'). " ".$node->getAttribute('sform'). "\n";
			foreach my $condpair (keys %intraConditions) {
				my ($descCond,$ancCond) = split( /\t/, $condpair);
	#			print STDERR "$descCond ++ $ancCond\n";
				#check descendant node conditions
				my @nodeConditions = squoia::util::splitConditionsIntoArray($descCond);
	#			print STDERR "$descCond\n";
				my $result = squoia::util::evalConditions(\@nodeConditions,$node);
	#			print STDERR "result $result\n";
				if ($result) {
					#find ancestor within chunk
					#print STDERR "$descCond ++ $ancCond\n";
					my @ancConditions = squoia::util::splitConditionsIntoArray($ancCond);
					my $ancestor = $node;
					my $found = 0;
					while (not $ancestor->isSameNode($chunk)) {
						$ancestor = $ancestor->parentNode;
	#					print STDERR $ancestor->nodeName."\n";
	#					print STDERR $ancestor->getAttribute('type')."\n";
						$found = squoia::util::evalConditions(\@ancConditions,$ancestor);
						last if $found;
					}
					if ($found) {	
	#					print STDERR "\n\n\nfound ancestor ".$ancestor->getAttribute('ref')."\n";
	#					print STDERR $ancestor->nodeName."\n";
						my $configline = $intraConditions{$condpair};
						my ($descAttr,$ancAttr,$direction,$wmode) = split(/\t/,$configline);
						#print STDERR "attr from to: $descAttr, $ancAttr\n\n";
	#					print STDERR "direction $direction\n";
						if ($direction eq "up") {
							&propagateAttr($node,$descAttr,$ancestor,$ancAttr,$wmode);
						}
						elsif ($direction eq "down") {
							&propagateAttr($ancestor,$ancAttr,$node,$descAttr,$wmode);	# switch src and trg
						}
						else {
							die "wrong propagation direction \"$direction\"";
						}
					}
				}
			}
		}
	}
	
	# print new xml to stdout
	#my $docstring = $dom->toString;
	#print STDOUT $docstring;
}

sub propagateAttr{
	my $srcNode = $_[0];
	my $srcAttr = $_[1];
	my $trgNode = $_[2];
	my $trgAttr = $_[3];
	my $wmode = $_[4];

	my $srcVal = $srcAttr;
	if ($srcAttr !~ /\"/ and $srcAttr =~ /\./) {	# attributes within quotes are taken as values and can contain a dot
		my @nodePath = split(/\./,$srcAttr);
		$srcAttr = pop(@nodePath);
		$srcNode = squoia::util::getTargetNode($srcNode,\@nodePath);
	}

	$srcVal = $srcNode->getAttribute($srcAttr);
	if ($srcVal eq '') {
		$srcVal = $srcAttr;
	}
	unless ($srcVal eq '"'){
	$srcVal =~ s/["]//g;
	}
	if ($wmode eq "concat") {
		if ($trgNode->hasAttribute($trgAttr)) {
			my $newVal = $trgNode->getAttribute($trgAttr).",".$srcVal;
			$trgNode->setAttribute($trgAttr,$newVal);
			#print STDERR "ATTRIBUTE...............$newVal\n";
		}
		else {
			$trgNode->setAttribute($trgAttr,$srcVal);			
		}
	}
	elsif ($wmode eq "overwrite") {
#print STDERR "overwrite attribute $trgAttr with value $srcVal\n";
#print STDERR $srcNode->nodePath()." propagates to ".$trgNode->nodePath()."\n";
#print STDERR $srcNode->toString()."\n==>\n".$trgNode->toString()."\n\n";
		$trgNode->setAttribute($trgAttr,$srcVal);
	}
	elsif ($wmode eq "no-overwrite") {
		if ($trgNode->getAttribute($trgAttr)) {
			print STDERR "target node already has a value for the attribute ".$trgAttr."\n";
		}
		else {
			$trgNode->setAttribute($trgAttr,$srcVal);
		}
	}
	else {
		die "wrong write mode \"$wmode\"";
	}
}

1;