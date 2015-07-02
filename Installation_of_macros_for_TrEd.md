In order to use the annotation mode for Quechua and/or parallel treebanks in the Tiger format (phrase structures) in TrEd, you have to install the macros in treebanks/tred\_macros.

  1. install TrEd from here:
> > http://ufal.mff.cuni.cz/tred/
  1. copy the content of tred\_macros in the squoia sources to the TrEd extensions directory:
```
$ cp -R your-squoia-repo/treebanks/tred_macro/* ~/.tred.d/extensions
```
  1. add these lines to the file ~/.tred.d/extensions/extensions.lst
```
squoia_parallel
quechua
```


> ## Description of parallel\_squoia macro ##
  * displays parallel trees annotated with Tiger phrase structures
  * n-n sentence alignments possible
  * two types of node alignments: 'fuzzy' vs. 'exact'

> files needed:
  * two files containing the monolingual treebanks
  * one alignment file
    * see example in parallel\_squoia/test\_align.pml
    * note: the author set in the header of the alignment file will automatically be added to every newly created or edited alignment
  * schema files of the individual treebanks
  * schema file for the alignment file
    * see parallel\_squoia/resources/alignment\_squoia\_schema.xml

> functions:
  * to create an alignment, drag a node and drop it above another node
  * to delete an alignment, drag one of the aligned nodes and drop it above the other node
  * to change the attributes of an alignment (author, date, quality),  drag one of the aligned nodes and drop it above the other node, pressing CTRL
  * to change the sentence alignment, press CRTL and l (L)


> ## Description of quechua macro ##
> > follows...