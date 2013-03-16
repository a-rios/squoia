#!/bin/bash

export MATXIN_DIR="/opt/matxin/local"
export FREELINGSHARE=$MATXIN_DIR/share/freeling
export MATXIN_BIN=$MATXIN_DIR/bin

export FREELING_CONFIG=$FREELINGSHARE/config/es_desr.cfg
export FREELING_PARAM="-f $FREELING_CONFIG $*"


export DESR_DIR="/home/clsquoia/parser/desr-1.2.6"
export DESR_CONFIG=$DESR_DIR/spanishv2.conf
export DESR_MODEL=$DESR_DIR/spanish.MLP
#export DESR_MODEL=$DESR_DIR/spanish_es4.MLP
export DESR_PARAMS="-m $DESR_MODEL -c $DESR_CONFIG"


#$MATXIN_BIN/tagFLdesr $FREELING_PARAM | $DESR_DIR/src/desr $DESR_PARAMS 

$DESR_DIR/src/desr $DESR_PARAMS 