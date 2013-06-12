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

TEXTS:=  texts/acuerdo_nacional_2002_QUE.txt

normal:  quechua-web.fst 
db: quechua-web-db.fst
vertical: vertical.fst


analysed.txt: normal
	cat $(TEXTS) | perl tokenize.pl | lookup -flags xcKv29TT quechua-web.fst | tail -n+2  > $@

analysed-db.txt: db
	cat $(TEXTS) | perl tokenize.pl | lookup -flags xcKv29TT quechua-web-db.fst | tail -n+2  > $@

analysed-db-truecase.txt: db
	cat $(TEXTS) | perl tokenize.pl | lookup -flags cKv29TT quechua-web-db.fst | tail -n+2  > $@

vertical.tsv: analysed.txt, vertical
	 tokenize verticalize.fst < $< |  tail -n+2 | perl -F'\t' -lane '; print "$$F[0]\t$$F[1]"' | perl -F'\[' -lane '; print "$$F[0]\t$$F[1]"' > $@

failures.txt: normal
	cat $(TEXTS) | perl tokenize.pl | lookup -flags xcKv29TT quechua-web.fst | perl listwrongspellings.pl  > $@
	
failures-db.txt: db
	cat $(TEXTS) | perl tokenize.pl | lookup -flags xcKv29TT quechua-web-db.fst | perl listwrongspellings.pl  > $@

clean: 
	rm  *.fst

%.fst:%.xfst
	xfst -f $<

