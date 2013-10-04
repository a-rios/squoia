######################################
# README conversions to and from PML #
######################################

# tiger2pml.sh
#==============#
# part of the tiger extension
# 	NOTE: does not work well with namespace (or we haven't found a way to deal with it!)
#	=> eliminate the corresponding attribute in the "corpus" element
#	cat FOCUS_SQUOIA_DE.xml | sed 's/xmlns:xsi=.*TigerXML.xsd"//' > focus_squoia_de.xml
# example call
~/.tred.d/extensions/tiger/bin/tiger2pml.sh --output-dir squoiapml focus_squoia_de.xml 
# => creates the file squoiapml/focus_squoia_de.pml

# treealigner2pml.pl
#====================#
# example call
./treealigner2pml.pl < FOCUS_alignments_squoia_de_es.xml > FOCUS_alignments_squoia_de_es.pml


# pml2treealigner.pl
#====================#
# example call:
./pml2treealigner.pl < FOCUS_alignments_squoia_de_es.pml > FOCUS_alignments_squoia_de_es_fromPML.xml

### TODO ###
# author? annotator in pml?
#
# empty alignments? e.g. FOCUS de:s154-es:empty... we can define a sentence alignment between a real sentence id on one side and a fake id on the other side
#    <LM>
#      <tree_a.rf>a#empty</tree_a.rf>
#      <tree_b.rf>b#s1408</tree_b.rf>
#    </LM>
#

# PRECONDITIONS:
# <sen-align> for every sentence pair that has node alignments... (script I wrote some time ago...?)
#

# same amount of node alignments!!!...
grep "<sen-align" FOCUS_alignments_squoia_de_es.xml | wc -l
498
grep "<align type" FOCUS_alignments_squoia_de_es.xml | wc -l
8064
grep "<node_alignments" FOCUS_alignments_squoia_de_es.pml | wc -l
498
grep "<LM>" FOCUS_alignments_squoia_de_es.pml | wc -l
8562
grep "<a.rf>" FOCUS_alignments_squoia_de_es.pml | wc -l
8064
grep "<b.rf>" FOCUS_alignments_squoia_de_es.pml | wc -l
8064
grep "<tree_b.rf>" FOCUS_alignments_squoia_de_es.pml | wc -l
498
grep "<tree_a.rf>" FOCUS_alignments_squoia_de_es.pml | wc -l
498

TREEALIGNER XML
===============
<?xml version="1.0" encoding="UTF-8"?>
<treealign subversion="3" version="2">
  <head>
    <alignment-metadata>
      <author>anne</author>
      <date>2012-09-28</date>
      <description>FOCUS_SQUOIA</description>
      <history>
</history>
      <license>None</license>
      <revision>12</revision>
      <size>8563</size>
      <uuid>e4b77b01-fbb6-48ea-8315-981d0abbecba</uuid>
    </alignment-metadata>
    <treebanks>
      <treebank id="de" language="de_DE" filename="FOCUS_SQUOIA_DE.xml"/>
      <treebank id="es" language="es_ES" filename="FOCUS_SQUOIA_ES.xml"/>
    </treebanks>
    <alignment-features>
      <alignment-feature color="#33e533" name="good">Exact alignment</alignment-feature>
      <alignment-feature color="#e53333" name="fuzzy">Fuzzy alignment</alignment-feature>
    </alignment-features>
    <consistency-checks>
</consistency-checks>
    <settings>
      <display-options>
        <top-treebank treebank-id=""/>
      </display-options>
      <auto-align active="True"/>
    </settings>
  </head>
  <alignments>
    <sen-align>
      <node treebank_id="de" node_id="s1_VROOT"/>
      <node treebank_id="es" node_id="s1_VROOT"/>
    </sen-align>
    <align type="good" last_change="2012-01-17" author="norahollenstein">
      <node treebank_id="de" node_id="s1_500"/>
      <node treebank_id="es" node_id="s1_503"/>
    </align>
  </alignments>
</treealign>

===> PML

<?xml version="1.0" encoding="UTF-8"?>
<tree_alignment xmlns="http://ufal.mff.cuni.cz/pdt/pml/">
  <head>
    <schema href="sample_align_schema.xml" />
    <references>
      <reffile id="a" name="document_a" href="AHK_SQUOIA_DE.pml" />
      <reffile id="b" name="document_b" href="AHK_SQUOIA_ES.pml" />
    </references>
  </head>
  <body>
    <LM>
      <tree_a.rf>a#s1422</tree_a.rf>
      <tree_b.rf>b#s1405</tree_b.rf>
      <node_alignments>
        <LM>
          <a.rf>a#s1422_501</a.rf>
          <b.rf>b#s1405_504</b.rf>
          <quality>exact</quality>
        </LM>
      </node_alignments>
    </LM>
  </body>
</tree_alignment>

