############################################################
# targets:                                                 #
#							   #
# make analysed.txt ->  analysis with standard xfst output #
# make analysed.tsv ->  analysis with verticalized output  #
#			(1 morpheme per line)              #
# make failures.txt ->  produces a list of all words that  #
#			could not be analysed              #
# -db- targets: 	same as above, but inserts an      #
#			additional boundary marker [^DB]   #
#			to lump morphemes into groups      #
############################################################

# indicate path to text file to analyse:

TEXTS:=  texts/bible_bolivian.txt

normal:  normalizer.fst 


normalized.txt: normal
	cat $(TEXTS) | perl tokenize.pl | lookup -flags xcKv29TT normalizer.fst | tail -n+2  > $@

failures.txt: normal
	cat $(TEXTS) | perl tokenize.pl | lookup -flags xcKv29TT quechua-web.fst | perl listwrongspellings.pl  > $@

clean: 
	rm  *.fst

%.fst:%.xfst
	xfst -f $<

