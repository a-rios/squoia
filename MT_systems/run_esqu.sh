#!/bin/bash

# adapt paths to your installation
export MATXIN_BIN="/opt/matxin/local/bin"
export PROJECT_DIR="/home/clsquoia/google_squoia"
export FREELINGSHARE=$PROJECT_DIR/FreeLingModules
export ESQU_DIR=$PROJECT_DIR/MT_systems/esqu
export GRAMMAR_DIR=$ESQU_DIR/grammar
export OUTPUT_DIR=$GRAMMAR_DIR/output

export FREELING_CONFIG=$FREELINGSHARE/es_desr.cfg
#export FREELING_CONFIG=$FREELINGSHARE/es_desrHMM.cfg
export FREELING_PARAM="-f $FREELING_CONFIG $*"
export FREELING_PORT="8866"
export MATXIN_DIX=$ESQU_DIR/lexica/es-quz.bin
export MATXIN_CONFIG=$GRAMMAR_DIR/es-qu.cfg

# path to desr parser & its model
export DESR_DIR="/home/clsquoia/parser/desr-1.2.6"
export DESR_CONFIG=$DESR_DIR/spanishv2.conf
export DESR_MODEL=$DESR_DIR/spanish_es4.MLP
#export DESR_MODEL=$DESR_DIR/spanish.MLP
export DESR_PARAMS="-m $DESR_MODEL -c $DESR_CONFIG"

perl readConfig.pl $MATXIN_CONFIG;

# not server mode (slow!):
#$MATXIN_BIN/tagFLdesr $FREELING_PARAM | $DESR_DIR/src/desr $DESR_PARAMS | perl conll2xml/conll2xml.pl | perl esqu/disambRelClauses_desr.pl | perl esqu/corefSubj_desr.pl

# server-client mode
$MATXIN_BIN/analyzer_client $FREELING_PORT |$DESR_DIR/src/desr $DESR_PARAMS  | perl conll2xml/conll2xml.pl  | perl esqu/disambRelClauses_desr.pl  | perl esqu/corefSubj_desr.pl  | perl esqu/subordVerbform_desr.pl | $MATXIN_BIN/matxin-xfer-lex $MATXIN_DIX  | perl splitNodes.pl | perl insertSemanticTags.pl  | perl semanticDisamb.pl | perl morphDisamb.pl | perl prepositionDisamb.pl | perl  synTransferIntraChunk.pl| perl STinterchunk.pl | perl nodesToChunks.pl  | perl recursiveNumberChunks.pl| perl interChunkOrder.pl | perl linearOrderChunk.pl | perl nodeOrderInChunk.pl  | xmllint --format - 
#| perl esqu/getSentencesForGeneration.pl | xmllint --format - 


#$MATXIN_BIN/analyzer_client $FREELING_PORT |$DESR_DIR/src/desr $DESR_PARAMS | perl conll2xml/conll2xml.pl  | perl esqu/disambRelClauses_desr.pl  | perl esqu/corefSubj_desr.pl  | perl esqu/subordVerbform_desr.pl | $MATXIN_BIN/matxin-xfer-lex $MATXIN_DIX  | perl splitNodes.pl | perl insertSemanticTags.pl | perl semanticDisamb.pl | perl morphDisamb.pl | perl prepositionDisamb.pl | perl synTransferIntraChunk.pl | perl STinterchunk.pl | perl recursiveNumberChunks.pl| perl interChunkOrder.pl | perl linearOrderChunk.pl | perl nodeOrderInChunk.pl | perl esqu/getSentencesForGeneration.pl


#perl alternativeSentences.pl 
#/opt/matxin/matxinFL3/squoia_analyzer -f /home/clsquoia/google_squoia/FreeLingModules/es_desr.cfg --outf=desrtag --server --port=8866 2>logdesrtag &