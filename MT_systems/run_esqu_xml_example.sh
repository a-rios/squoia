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
#export FREELING_PORT="8866"
export FREELING_PORT="8866"
export MATXIN_DIX=$ESQU_DIR/lexica/es-quz.bin
export MATXIN_CONFIG=$ESQU_DIR/es-qu.cfg

# path to desr parser & its model
#export DESR_DIR_OLD="/home/clsquoia/parser/desr-1.2.6"
export DESR_DIR="/home/clsquoia/parser/desr-1.3.2"
export DESR_CONFIG=$DESR_DIR/spanishv2.conf
export DESR_MODEL=$DESR_DIR/spanish_es4.MLP
#export DESR_MODEL=$DESR_DIR/spanish.MLP
# squoia desr binaries:
export DESR_BIN=$PROJECT_DIR/desrModules
export DESR_PARAMS="-m $DESR_MODEL -c $DESR_CONFIG"
# model1 = spanish_es4.MLP
export DESR_PORT=5678


# test if server already started listening
if ps ax | grep -v grep | grep squoia_analyzer > /dev/null
then
 echo "squoia_analyzer server already started"
else
 echo "squoia_analyzer server not yet started"
 squoia_analyzer -f $FREELING_CONFIG --outf=desrtag --server --port=$FREELING_PORT 2> logdesrtag &
 echo "squoia_analyzer started..."
#while ! ps ax | grep -v grep | grep squoia_analyzer > /dev/null
# do
  echo "please wait..."
  sleep 10
# done
 
 echo "squoia_analyzer now ready"
fi

# test if desr server already started listening
if ps ax | grep -v grep | grep desr_server > /dev/null
then
 echo "desr_server server already started"
else
 echo "desr_server server not yet started"
 desr_server -m $DESR_DIR/spanish_es4.MLP --port 5678 2> logdesr_es4 &
 desr_server -m $DESR_DIR/spanish.MLP --port 1234 2> logdesr_MLP &
 echo "desr_server started..."
#while ! ps ax | grep -v grep | grep squoia_analyzer > /dev/null
# do
  echo "please wait..."
  sleep 1
# done
 
 echo "desr_server now ready"
fi


export EVID=$1

if [ -n "$EVID" ] && [ "$EVID" = "-indirect" ] ; then
        echo  "evidentiality set to $1" >&2
else
    echo "evidential past: neutral form -rqa (default)" >&2

fi


#perl readConfig.pl $MATXIN_CONFIG;


# server-client mode, new desr parser client
$MATXIN_BIN/analyzer_client $FREELING_PORT | $DESR_BIN/desr_client $DESR_PORT |perl conll2xml/conll2xml.pl |perl esqu/disambRelClauses_desr.pl  | perl esqu/corefSubj_desr.pl  | perl esqu/disambVerbFormsRules.pl $EVID  | $MATXIN_BIN/matxin-xfer-lex $MATXIN_DIX  | perl esqu/disambVerbFormsML.pl | perl splitNodes.pl  | perl insertSemanticTags.pl  | perl semanticDisamb.pl | perl morphDisamb.pl | perl prepositionDisamb.pl  | perl  synTransferIntraChunk.pl | perl STinterchunk.pl | perl nodesToChunks.pl | perl childToSiblingChunk.pl  | perl recursiveNumberChunks.pl | perl interChunkOrder.pl | perl linearOrderChunk.pl | perl nodeOrderInChunk.pl  | xmllint --format - 



##### OLD VERSIONS #####

# not server mode (slow!):
#$MATXIN_BIN/tagFLdesr $FREELING_PARAM | $DESR_DIR/src/desr $DESR_PARAMS | perl conll2xml/conll2xml.pl | perl esqu/disambRelClauses_desr.pl | perl esqu/corefSubj_desr.pl

# server-client mode
#$MATXIN_BIN/analyzer_client $FREELING_PORT |$DESR_DIR/src/desr $DESR_PARAMS  | perl conll2xml/conll2xml.pl  | perl esqu/disambRelClauses_desr.pl  | perl esqu/corefSubj_desr.pl  | perl esqu/subordVerbform_desr.pl  | $MATXIN_BIN/matxin-xfer-lex $MATXIN_DIX  | perl splitNodes.pl | perl insertSemanticTags.pl  | perl semanticDisamb.pl | perl morphDisamb.pl | perl prepositionDisamb.pl | perl  synTransferIntraChunk.pl | perl STinterchunk.pl | perl nodesToChunks.pl  | perl recursiveNumberChunks.pl| perl interChunkOrder.pl | perl linearOrderChunk.pl | perl nodeOrderInChunk.pl  | xmllint --format - 
#| perl esqu/getSentencesForGeneration.pl | xmllint --format - 



#$MATXIN_BIN/analyzer_client $FREELING_PORT |$DESR_DIR/src/desr $DESR_PARAMS | perl conll2xml/conll2xml.pl  | perl esqu/disambRelClauses_desr.pl  | perl esqu/corefSubj_desr.pl  | perl esqu/subordVerbform_desr.pl | $MATXIN_BIN/matxin-xfer-lex $MATXIN_DIX  | perl splitNodes.pl | perl insertSemanticTags.pl | perl semanticDisamb.pl | perl morphDisamb.pl | perl prepositionDisamb.pl | perl synTransferIntraChunk.pl | perl STinterchunk.pl | perl recursiveNumberChunks.pl| perl interChunkOrder.pl | perl linearOrderChunk.pl | perl nodeOrderInChunk.pl | perl esqu/getSentencesForGeneration.pl


# start squoia_analyzer:
#squoia_analyzer -f /home/clsquoia/google_squoia/FreeLingModules/es_desr.cfg --outf=desrtag --server --port=8866 2> logdesrtag &

# 8867 neue original FreeLing probabilitats.dat
# 8866 unsere neue original FreeLing probabilitats.dat
# 8868 alte original FreeLing probabilitats.dat
