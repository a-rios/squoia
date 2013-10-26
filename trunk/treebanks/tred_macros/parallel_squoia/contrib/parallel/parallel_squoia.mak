# -*- cperl -*-

package Parallel_Squoia;

=head1 Parallel_Squoia

=head2 DESCRIPTION

This annotation context provides simple functionality for visualizing
node-to-node alignments of trees in TrEd.

Instead of the alignment document, the aligned trees are rendered side
by side and the alignment links are visualized as arrows.

To create or remove an alignment link, simply drag node from one tree
to a node in the other tree.

=cut

#insert Parallel_Squoia Parallel Squoia
#binding-context Parallel_Squoia
sub NoOp {}

use strict;

BEGIN { import TredMacro; }

#include <contrib/support/arrows.inc>
use warnings;


## detect files with the expected PML schema
sub detect {
  return (((PML::SchemaName()||'') eq 'squoia_alignment') ? 1 : 0);
}
push @TredMacro::AUTO_CONTEXT_GUESSING, sub {
  my $current = CurrentContext();
  return __PACKAGE__ if detect();
  return;
};
sub allow_switch_context_hook {
  return 'stop' unless detect();
}

#bind toggle_layout to l menu Toggle Layout (side by side / one below the other)
our $trees_side_by_side = 0;
sub toggle_layout {
  $trees_side_by_side=!$trees_side_by_side;
}

#bind toggle_arrow_style to s menu Toggle Alignment Arrow Style (straight / curved)
our $straight_arrows = 1;
sub toggle_arrow_style {
  $straight_arrows = !$straight_arrows;
}

## get document_a or document_b
sub get_subdocument {
  my ($fsfile,$which)=@_;
  return undef unless ref($fsfile->metaData('refnames')) and ref($fsfile->appData('ref'));
  my $refid = $fsfile->metaData('refnames')->{$which};
  return defined($refid) && $fsfile->appData('ref')->{$refid};
}

sub get_document_a {
  return get_subdocument($_[0]||CurrentFile(),'document_a');
}

sub get_document_b {
  return get_subdocument($_[0]||CurrentFile(),'document_b');
}

our %b_node;
our @b_roots;
our @a_roots;


## give TrEd a list of nodes to display (nodes from document_a followed by nodes from document_b)
sub get_nodelist_hook {
  my ($fsfile,$tree_no,$current,$show_hidden)=@_;
  my $root = $fsfile->tree($tree_no);

  my $arfstr = $root->{'tree_a.rf'} || return; 
  $arfstr =~ s/^a#//;
  my (@arfs)= split('-', $arfstr); 
 # print STDERR "em $empty, @arfs\n";
  
  my $brfstr = $root->{'tree_b.rf'} || return; 
  $brfstr =~ s/^.*b#//;
  my (@brfs)= split('-', $brfstr); 
 #  print STDERR "em $empty, @brfs\n";
  
  my @aroots;
  foreach my $r (@arfs){
     unless ($r eq 'empty'){
	my $aroot = PML::GetNodeByID( $r, get_document_a($fsfile));
	if($aroot){
	    push( @aroots, $aroot);
	    }
	else{
	  die "No root $r found in ".get_document_a($fsfile)->filename."\n";
	  }
      }
   }
  my @broots;
  foreach my $r (@brfs){
    unless ($r eq 'empty'){
	my $broot = PML::GetNodeByID( $r, get_document_b($fsfile));
	if($broot){
	  push( @broots, $broot);
	}
	else{
	  die "No root $r found in ".get_document_b($fsfile)->filename."\n";
	}
      }
   }
  
  # need to access the roots in other functions, but only fill in once
  @a_roots = @aroots;
  @b_roots = @broots;
  
  my @aterminals; 
  foreach my $a_root (@aroots){
	my @sorted_as =
	sort { $a->{order} <=> $b->{order} }
	grep { $_->{'#name'} eq 'terminal' } $a_root->descendants;
	push (@aterminals, @sorted_as);
    }
  my @bterminals;
  foreach my $b_root (@broots){
	my @sorted_bs =
	sort { $a->{order} <=> $b->{order} }
	grep { $_->{'#name'} eq 'terminal' } $b_root->descendants;
	push (@bterminals, @sorted_bs);
    }
   
  my %aorder; @aorder{@aterminals}=(0..$#aterminals);
  my %border; @border{@bterminals}=(0..$#bterminals);
  
  my @anonterminals;
  foreach my $a_root(@aroots){
       my @nt = grep { $_->{'#name'} eq 'nonterminal' } $a_root->descendants;
       push (@anonterminals, @nt);
  }
 
  my @bnonterminals; 
  foreach my $b_root(@broots){
       my @nt = grep { $_->{'#name'} eq 'nonterminal' } $b_root->descendants;
       push (@bnonterminals, @nt);
  }


   my %aspan;
   my $afile = get_document_a($fsfile);
   my @anodes_sorted;
   my $atree = $afile->tree($tree_no);

  foreach my $a_root (@aroots)
  { 
      #print STDERR "a root: ".$a_root->{'id'}."\n";
      for my $node ($atree, reverse $a_root->descendants) {
	  next unless $node->parent;
	  my $is_terminal = $node->{'#name'} eq 'terminal' ? 1 : 0;
	  if (! $is_terminal ) {
	    $aorder{$node} = ($aorder{$aspan{$node}[1]}+$aorder{$aspan{$node}[0]})/2;
	  }
	  if (! $node->lbrother) {
	    $aspan{$node->parent}[0] = $node; #$is_terminal ? $node : $span{$node}[0]
	  }
	  if (! $node->rbrother) {
	    $aspan{$node->parent}[1] = $node; #$is_terminal ? $node : $span{$node}[1]
	  }
	}
	my @nodes_sorted = sort { $aorder{$a} <=> $aorder{$b} } ($atree,($a_root, $a_root->descendants));
	push (@anodes_sorted, @nodes_sorted);
    }
  
   my %bspan;
   my $bfile = get_document_b($fsfile);
   my $btree = $bfile->tree($tree_no);
   my @bnodes_sorted;
   foreach my $b_root (@broots)
   { 
	#print STDERR "b root: ".$b_root->{'id'}."\n";
	for my $node ($btree, reverse $b_root->descendants) {
	    next unless $node->parent;
	    my $is_terminal = $node->{'#name'} eq 'terminal' ? 1 : 0;
	    if (! $is_terminal ) {
	      $border{$node} = ($border{$bspan{$node}[1]}+$border{$bspan{$node}[0]})/2;
	    }
	    if (! $node->lbrother) {
	      $bspan{$node->parent}[0] = $node; #$is_terminal ? $node : $span{$node}[0]
	    }
	    if (! $node->rbrother) {
	      $bspan{$node->parent}[1] = $node; #$is_terminal ? $node : $span{$node}[1]
	    }
	  }
	  my @nodes_sorted = sort { $border{$a} <=> $border{$b} } ($btree,($b_root, $b_root->descendants));
	  push (@bnodes_sorted, @nodes_sorted);
     }

   %b_node=();
   @b_node{@bnodes_sorted}=();
  #$anodes_sorted[0]->paste_after($bnodes_sorted[0], $anodes_sorted[1]);
  
  push @anodes_sorted, @bnodes_sorted;
  foreach my $n (@bnodes_sorted){
    #  print STDERR $n->{'xml:id'}."\n";
      $n->{'b-node'} = 1;
  }
  
#   foreach my $n (@anodes_sorted){
#      print STDERR "node: ".$n->{'id'}."\n";
#   
#   }
  # print STDERR "curr: ".$current."\n";
 return [ \@anodes_sorted, $current ];
}

sub file_save_hook{

  my $a_doc = get_document_a();
  $a_doc->writeFile();
  my $b_doc = get_document_b();
  $b_doc->writeFile();

}


## change sentence alignment with Control+l
sub event_hook{
  my ($TkXEvent,$Tkwin,@shortcut) = @_;
 # print STDERR  "shortcut1 used: ".@shortcut[1]."\n";
  if(@shortcut[1] eq 'CTRL+l'){
       EditAttribute($root);
  }
}

## let TrEd's stylesheet editor offer attributes of nodes in document_a and _b instead
## of the alignment document
sub get_node_attrs_hook {
  return [
    uniq(
      PML::Schema(get_document_a())->attributes,
      PML::Schema(get_document_b())->attributes,
    ) ];
}


# positioning, node style options, and alignment arrows
our %alignments;
our %qualities;
sub node_style_hook {
  my ($node,$styles) = @_;
  if (exists $b_node{$node}) {
    AddStyle($styles,'Node',
	     -shape => 'rectangle',
	     -segment=>'0/0',
	    );
  } else {
    AddStyle($styles,'Node',
	     $trees_side_by_side ? (-segment=>'0/1') : (-segment=>'1/0')
	    );
    my $targets = $alignments{$node->{'id'}};
    
    # sort fuzzy vs. exact alignments
    my @exactTargets;
    my @fuzzyTargets;
    my $id=$node->{'id'};
    
    foreach my $target (@$targets){
	my $key = $id.":".$target;
	if($qualities{$key} eq 'fuzzy'){
	    push(@fuzzyTargets, $target);
	}
	elsif($qualities{$key} eq 'exact'){
	    push(@exactTargets, $target);
	}
    }
    
   # foreach my $key (@fuzzyTargets){print STDERR "fuzzy $id - $key\n";}
   # foreach my $key (@exactTargets){print STDERR "exact $id - $key\n";}
    if (@fuzzyTargets or @exactTargets) {
      my $bfile = get_document_b();
      DrawArrows($node,$styles,
		 [ map {{
		   -target => PML::GetNodeByID($_,$bfile),
		     ($straight_arrows ? (
		       -smooth => 0,
		       -frac => "0.0",
		       -raise => "0.0",
		      ) : (
			-smooth => 1,
			-raise => -25,
			-frac => -0.12,
		       )),
		   -arrow => 'last',
		   -arrowshape => '12,20,6',
		   -fill => 'orange',
		   # other options: -tag -arrow -arrowshape -width -smooth -fill -dash
		 }} @fuzzyTargets],
		 {
		   # options common to all edges
		  }
		);
	      DrawArrows($node,$styles,
		 [ map {{
		   -target => PML::GetNodeByID($_,$bfile),
		     ($straight_arrows ? (
		       -smooth => 0,
		       -frac => "0.0",
		       -raise => "0.0",
		      ) : (
			-smooth => 1,
			-raise => -25,
			-frac => -0.12,
		       )),
		   -arrow => 'last',
		   -arrowshape => '12,20,6',
		   -fill => 'lightgreen',
		   # other options: -tag -arrow -arrowshape -width -smooth -fill -dash
		 }} @exactTargets],
		 {
		   # options common to all edges
		  }
		);
    }
  }
}

our %prev;
our %level;


sub root_style_hook {
  my ($node,$styles,$opts)=@_;
  %alignments=();
  %qualities =();
  for my $c ($root->children) {
    my $arf = $c->{'a.rf'};
    my $brf = $c->{'b.rf'};
    $arf=~s/^.*#//;
    $brf=~s/^.*#//;
    my $quality = $c->{'quality'};
    my $key = $arf.":".$brf;
    $qualities{$key} = $quality;
    push @{$alignments{$arf}},$brf;
  }
  
#   foreach my $key (keys %$styles){
#       print STDERR "key $key ".$$styles{$key}."\n";
#      }
#   print STDERR "b root ".$b_root->{'id'}."\n";
  
    # set positions for b nodes 
#     $Parallel_Squoia::bchld_pos=\%prev;
#     $Parallel_Squoia::bmax_level=$level{$b_root}=0;
#     $Parallel_Squoia::blevels=\%level;
#     my $hidden = FileUserData('hide');
#     my $lvl;
#     for my $n ($b_root->descendants) {
#       $lvl = $level{$n}=$level{ $n->parent }+1;
#       $prev{$n->{id}} = $prev{$n}=$prev{ $n->lbrother || "" } + 0.2;
#       $Parallel_Squoia::bmax_level = $lvl if !$hidden->{$n} && $lvl>$Parallel_Squoia::bmax_level;
#     }
    my $b_root1 = @b_roots[0];
    $Parallel_Squoia::bchld_pos=\%prev;
    $Parallel_Squoia::bmax_level=$level{$b_root1}=0;
    $Parallel_Squoia::blevels=\%level;
    my $hidden = FileUserData('hide');
    my $lvl;
    foreach my $b_root (@b_roots){
	for my $n ($b_root->descendants) {
	  $lvl = $level{$n}=$level{ $n->parent }+1;
	  $prev{$n->{id}} = $prev{$n}=$prev{ $n->lbrother || "" } + 0.2;
	  $Parallel_Squoia::bmax_level = $lvl if !$hidden->{$n} && $lvl>$Parallel_Squoia::bmax_level;
	}
    }
    
    # set positions for b nodes 
    my $a_root1 = @a_roots[0];
    $Parallel_Squoia::achld_pos=\%prev;
    $Parallel_Squoia::amax_level=$level{$a_root1}=0;
    $Parallel_Squoia::alevels=\%level;
    my $hidden = FileUserData('hide');
    my $lvl;
    foreach my $a_root (@a_roots){
	for my $n ($a_root->descendants) {
	  $lvl = $level{$n}=$level{ $n->parent }+1;
	  $prev{$n->{id}} = $prev{$n}=$prev{ $n->lbrother || "" } + 0.2;
	  $Parallel_Squoia::amax_level = $lvl if !$hidden->{$n} && $lvl>$Parallel_Squoia::amax_level;
	  }
    }
    
  DrawArrows_init();
}



sub after_redraw_hook {
  %alignments=();
  %qualities =();
  DrawArrows_cleanup();
}


# drag and drop creates/removes alignment arrows
sub node_release_hook {
  my ($node,$target,$mod)=@_;

  if(defined($mod) and $mod eq 'Control'){
      print STDERR "mod is $mod\n";
  }
  
   my $fsfile = $grp->{FSFile}; 
   my $pml_root = $fsfile->metaData('pml_root');
   my $meta = $pml_root->{'meta'};
   my $author = $meta->{'author'};

  # source node and target node must be from document_a and document_b respectively 
  # or vice versa
  if (exists($b_node{$node}) xor exists($b_node{$target})) {
    my @ab = exists($b_node{$target}) ? qw(a b) : qw(b a);
    my @ids = ($node->{'id'}, $target->{'id'});
    
    # try to find an existing alignment first
    for my $alignment ($root->children) {
      my @refs = map $alignment->{"$_.rf"}, @ab;
      s{^.*#}{} for (@refs);
      if ($refs[0] eq $ids[0] and $refs[1] eq $ids[1]) {
	# these two nodes are already aligned
	# if with key=Control: change quality
	if(defined($mod) and $mod eq 'Control'){
	    # set annotator
	    $alignment->{'author'}=$author;
	    EditAttribute($alignment);
	}
	# else: no key -> delete this alignment
	else{
	    DeleteLeafNode($alignment);
	}
	Redraw_FSFile_Tree();
	ChangingFile(1);
	return 'stop';
      }
    }
    # no alignment exists yet, creating a new one
    my $doc_name2doc_id = FileMetaData('refnames');
    my $alignment = Treex::PML::Factory->createNode({
      "$ab[0].rf" => $doc_name2doc_id->{"document_$ab[0]"}."#$ids[0]",
      "$ab[1].rf" => $doc_name2doc_id->{"document_$ab[1]"}."#$ids[1]",
      "quality" => "exact",
      "annotator" => $author,
    },1);
    PasteNode($alignment,$root);
    EditAttribute($alignment);
    Redraw_FSFile_Tree();
    ChangingFile(1);
    return 'stop';
  }
  return;
}

1;
