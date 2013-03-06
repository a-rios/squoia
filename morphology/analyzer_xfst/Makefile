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

# Moegliche Text-Dateien als Input:

TEXTS:=  texts/acuerdo_nacional_2002_QUE.txt 

all:  tokenize.fst quechua-web.fst verticalize.fst 
db: quechua-web-db.fst


analysed.txt: all
	cat $(TEXTS) | tokenize-utf -utf8 tokenize.fst | lookup-utf -flags xcKv29TT quechua-web.fst  > $@

analysed-db.txt: db
	cat $(TEXTS) | tokenize-utf -utf8 tokenize.fst | lookup-utf -flags xcKv29TT quechua-web-db.fst  > $@

analysed-db-truecase.txt: db
	cat $(TEXTS) | tokenize-utf -utf8 tokenize.fst | lookup-utf -flags cKv29TT quechua-web-db.fst  > $@

vertical.tsv: analysed.txt
	 tokenize-utf -utf8 verticalize.fst < $< |  tail -n+2 | perl -F'\t' -lane '; print "$$F[0]\t$$F[1]"' | perl -F'\[' -lane '; print "$$F[0]\t$$F[1]"' > $@

failures.txt: all
	cat $(TEXTS) | tokenize-utf -utf8 tokenize.fst | lookup-utf -utf8 -flags cKv29TT quechua-web.fst | grep '+?' |gawk '{print $$1}' | sort -u  > $@

failures-db.txt: all db
	cat $(TEXTS) | tokenize-utf -utf8 tokenize.fst | lookup-utf -utf8 -flags cKv29TT quechua-web-db.fst | grep '+?' |gawk '{print $$1}' | sort -u  > $@

%.fst:%.xfst
	xfst-utf -utf8 -f $<
