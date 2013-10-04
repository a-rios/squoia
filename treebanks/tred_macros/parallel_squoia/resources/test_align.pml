<?xml version="1.0" encoding="UTF-8"?>
<squoia_alignment xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
  <head>
    <schema href="sample_align_schema.xml" />
    <references>
      <reffile id="a" name="document_a" href="AHK_SQUOIA_DE.pml" />
      <reffile id="b" name="document_b" href="AHK_SQUOIA_ES.pml" />
    </references>
  </head>
  <meta>
    <name>AHK_SQUOIA</name>
    <author>bliblablu</author>
    <date>2012-09-21</date>
    <description>German-Spanish SQUOIA</description>
    <format>pml</format>
  </meta>
  <body>
    <LM>
      <tree_a.rf>a#s1422-s1423</tree_a.rf>
      <tree_b.rf>b#s1405-s1406</tree_b.rf>
      <node_alignments>
        <LM annotator="bliblablu">
          <a.rf>a#s1422_4</a.rf>
          <b.rf>b#s1405_505</b.rf>
          <quality>exact</quality>
        </LM>
        <LM annotator="bliblablu">
          <a.rf>a#s1424_1</a.rf>
          <b.rf>b#s1406_500</b.rf>
          <quality>exact</quality>
        </LM>
        <LM annotator="bliblablu">
          <a.rf>a#s1424_502</a.rf>
          <b.rf>b#s1405_505</b.rf>
          <quality>exact</quality>
        </LM>
        <LM annotator="bliblablu">
          <a.rf>a#s1422_3</a.rf>
          <b.rf>b#s1405_501</b.rf>
          <quality>exact</quality>
        </LM>
        <LM annotator="jj">
          <a.rf>a#s1422_1</a.rf>
          <b.rf>b#s1405_1</b.rf>
          <quality>exact</quality>
        </LM>
        <LM annotator="jaja">
          <a.rf>a#s1422_3</a.rf>
          <b.rf>b#s1405_4</b.rf>
          <quality>exact</quality>
        </LM>
        <LM annotator="bla">
          <a.rf>a#s1422_2</a.rf>
          <b.rf>b#s1405_2</b.rf>
          <quality>exact</quality>
        </LM>
        <LM annotator="bling">
          <a.rf>a#s1422_4</a.rf>
          <b.rf>b#s1405_3</b.rf>
          <quality>fuzzy</quality>
        </LM>
      </node_alignments>
    </LM>
      <LM>
      <tree_a.rf>a#s1422-s1423</tree_a.rf>
      <tree_b.rf>b#empty</tree_b.rf>
      <node_alignments>
      </node_alignments>
    </LM>
  </body>
</squoia_alignment>
<?tred-pattern node: #{black}${word}?>
<?tred-pattern node: #{darkblue}${cat}#{darkgreen}${pos}?>
<?tred-pattern node: &lt;? $${morph} ne '--' ? '${morph}' : '' ?&gt;?>
<?tred-pattern label:&lt;? 
  my $pd=-10+8*$Parallel_Squoia::chld_pos-&gt;{$this-&gt;parent};
  '#{-coords:n,p+20+'.$pd.'}#{-anchor:center}#{black}${label}'
?&gt;
?>
<?tred-pattern text: &lt;?
  $${#name} eq 'terminal' ? 
    "#{-tag:".(join(",",$this,grep {$_-&gt;{'#name'} eq 'nonterminal'} $this-&gt;ancestors))."}"
    .$${word}
  : () ?&gt;
?>
<?tred-pattern rootstyle: 
# note: only attributes of root of the first document can be edited here directl# y, attributes for the root of the second document have to be edited directly in parallel_squoia.mak
  #{balance:0}
  #{skipHiddenLevels:1}
  #{CurrentTextBox-fill:red}
  #{nodeXSkip:30}
  #{nodeYSkip:40}
  #{baseYPos:20}
  #{NodeLabel-skipempty:1}
  #{NodeLabel-halign:center}#{Node-textalign:center}
  #{CurrentOval-outline:red}
  #{CurrentOval-width:3}
  &lt;?
 #   my (%prev,%level);
 #   $Parallel_Squoia::achld_pos=\%prev;
 #   $Parallel_Squoia::amax_level=$level{$this}=0;
 #   $Parallel_Squoia::alevels=\%level;
 #   my $hidden = FileUserData('hide');
 #   for my $n ($this-&gt;descendants) {
 #     my $lvl = $level{$n}=$level{ $n-&gt;parent }+1;
 #     $prev{$n-&gt;{id}} = $prev{$n}=$prev{ $n-&gt;lbrother || "" } + 1;
 #     $Parallel_Squoia::amax_level = $lvl if !$hidden-&gt;{$n} &amp;&amp; $lvl&gt;$Parallel_Squoia::amax_level;
#    }
  ?&gt;
?>
<?tred-pattern style:
&lt;?
  if ( ! $this-&gt;parent ) {
     '#{Node-hide:1}'
  } else {
    my $styles='';
    my $is_nonterminal = $${#name} eq 'nonterminal' ? 1 : 0;
   my $smooth='0';
 #   print STDERR "is b: ".$this-&gt;{'b-node'}."\n";

  if($this-&gt;{'b-node'}==1)
   {
 #  print STDERR "BBB node ".$this-&gt;{'id'}."\n";
#    print STDERR "bchld pos: ".$Parallel_Squoia::bchld_pos."\n";
# print STDERR "blevel: ".$Parallel_Squoia::blevels-&gt;{$this}."\n";
# print STDERR "bmaxlevel: ".$Parallel_Squoia::bmaxlevel."\n";
   my $pd=-10+8*$Parallel_Squoia::bchld_pos-&gt;{$this-&gt;parent};
   my $nd=0;
   if ($is_nonterminal) {
    $nd=-10+8*$Parallel_Squoia::bchld_pos-&gt;{$this};
  
    $styles .= "#{NodeLabel-yadj:$nd}";
   }
    my $coords = qq{n,n+$nd,n,p+$pd,p,p+$pd};
    if (length $${secedges/secedge/idref}) {
      my $td=-10+8*$Parallel_Squoia::bchld_pos-&gt;{ $${secedges/secedge/idref} };
      my $t='[? $node-&gt;{id} eq "'.$${secedges/secedge/idref}.'" ?]';
      my $xn=qq{xn};
      my $yn=qq{yn+$nd};
      my $xt=qq{x$t-10*sgn(x$t-$xn)};
      my $yt=qq{y$t+$td};
      my $X=qq{($xt-$xn)};
      my $Y=qq{($yt-$yn)};
      my $D=qq{sqrt($X**2+$Y**2)};
      my $d=qq{(25/$D+0.12)};
      $coords.=qq{&amp;$xn,$yn,($xt+$xn)/2 - $Y*$d,($yt+$yn)/2 + $X*$d,$xt,$yt};
      $styles .= '#{Line-arrow:&amp;last}#{Line-fill:&amp;orange}#{Line-width:&amp;1}';
    }
    $styles .= "#{Line-coords:$coords}#{Line-smooth:$smooth&amp;1}";

    if ($is_nonterminal and $this-&gt;parent-&gt;parent) {
      $styles .= "#{Node-rellevel:-0.50}";
    } elsif (!$is_nonterminal) {
      my $level = ($Parallel_Squoia::bmax_level - $Parallel_Squoia::blevels-&gt;{$this}) - 1;
      $level/=2;
      $styles.= "#{Node-level:$level}";
    }
   }
 else
 {  
   my $pd=-10+8*$Parallel_Squoia::achld_pos-&gt;{$this-&gt;parent};
   my $nd=0;
   if ($is_nonterminal) {
    $nd=-10+8*$Parallel_Squoia::achld_pos-&gt;{$this-&gt;parent};
  # print STDERR "node ".$this-&gt;{'id'}."\n";
  #  print STDERR "achld pos: ".$Parallel_Squoia::achld_pos."\n";
 #print STDERR "alevel: ".$Parallel_Squoia::alevels-&gt;{$this}."\n";
 #print STDERR "maxlevel: ".$Parallel_Squoia::amaxlevel."\n";
  
    $styles .= "#{NodeLabel-yadj:$nd}";
   }
    my $coords = qq{n,n+$nd,n,p+$pd,p,p+$pd};
    if (length $${secedges/secedge/idref}) {
    #  my $td=-10+8*$Parallel_Squoia::achld_pos-&gt;{ $${secedges/secedge/idref} };
      my $td=-10+8*$Parallel_Squoia::achld_pos-&gt;{ $${secedges/secedge/idref} };
      my $t='[? $node-&gt;{id} eq "'.$${secedges/secedge/idref}.'" ?]';
      my $xn=qq{xn};
      my $yn=qq{yn+$nd};
      my $xt=qq{x$t-10*sgn(x$t-$xn)};
      my $yt=qq{y$t+$td};
      my $X=qq{($xt-$xn)};
      my $Y=qq{($yt-$yn)};
      my $D=qq{sqrt($X**2+$Y**2)};
      my $d=qq{(25/$D+0.12)};
      $coords.=qq{&amp;$xn,$yn,($xt+$xn)/2 - $Y*$d,($yt+$yn)/2 + $X*$d,$xt,$yt};
      $styles .= '#{Line-arrow:&amp;last}#{Line-fill:&amp;orange}#{Line-width:&amp;1}';
    }
    $styles .= "#{Line-coords:$coords}#{Line-smooth:$smooth&amp;1}";

    if ($is_nonterminal and $this-&gt;parent-&gt;parent) {
      $styles .= "#{Node-rellevel:-0.50}";
    } elsif (!$is_nonterminal) {
      my $level = ($Parallel_Squoia::amax_level - $Parallel_Squoia::alevels-&gt;{$this}) - 1;
      $level/=2;
      $styles.= "#{Node-level:$level}";
    }
 # print STDERR "styles  : $styles\n";
 } #close else
    $styles .= 
    $is_nonterminal ? 
       "#{Node-shape:oval}#{Oval-fill:lightyellow}#{Node-surroundtext:1}#{NodeLabel-valign:center}" 
     :  "#{NodeLabel-yadj:-20}#{Line-dash:.}#{Oval-fill:yellow}";
     $styles;
}
?&gt;
?>
<?tred-pattern style: &lt;? "#{Node-hide:1}" if FileUserData('hide')-&gt;{$this}; ?&gt;?>
<?tred-pattern style:&lt;? "#{Oval-fill:lightgray}" if ($this-&gt;{'#name'} eq 'nonterminal' and FileUserData('fold')-&gt;{$this}) ?&gt;
?>
