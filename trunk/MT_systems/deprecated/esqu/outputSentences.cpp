// compile with:
// g++ -o outputSentences outputSentences.cpp -I/path-to-kenlm -DKENLM_MAX_ORDER=6 -L/path-to-kenlm/lib/ -lkenlm
// g++ -o outputSentences outputSentences.cpp -I/home/clsquoia/kenlm-master/ -DKENLM_MAX_ORDER=6 -L/home/clsquoia/kenlm-master/lib/ -lkenlm -lboost_regex

#include <iostream>
#include <map>
#include "lm/model.hh"
#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/regex.hpp>

int sentOpts =0;
//std::map< int, std::vector<std::wstring> > sentLattice;
std::map< int, std::vector<std::string> > sentLattice;
//lm::ngram::Model model("test.binary");
std::string usagestring = "Usage: outputSentences -f model (-n n-best, default n=3) -h help (provide data on stdin)";
std::string helpstring=	"Reads output data from MT system on stdin and prints out n-best sentences\n"
		"-h\t\tprint help\n"
		"-f\t\tkenlm language model (binary!)\n"
		"-n\t\tprint n-best (optional, default is 3)\n";
static int  CUTOFF = 3;


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
						//std::wcout << word << std::endl;
					}

					if(i ==0){
						// uppercase first word in sentence
						//	#TODO
						if( equals(word, ",") or ends_with(pmi,"T")   ){
							startedWithPunc =1;
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
			// print probability for this sentence
			std::cout << " p:" << sortedOpts[s].first << std::endl;
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

	getProbs(sentMatrix,model);
	sentOpts=0;
	//printMatrix(sentMatrix);
	//printSents(sentMatrix);

}

int main(int argc, char *argv[]) {
	//	std::setlocale(LC_ALL, "en_US.utf8");
		int opt = 1;
		bool sentence_context =1;
		const char *file = NULL;
		while ((opt = getopt(argc, argv, "f:n:h")) != -1) {
		      switch(opt) {
		        case 'f':
		        	//std::cerr << optarg<< "\n";
		        	file = optarg;
		        	break;
		        case 'n':
		        	CUTOFF = atoi(optarg);
		        	break;
		        case 'h':
		        	std::cerr << usagestring << '\n';
		        	std::cerr << helpstring << '\n';
		            exit(0);
		        default:
		            std::cerr << usagestring << '\n';
		            std::cerr << helpstring << '\n';
		            exit(EXIT_FAILURE);
		    }
		}
		if (!file){
			std::cerr << usagestring << '\n';
			exit(EXIT_FAILURE);
		}
		try {
			    lm::ngram::ModelType model_type;
			    if (RecognizeBinary(file, model_type)) {
			    		lm::ngram::Model model(file);
			    		std::string line;
			    		bool newSentence = 1;
			    		int wordcount =0;
			    		int nbrOfAltSents=1;

			    		using namespace boost;

			    		while(std::getline(std::cin,line)){
			    			if(!line.empty()){
			    				// end of sentence, start new one
			    				if (contains(line, "#EOS")){
			    					newSentence = 1;
			    					int lastWordAlternatives = sentLattice[wordcount].size();
			    					nbrOfAltSents = nbrOfAltSents * lastWordAlternatives;
			    					printLattice(sentLattice, nbrOfAltSents, model);
			    					//printLatticeWithNgrams(sentLattice, nbrOfAltSents, model_type, file);
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

			    } else {
			    	//model type not recognized: abort
			    	std::cerr << "model type not recognized, check content of " << file << "!" << std::endl;
			    	exit(0);
			    }
			  } catch (const std::exception &e) {
			    std::cerr << e.what() << std::endl;
			    return 1;
			  }
			return 0;
}

