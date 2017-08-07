// compile with:
// g++ -o outputSentences outputSentences.cpp -I/path-to-kenlm -DKENLM_MAX_ORDER=6 -L/path-to-kenlm/lib/ -lkenlm
// g++ -o outputSentences outputSentences.cpp -I/home/clsquoia/kenlm-master/ -DKENLM_MAX_ORDER=6 -L/home/clsquoia/kenlm-master/lib/ -lkenlm -lboost_regex
// en hex: g++ -o outputSentences outputSentences.cpp -I/mnt/storage/hex/projects/clsquoia/kenlm-master/ -I/opt/matxin/local/include -DKENLM_MAX_ORDER=6 -L/mnt/storage/hex/projects/clsquoia/kenlm-master/lib/ -lkenlm -lboost_regex /opt/matxin/local/lib/libfoma.a -lz

#include <iostream>
#include <fstream>
#include <map>
#include "lm/model.hh"
#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/regex.hpp>
#include <stdlib.h>

#include <limits.h>
typedef bool _Bool;
#include "fomalib.h"



int sentOpts =0;
bool morphProbs=0;
//std::map< int, std::vector<std::wstring> > sentLattice;
std::map< int, std::vector<std::string> > sentLattice;
//lm::ngram::Model model("test.binary");
std::string usagestring = "Usage: outputSentences -m model (-n n-best, default n=3) -i input file (-l) -f foma transducer (-t) print morphemes for testing -h help";
std::string helpstring=	"Reads output data from MT system on stdin or from file and prints out n-best sentences\n"
		"-h\t\tprint help\n"
		"-m\t\tkenlm language model (binary!)\n"
		"-i\t\tinput file with generated word forms (optional, if no file given, reads data from stdin)\n"
		"-n\t\tprint n-best (optional, default is 3)\n"
		"-l\t\tuse lemma and morphemes to calculate sentence probability instead of whole words\n"
		"-f\t\tfoma transducer for generation\n"
		"-t\t\tprint output in lemma/tag sequences (for testing only)\n"
		;
static int  CUTOFF = 3;

void printMatrix(std::map< int, std::map< int, std::string > >sentMatrix);
void printLattice(std::map< int, std::vector<std::string> > &sentLattice, int nbrOfAltSents, const lm::ngram::Model &model);
bool probCompare(const std::pair<float, int>& firstElem, const std::pair<float, int>& secondElem);
void printTest(std::vector<std::pair<float,int> > sortedOpts);
void printSents(std::map< int, std::map< int, std::string > >sentMatrix, std::vector<std::pair<float,int> > sortedOpts);
void printSentsMorphGen(std::map< int, std::map< int, std::string > >sentMatrix, std::vector<std::pair<float,int> > sortedOpts);
void printTestMorphs(std::map< int, std::map< int, std::string > >sentMatrix, std::vector<std::pair<float,int> > sortedOpts);
void getProbs(std::map< int, std::map< int, std::string > >& sentMatrix, const lm::ngram::Model &model);
void getProbsMorphs(std::map< int, std::map< int, std::string > >& sentMatrix, const lm::ngram::Model &model);
void insertTransOpts(std::map< int, std::map< int, std::string > >&sentMatrix,int first,int last,std::vector< int > indexesOfAmbigWords);
static struct apply_handle *ah;
const char *modelfile = NULL;
bool print_test_morph=0;

int main(int argc, char *argv[]) {
	//	std::setlocale(LC_ALL, "en_US.utf8");
		int opt = 1;
		bool sentence_context =1;
		std::string infile ="";
		std::ifstream inputFile;
		std::istream* pCin = &std::cin;
		char *fstfilename;
		static struct fsm *analyzernet;

		//static char *(*applyer)() = &apply_up;


		while ((opt = getopt(argc, argv, "m:n:i:f:hlt")) != -1) {
		      switch(opt) {
		        case 'm':
		        	//std::cerr << optarg<< "\n";
		        	modelfile = optarg;
		        	break;
		        case 'i':
		        	//std::cerr << optarg<< "\n";
		        	infile = optarg;
		        	break;
		        case 'n':
		        	CUTOFF = atoi(optarg);
		        	break;
		        case 'l':
		       		morphProbs = 1;
		       		break;
		        case 't':
		       		print_test_morph = 1;
		       		morphProbs = 1;
		       		break;
		        case 'h':
		        	std::cerr << usagestring << '\n';
		        	std::cerr << helpstring << '\n';
		            exit(0);
		        case 'f':
		        	fstfilename = optarg;
		        	analyzernet = fsm_read_binary_file(fstfilename);
		        	if (analyzernet == NULL) {
		        		std::cerr << "print -h for help\n File error" << fstfilename << "\n";
		        			exit(EXIT_FAILURE);
		        	    }
		        	    ah = apply_init(analyzernet);
		        	break;
		        default:
		            std::cerr << usagestring << '\n';
		            std::cerr << helpstring << '\n';
		            exit(EXIT_FAILURE);
		    }
		}
		if (!modelfile){
			std::cerr << usagestring << '\n';
			exit(EXIT_FAILURE);
		}
		// if infile given, read this, if not, read from stdin (default)
		if (infile != "") {
			inputFile.exceptions ( std::ifstream::badbit );
			try{
				inputFile.open(infile.c_str(), std::ifstream::in);
				pCin = &inputFile;
			}
			catch (std::ifstream::failure e) {
			    std::cerr << "Exception opening input file in "<< infile <<"\n";
			    return 0;
			}
		}
		try {
			    lm::ngram::ModelType model_type;
			    if (RecognizeBinary(modelfile, model_type)) {
			    		lm::ngram::Model model(modelfile);
			    		std::string line;
			    		bool newSentence = 1;
			    		int wordcount =0;
			    		int nbrOfAltSents=1;

			    		using namespace boost;

			    		while(std::getline(*pCin,line)){
			    			if(!line.empty()){
			    				// end of sentence, start new one
			    				if (contains(line, "#EOS")){
			    					newSentence = 1;
			    					int lastWordAlternatives = sentLattice[wordcount].size();
			    					nbrOfAltSents = nbrOfAltSents * lastWordAlternatives;
			    					printLattice(sentLattice, nbrOfAltSents, model);
			    					//printLatticeWithNgrams(sentLattice, nbrOfAltSents, model_type, modelfile);
			    					sentLattice.clear();
			    					wordcount=0;
			    					nbrOfAltSents=1;
			    					//startedWithPunc =0;
			    					//prev.clear(); prevPunc.clear();

			    				}
			    				// not at the end of a sentence: get word form(s)
			    				else{
			    					erase_all(line,"\t");
			    					erase_all(line,"\n");
			    					std::string word = line;
			    					//std::cout << word << '\n';

			    					//#start a new sentence
			    					if(newSentence ==1){
			    						newSentence=0;
			    						sentLattice[wordcount].push_back(word);
			    					}
			    					else{
			    						//alternative translation
			    						if(find_regex(word,regex("^/.+"))){
			    							sentLattice[wordcount].push_back(word);
			    							//std::cout << word << std::endl;
			    						}
			    						else{
			    							//count entries for previous words and multiply with nbrOfAltSents before storing new word
			    							int prevWordAlternatives = sentLattice[wordcount].size();
			    							nbrOfAltSents = nbrOfAltSents * prevWordAlternatives;
			    							wordcount++;
			    							sentLattice[wordcount].push_back(word);
			    						}
			    					}
			    				}
			    			}
			    		}
			    		inputFile.close();
			    } else {
			    	//model type not recognized: abort
			    	std::cerr << "model type not recognized, check content of " << modelfile << "!" << std::endl;
			    	exit(0);
			    }
			  } catch (const std::exception &e) {
			    std::cerr << e.what() << std::endl;
			    return 1;
			  }
			return 0;
}



void printMatrix(std::map< int, std::map< int, std::string > >sentMatrix){
	for(int opt=0; opt<sentMatrix.size();opt++){
		std::cout << opt << ": ";
		std::map< int, std::string> sent = sentMatrix[opt];
		for(int i=0;i<sent.size();i++){
			std::cout << sentMatrix[opt][i] << " ";
		}
		std::cout  << std::endl;
	}
}


bool probCompare(const std::pair<float, int>& firstElem, const std::pair<float, int>& secondElem) {
  return firstElem.first > secondElem.first;

}

void printTest(std::vector<std::pair<float,int> > sortedOpts){
	std::sort(sortedOpts.begin(), sortedOpts.end(), probCompare);
	for(int i=0;i<sortedOpts.size();i++){
		std::cout << "i position: " << i << ", contains pair 1st el: " << sortedOpts[i].first << " second elem: " << sortedOpts[i].second << "\n";
	}
}


void printSents(std::map< int, std::map< int, std::string > >sentMatrix, std::vector<std::pair<float,int> > sortedOpts){
	using namespace boost;
	bool startedWithPunc=0;
	std::string prev, prevPunc;

	std::sort(sortedOpts.begin(), sortedOpts.end(), probCompare);
	//for(int s=0;s<sortedOpts.size();s++){
	for(int s=0;(s<CUTOFF and s<sortedOpts.size());s++){
		//std::cerr << "i position: " << i << ", contains pair 1st el: " << sortedOpts[i].first << " second elem: " << sortedOpts[i].second << "\n";
		int opt = sortedOpts[s].second;
		//std::cout << opt << ": ";

		std::map< int, std::string> sent = sentMatrix[opt];
		for(int i=0;i<sent.size();i++){
					//punctuation marks come with their mi tag, split
					std::string line = sentMatrix[opt][i];
					std::vector<std::string> puncs (2);
					algorithm::split_regex(puncs, line,regex("-PUNC-") );
					std::string word = puncs.at(0);
					std::string pmi;

					if(puncs.size()>1){
						pmi = puncs.at(1);
					}
					else{
						//no punctuation: delete leading '/' (marks ambiguous words)
						if(starts_with(word,"/")){
							erase_head(word,1);
						}
						//std::cout << word << std::endl;
					}

					if(i ==0){
						// uppercase first word in sentence
						//	#TODO
						regex startpuncrx("FAA|FEA|FIA|FCA|FG|FLA|FPA|FRA");
						if( equals(word, ",") or ends_with(pmi,"T") ){
							startedWithPunc =1;
						}
						// starts with correct opening punctuation (¡ or ¿ or " etc)
						else if( regex_search(pmi,startpuncrx)){
								std::cout << word ;
								startedWithPunc =1;
								//std::cout << "matched " <<pmi << " word " << word << std::endl;
						}
						else
						{
							//std::wcout << std::endl;
							word[0] = std::toupper(word[0]);
							std::cout << word ;
							prev = word;
							prevPunc = pmi;
							startedWithPunc=0;
						}
					}
					else{
						if(! (equals(word, ",") and equals(prev,",") ) ){
							// if this is a punctuation mark,
							// check whether its closing (attach to previous word), pmi:
							// - ends with 'T'
							// - is FP (.), FC (,), FD (:), FX (;), FT (%), FS (...)
							// or opening (pmi ends with 'A') or is
							// special case '/' (FH) -> no space at all
							// mathematical signs: -, +, = -> treat same as words (spaces both left and right)
							regex rx(".*FH|FP|FC|FD|FX|FT|FS$");
//							if(regex_search(pmi,rx)){
//									std::wcout << L"matched " <<pmi << std::endl;
//							}
							//if sentence started with opening punctuation, uppercase first word
							if(startedWithPunc==1){
									word[0] =std::toupper(word[0]);
									startedWithPunc=0;
							}

							if( (!equals(pmi,"") and ends_with(pmi,"T")) or regex_search(pmi,rx) ||  equals(pmi, "FH") ){
								std::cout << word;
								prevPunc =pmi;
								prev = word;
							}
							else if(ends_with(pmi,"A") ){
								std::cout << " " << word;
								prevPunc =pmi;
							}
							else if(ends_with(prevPunc, "A") or equals(prevPunc, "FH")){
								std::cout << word;
								prevPunc = "";
								prev = word;
							}
							else{
								std::cout<< " " << word;
								prev = word;
							}
						}
					}
			}
			// if cutoff >1 print probability for this sentence, otherwise just a newline
		    (CUTOFF>1) ? std::cout << " p:" << sortedOpts[s].first << std::endl : std::cout << "\n";
	}
	// if cutoff > 1, print empty line between sentences
	if(CUTOFF>1){
		std::cout << "\n";
	}
}

// print sentence and generate words with foma fst
void printSentsMorphGen(std::map< int, std::map< int, std::string > >sentMatrix, std::vector<std::pair<float,int> > sortedOpts){
	using namespace boost;
	bool startedWithPunc=0;
	std::string prev, prevPunc;
	char  *result;

	std::sort(sortedOpts.begin(), sortedOpts.end(), probCompare);
	//for(int s=0;s<sortedOpts.size();s++){
	for(int s=0;(s<CUTOFF and s<sortedOpts.size());s++){
		//std::cerr << "i position: " << i << ", contains pair 1st el: " << sortedOpts[i].first << " second elem: " << sortedOpts[i].second << "\n";
		int opt = sortedOpts[s].second;
		//std::cout << opt << ": ";

		std::map< int, std::string> sent = sentMatrix[opt];
		for(int i=0;i<sent.size();i++){
					//punctuation marks come with their mi tag, split
					std::string line = sentMatrix[opt][i];
					std::vector<std::string> puncs (2);
					algorithm::split_regex(puncs, line,regex("-PUNC-") );
					std::string word = puncs.at(0);
					std::string pmi;

					// delete _NP tag from words
					if(boost::contains(word,"_NP:")){
						int position_to_erase = word.find("_NP");
						word.erase(position_to_erase,3);
					}

					char * writable = new char[word.size() + 1];
					std::copy(word.begin(), word.end(), writable);
					writable[word.size()] = '\0'; //  terminating 0


					if(puncs.size()>1){
						pmi = puncs.at(1);
					}
					else{
						//no punctuation: delete leading '/' (marks ambiguous words)
						/*if(starts_with(word,"/")){
							erase_head(word,1);
						}*/
						if(strncmp(writable, "/", strlen("/")) ==0 ){
							//std::cout << "writable before erase "<<writable << " writable after erase ";
							memmove (writable, writable+1, strlen (writable));
							//std::cout << writable << std::endl;
						}
						//std::cout << word << std::endl;
					}

					if(i ==0){
						// uppercase first word in sentence
						regex startpuncrx("FAA|FEA|FIA|FCA|FG|FLA|FPA|FRA");
						// starts with wrong punctuation: don't print punctuation but remember to uppercase next word
						if( equals(word, ",") or ends_with(pmi,"T") ){
							startedWithPunc =1;
						}
						// starts with correct opening punctuation (¡ or ¿ or " etc)
						else if( regex_search(pmi,startpuncrx)){
							std::cout << word ;
							startedWithPunc =1;
							prevPunc=pmi;
							//std::cout << "matched " <<pmi << " word " << word << std::endl;
						}
						else
						{
							//std::wcout << std::endl;
							//word[0] = std::toupper(word[0]);
							writable[0] =std::toupper(writable[0]);


							if(word[0] != '\0'){

								/* Apply analyzer.bin */
								result = apply_up(ah, writable);
								/* if no result from analyzer, just print original string TODO:: find better way */
								if(result == NULL){
									std::cout << word ;
								}
								else{
									std::cout << result ;
								}
							}
							prev = word;
							prevPunc = pmi;
							startedWithPunc=0;
						}
					}
					else{
						if(! (equals(word, ",") and equals(prev,",") ) ){
							// if this is a punctuation mark,
							// check whether its closing (attach to previous word), pmi:
							// - ends with 'T'
							// - is FP (.), FC (,), FD (:), FX (;), FT (%), FS (...)
							// or opening (pmi ends with 'A') or is
							// special case '/' (FH) -> no space at all
							// mathematical signs: -, +, = -> treat same as words (spaces both left and right)
							regex rx(".*FH|FP|FC|FD|FX|FT|FS$");
//							if(regex_search(pmi,rx)){
//									std::wcout << L"matched " <<pmi << std::endl;
//							}

							//if sentence started with opening punctuation, uppercase first word
							if(startedWithPunc==1){
									writable[0] =std::toupper(writable[0]);
									startedWithPunc=0;
							}

							// generate word form
							if(word[0] != '\0'){
								/* Apply analyzer.bin */
								result = apply_up(ah, writable);
								/* if no result from analyzer, just print original string TODO:: find better way */
								if(result == NULL){
									result = writable ;
								}
							}

							if( (!equals(pmi,"") and ends_with(pmi,"T")) or regex_search(pmi,rx) or  equals(pmi, "FH") ){
								//std::cout << result; --> for unknown reasons, foma return punctuation with newline after certain marks (e.g. ':')... not clear why. just print writable instead of result.
								std::cout << writable;
								//std::cout << "...matched pmi: " << pmi << "  result -" << writable;
								prevPunc =pmi;
								prev = word;
							}
							else if(ends_with(pmi,"A") ){
								std::cout << " " << result;
								prevPunc =pmi;
							}
							else if(ends_with(prevPunc, "A") or equals(prevPunc, "FH")){
								std::cout << result;
								prevPunc = "";
								prev = word;
							}
							else{
								std::cout<< " " << result;
								prev = word;
							}
						}
					}
					// free the string after finished using it
					delete[] writable;
			}
			// if cutoff >1 print probability for this sentence, otherwise just a newline
		    (CUTOFF>1) ? std::cout << " p:" << sortedOpts[s].first << std::endl : std::cout << "\n";
	}
	// if cutoff > 1, print empty line between sentences
	if(CUTOFF>1){
		std::cout << "\n";
	}
}


void printTestMorphs(std::map< int, std::map< int, std::string > >sentMatrix, std::vector<std::pair<float,int> > sortedOpts){
	using namespace boost;
	bool startedWithPunc=0;
	std::string prev, prevPunc;
	//std::cerr << "printing test morphs" << std::endl;

	std::sort(sortedOpts.begin(), sortedOpts.end(), probCompare);
	//for(int s=0;s<sortedOpts.size();s++){
	for(int s=0;(s<CUTOFF and s<sortedOpts.size());s++){
		//std::cerr << "i position: " << i << ", contains pair 1st el: " << sortedOpts[i].first << " second elem: " << sortedOpts[i].second << "\n";
		int opt = sortedOpts[s].second;
		//std::cout << opt << ": ";

		std::map< int, std::string> sent = sentMatrix[opt];
		for(int i=0;i<sent.size();i++){
					//punctuation marks come with their mi tag, split
					std::string line = sentMatrix[opt][i];
					std::vector<std::string> puncs (2);
					algorithm::split_regex(puncs, line,regex("-PUNC-") );
					std::string word = puncs.at(0);
					std::string pmi;
					//std::cout << word << std::endl;

					if(puncs.size()>1){
						pmi = puncs.at(1);
					}
					else{
						//no punctuation: delete leading '/' (marks ambiguous words)
						if(starts_with(word,"/")){
							erase_head(word,1);
						}
						//std::cout << word << std::endl;
					}

					if(i ==0){
						// uppercase first word in sentence
						word[0] = std::toupper(word[0]);
					}
					//std::cout << word<< std::endl;
					std::vector<std::string> strs;
					boost::split(strs,word,boost::is_any_of(":"));
					std::string lem = strs[0];
					std::cout << lem << " ";
					std::vector<std::string> morphs;
					boost::regex morphrx("\\+[^\\+]+");
					if(strs.size() > 1){
						boost::find_all_regex(morphs, strs[1], morphrx);
					}
					for(int j=0;j<morphs.size();j++){
						std::cout << morphs[j] << " ";
					}

			}
			// if cutoff >1 print probability for this sentence, otherwise just a newline
		    (CUTOFF>1) ? std::cout << " p:" << sortedOpts[s].first << std::endl : std::cout << "\n";
	}
	// if cutoff > 1, print empty line between sentences
	if(CUTOFF>1){
		std::cout << "\n";
	}
}

void getProbs(std::map< int, std::map< int, std::string > >& sentMatrix, const lm::ngram::Model &model){

	std::vector<std::pair<float, int> > sortedOpts;
	for(int opt=0; opt<sentMatrix.size();opt++){
			//std::cerr << opt << ": ";
			std::map< int, std::string> sent = sentMatrix[opt];

			lm::ngram::State state(model.BeginSentenceState()), out_state;
			// no sentence context
			//lm::ngram::State state(model.NullContextState()), out_state;
			const lm::ngram::Vocabulary &vocab = model.GetVocabulary();


			lm::FullScoreReturn ret;
			float total =0.0;

			for(int i=0;i<sent.size();i++)
			{
				std::string w = sent[i];
				// alternatives start with '/' and punctuation end with -PUNC-tag -> delete tag and leading '/'
				if(boost::starts_with(w,"/")){boost::erase_head(w,1);}
				if(boost::contains(w,"-PUNC-")){w = w.substr(0,1);}
				if(boost::contains(w,"_NP:")){
					//TODO replace _NP: with :
				}
				ret = model.FullScore(state, vocab.Index(w), out_state);
			//	std::cerr << "tested word " << w << " ,full p: " << ret.prob << " == " <<vocab.Index(w) <<'\n';
				total += ret.prob;
				state = out_state;

			}
			ret = model.FullScore(state, model.GetVocabulary().EndSentence(), out_state);
			total += ret.prob;
			//std::cerr  <<  " total p: " << total <<'\n';
			std::pair<float,int> mypair (total, opt);
			sortedOpts.push_back(mypair);
		}
	 printSents(sentMatrix,sortedOpts);
}

void getProbsMorphs(std::map< int, std::map< int, std::string > >& sentMatrix, const lm::ngram::Model &model){

	std::vector<std::pair<float, int> > sortedOpts;

	for(int opt=0; opt<sentMatrix.size();opt++){
			//std::cerr << opt << ": ";
			std::map< int, std::string> sent = sentMatrix[opt];

			lm::ngram::State state(model.BeginSentenceState()), out_state;
			// no sentence context
			//lm::ngram::State state(model.NullContextState()), out_state;
			const lm::ngram::Vocabulary &vocab = model.GetVocabulary();


			lm::FullScoreReturn ret;
			float total =0.0;

			for(int i=0;i<sent.size();i++)
			{
				std::string w = sent[i];
				//std::cerr << "word : "<< w << "sent size: "<< sent.size() << "\n";
				// alternatives start with '/' and punctuation end with -PUNC-tag -> delete tag and leading '/'
				if(boost::starts_with(w,"/")){boost::erase_head(w,1);}

				if(boost::contains(w,"-PUNC-")){w = w.substr(0,1);}

				// proper names are marked with _NP -> use only NP for getting probs
				std::string newLem = "NP:";
				boost::regex re("^.+_NP:");
				if(boost::contains(w,"_NP:")){
					w  = boost::regex_replace(w, re, newLem);
				}

				// split word into morphs and get probabilities
				std::vector<std::string> strs;
				boost::split(strs,w,boost::is_any_of(":"));
				std::string lem = strs[0];
				std::vector<std::string> morphs;
				boost::regex morphrx("\\+[^\\+]+");
				if(strs.size() > 1){
					boost::find_all_regex(morphs, strs[1], morphrx);
				}

				//std::cerr << "lemma: " << lem << ", morph size " << morphs.size() <<"\n";
				/*for(int j=0;j<morphs.size();j++){
					std::cerr << "    morph: " << morphs[j] << "\n";
				}*/

				ret = model.FullScore(state, vocab.Index(lem), out_state);
				//std::cerr << "tested word " << w << " ,full p: " << ret.prob << " == " <<vocab.Index(w) << "\n";
				total += ret.prob;
				state = out_state;
				// get Probs for morphs
				for(int j=0;j<morphs.size();j++){
					ret = model.FullScore(state, vocab.Index(morphs[j]), out_state);
					total += ret.prob;
					//std::cerr << "tested morph " <<  morphs[j] << " ,p: " << ret.prob << " == " <<vocab.Index(morphs[j]) << "\n";
					state = out_state;
				}

			}
			ret = model.FullScore(state, model.GetVocabulary().EndSentence(), out_state);
			total += ret.prob;
			//std::cerr  <<  " total p: " << total <<'\n';
			std::pair<float,int> mypair (total, opt);
			sortedOpts.push_back(mypair);
		}
	 if(print_test_morph ==1){
		// std::cerr << "printing test morphs" << std::endl;
		 printTestMorphs(sentMatrix,sortedOpts);
	 }
	 else{
		 printSentsMorphGen(sentMatrix,sortedOpts);
		// std::cerr << "printing generated words" << std::endl;
	//std::cerr << "\n";
	 }
}

void insertTransOpts(std::map< int, std::map< int, std::string > >&sentMatrix,int first,int last,std::vector< int > indexesOfAmbigWords){
	std::vector< std::string > wordarray = sentLattice[indexesOfAmbigWords[first]];
	int thisindex = indexesOfAmbigWords[first];

	for(int indexInFirstArray=0; indexInFirstArray<wordarray.size();indexInFirstArray++){
		//std::wcout << L"called with first:" << first << L" last:" <<last <<L", called at pos:" <<indexInFirstArray <<L" of" << thisindex << wordarray[indexInFirstArray] <<L" sentopts: " << sentOpts << std::endl;

		if(first<last){
			int startOpts = sentOpts;
		//			#print "recursive with first:$first  last:$last , called at pos:$indexInFirstArray of $thisindex ".@$wordarray[$indexInFirstArray]." sentopts: $sentOpts\n";
					//std::wcout << L"recursive with first:" << first << L" last:" << last << L", called at pos:" << indexInFirstArray << L" of " << thisindex << L" " << wordarray[indexInFirstArray] << L" sentopts "<< sentOpts << std::endl;
					insertTransOpts(sentMatrix,first+1,last,indexesOfAmbigWords);
					for(int i=startOpts;i<sentOpts;i++){
		//					#print "set opt:$i with word ".@$wordarray[$indexInFirstArray]." at first $first\n";
							sentMatrix[i][thisindex]= wordarray[indexInFirstArray];
				}
		}
		else{
					sentMatrix[sentOpts][indexesOfAmbigWords[first]]= wordarray[indexInFirstArray];
					//std::wcout << L"filled with opt: " <<sentOpts << L" with word " << wordarray[indexInFirstArray] << L" at positon " << first ;
		//			#print "filled opt:$sentOpts with word ".@$wordarray[$indexInFirstArray]." at pos $first ";
		//			#print "opt+1 hieer\n";
					sentOpts++;
		}
	}

}


void printLattice(std::map< int, std::vector<std::string> > &sentLattice, int nbrOfAltSents, const lm::ngram::Model &model){
	int nbrOfWords = sentLattice.size();
	std::map< int, std::map< int, std::string > >sentMatrix;
	//std::cerr << "number of alts: " << nbrOfAltSents << std::endl;
	std::vector< int > indexesOfAmbigWords;
	//create matrix: $nbrOfAltSents x $nbrOfWords that contains all possible sentences
	for(int i =0; i< nbrOfWords; i++){
		if(sentLattice[i].size()>1){
			indexesOfAmbigWords.push_back(i);
		}
		// otherwise: fill matrix with $wordarray[0]
		else{
			for(int opt=0;opt<nbrOfAltSents;opt++){
				sentMatrix[opt][i] = sentLattice[i].at(0);
			}
		}
	}
	//	# if all words are ambiguous: initialize hash with dummy value
	if(indexesOfAmbigWords.size() == sentLattice.size() and sentLattice.size()>0){
		for(int opt=0;opt<nbrOfAltSents;opt++){
				sentMatrix[opt][0]="dummy";
		}
		//std::wcout << L"sentLattice all ambs: " << sentLattice[0].at(0) << std::endl;
	}
	if(indexesOfAmbigWords.size()>0){
		int first =0;
		int last = indexesOfAmbigWords.size()-1;
		insertTransOpts(sentMatrix,first,last,indexesOfAmbigWords);
	}

	//printMatrix(sentMatrix);
	morphProbs ? getProbsMorphs(sentMatrix,model) : getProbs(sentMatrix,model);
	sentOpts=0;

	//printSents(sentMatrix);

}



