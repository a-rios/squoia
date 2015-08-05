#!/bin/bash

########################################################
## ADAPT THESE PATH DECLARATIONS TO YOUR INSTALLATION ##
########################################################

# path to the compiled xfst analyzers, either from the git repository, or the package squoiaMorph from https://github.com/ariosquoia/squoia/releases
export NORMALIZER_DIR=/mnt/storage/hex/projects/clsquoia/arios_squoia_git/morphology/normalizer

# Path to your maltparser installation (get MaltParser from http://www.maltparser.org/download.html)
export MALTPARSER_DIR=/mnt/storage/hex/projects/clsquoia/parser/maltparser-1.8
export TMP_DIR=tmp

## Models to disambiguate words
MORPH1_MODEL=models/morph1.model
MORPH2_MODEL=models/morph2.model
MORPH3_MODEL=models/morph3.model
MORPH4_MODEL=models/morph4.model

# MaltParser model
MALTPARSER_MODEL=quzMaltParserModel

# EVID=aya -> ayacuchano, system will assume that every ambiguous -n is a 3. person marker, NOT the evidential -m/-n/-mi
# EVID=cuz -> system will disambiguate all ambiguous -n and decide whether they are person or evidential markers (normalized to -m)
EVID="cuz"    

# PISPAS=PAS -> text has only -pas as additive suffix: all ocurrences of -pis will be analyzed as sequence of -pi (locative) and -s (evidential)
# PISPAS=PIS -> additive suffix ocurrs as -pis in text: system will disambiguate all ocurrences of -pis and decide whether they are a combination of -pi and -s or the additive suffix (normalized to -pas)
PISPAS="pas"

RAW_FILE=$1

filename_w_ext=$(basename "$RAW_FILE")
filename_no_ext="${filename_w_ext%.*}"

#echo "filename is $filename_no_ext"

cat $RAW_FILE | perl splitSentences.pl | perl $NORMALIZER_DIR/tokenize.pl | lookup -f lookup.script -flags cKv29TT > $TMP_DIR/test.xfst

cat $TMP_DIR/test.xfst | perl cleanGuessedRoots.pl -$EVID -$PISPAS > $TMP_DIR/test_clean.xfst
cat $TMP_DIR/test_clean.xfst | perl xfst2wapiti_pos.pl -test > $TMP_DIR/pos.test

wapiti label -m $MORPH1_MODEL $TMP_DIR/pos.test > $TMP_DIR/morph1.result

perl disambiguateRoots.pl $TMP_DIR/morph1.result $TMP_DIR/test_clean.xfst > $TMP_DIR/morph1.disamb

perl xfst2wapiti_morphTest.pl -1 $TMP_DIR/morph1.disamb > $TMP_DIR/morph2.test

wapiti label -m $MORPH2_MODEL $TMP_DIR/morph2.test > $TMP_DIR/morph2.result

perl xfst2wapiti_morphTest.pl -2 $TMP_DIR/morph2.result > $TMP_DIR/morph3.test

wapiti label -m $MORPH3_MODEL $TMP_DIR/morph3.test > $TMP_DIR/morph3.result

perl xfst2wapiti_morphTest.pl -3 $TMP_DIR/morph3.result > $TMP_DIR/morph4.test

wapiti label -m $MORPH4_MODEL $TMP_DIR/morph4.test > $TMP_DIR/morph4.result

perl xfst2wapiti_morphTest.pl -4 $TMP_DIR/morph4.result > $TMP_DIR/disamb.xfst


# convert xfst to conll
cat $TMP_DIR/disamb.xfst | perl xfst2conll.pl > $TMP_DIR/$filename_no_ext.conll


# parse conll
java -jar $MALTPARSER_DIR/maltparser-1.8.jar -c $MALTPARSER_MODEL -i $TMP_DIR/$filename_no_ext.conll -o $TMP_DIR/$filename_no_ext.parsed.conll -m parse

# convert conll to pml to view (and edit) trees in TrEd (see https://ufal.mff.cuni.cz/tred/)
perl quzconll2pml.pl -s quz_schema.xml -n $filename_no_ext -c $TMP_DIR/$filename_no_ext.parsed.conll -t quz_stylesheet > $TMP_DIR/$filename_no_ext.pml 


