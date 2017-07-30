

XFST_DIR=/home/clsquoia/google_squoia/morphology/analyzer_xfst
XFST_BIN=$XFST_DIR/quechua-web-db.fst
TOKENIZER=$XFST_DIR/tokenize.pl



perl $TOKENIZER | lookup -flags cKv29TT  $XFST_BIN 
