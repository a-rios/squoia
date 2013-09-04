##############################################################################################################
# Targets:                                                                                                   #
#                                                                                                            #
# make analysed.txt -> produces a list of all the tokens in the input text with their morphological analysis #            
# make failures.txt -> creates a list of all the tokens in the text the transducer failed to analyse         #
# make spellcheck.txt -> creates a list of all the words in the text that were not recognized with a list of #
#                        with a list of suggestions (default: 5 suggestions, you can change that by editing  #
#                        the part fmed -l NUMBER in the invocation of the target 'spellcheck.txt'            #
#                                                                                                            #
#    if the necessary binary files are not present, they will be compiled automatically                      #
#    IMPORTANT: - all texts files need to be in UTF-8! If your Quechua text is in another encoding, you have #
#                 convert it first, on Unix e.g. with iconv.                                                 #
#               - perl has to be installed on your system
#                                                                                                            #
##############################################################################################################


# insert path to the text you want to analyse (test.txt contains the preamble of the Human Rights Declaration in Cuzco Quechua)
TEXTS:=  test1.txt

analyse:  analyzeUnificado.bin
spellcheck: spellcheckUnificado.bin

analysed.txt: analyse
	cat $(TEXTS) | perl ../tokenize.pl | flookup analyzeUnificado.bin | tail -n+2  > $@


failures.txt: spellcheck
	cat $(TEXTS) | perl ../tokenize.pl | flookup spellcheck.bin | perl listwrongspellings.pl > $@


spellcheck.txt: spellcheck
	cat $(TEXTS) | perl ../tokenize.pl | flookup spellcheck.bin |  perl ../listwrongspellings.pl | fmed -l 5 spellcheckUnificado.bin | perl ../formatspellcheckoutput.pl > $@
	
clean: 
	rm *.att *.bin

%.bin:%.foma
	foma -f $<
