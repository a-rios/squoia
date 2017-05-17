#!/bin/bash

##########################################
# example script to process Spanish text #
# by Annette Rios                        #
##########################################

parsing_pipeline_dir=path-to-your-parsing_pipeline_spanish
mosesdecoder=path-to-mosesdecoder ## if you use moses scripts for preprocessing, get from https://github.com/moses-smt/mosesdecoder
data_dir=$parsing_pipeline_dir/test_data
corzu_dir=$parsing_pipeline_dir/corzu_es
scripts=$parsing_pipeline_dir/scripts
out_dir=$data_dir # replace with different output directory if needed

# sentence splitting with moses script in Spanish does NOT work well with titles
# if your data has lines with multiple sentences, but no single sentences over more than one lines
# -> insert empty lines before using splitter to make sure titles are not inserted into the next sentence, e.g. with sed 's/$/\n/g'

###################
#    Parsing      #
###################
for file in $data_dir/*.es
   do
     base_es=$(basename $file) 
     echo "working on $base_es"
      
     base_parsed=`echo "$base_es" | sed -e 's/.es$/.es.parsed/'`
     file_parsed=$out_dir/$base_parsed
     
     if ! [ -s ${file_parsed} ]
       then
       echo "parsing $base_es $out_dir/$base_es.senttok"
         cat $file | sed 's/$/\n/g'  | perl $mosesdecoder/scripts/ems/support/split-sentences.perl -l es | perl -p -e 's/<P>\n//' | $mosesdecoder/scripts/tokenizer/normalize-punctuation.perl es > $out_dir/$base_es.senttok
         perl -I $parsing_pipeline_dir $parsing_pipeline_dir/parse.pm -o parsed -f $out_dir/$base_es.senttok > $file_parsed
         cat $file_parsed | perl $scripts/conll2senttok.pl > $out_dir/$base_es.senttokfromconll ## if you need to do sentence alignment, best use sentence splitting from parse
         perl -pi -e 'chomp if eof' $out_dir/${base_es}.senttokfromconll
         
         ## add document boundaries to conll for corzu ##
         sed -i "1 i\#begin document $base_es" $file_parsed
         sed -i -e "\$a#end document $base_es" $file_parsed
      fi
   done

#########################################
#  co-reference resolution with CorZu   #
#########################################

for file_parsed in $out_dir/*.parsed
  do
   base_es=$(basename $file_parsed) 
   echo "working on $base_es"
    
   base_mables=`echo "$base_es" | sed -e 's/.es.parsed/.es.mables/'`
   base_coref=`echo "$base_es" | sed -e 's/.es.parsed/.es.coref.conll/'`
   base_names=`echo "$base_es" | sed -e 's/.es.parsed/.es.checked.names/'`
   
   file_coref=$out_dir/$base_coref  
   file_names=$out_dir/$base_names
   
   echo "file_coref is $file_coref"
    
    ### check named entities against list of names/ common nouns that refer to persons (lists in corzu_es/data)
    if [ ! -s $file_names ]; then
	echo "check names on $base_es"
	## check if names/person list have been read and stored as perl hashes already
 	if [  ! -s $corzu_dir/fem.names.pl.stored ] ||  [ ! -s $corzu_dir/last.names.pl.stored ] || [ ! -s $corzu_dir/male.names.pl.stored ] || [ ! -s $corzu_dir/person.list.string.pl.stored ]; then
	    echo "reading names and person lists"
	    perl $corzu_dir/check_names.pl --female-names $corzu_dir/data/all.fem.sorted --male-names $corzu_dir/data/all.male.sorted --person-list $corzu_dir/data/person.list --last-names $corzu_dir/data/lastnames.txt   
        fi
        perl $corzu_dir/check_names.pl -c $file_parsed > $file_names 
        ## uncomment if you want to track the changes to the proper name tags
        #perl $corzu_dir/check_names.pl -c $file_parsed --verbose > $file_names 2>> $out_dir/person.changes.log
    fi
    
    ### co-reference resolution
    if [ ! -s $file_coref ]; then
        echo "corzu coref on $base_es"
       (cd $corzu_dir && python extract_markables.py $file_names > $out_dir/$base_mables && python corzu_es.py $out_dir/$base_mables $file_names $file_coref)
      fi

   done





