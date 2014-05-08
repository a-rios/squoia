// compile with:
// g++ -o outputSentences outputSentences.cpp -I/path-to-kenlm -DKENLM_MAX_ORDER=6 -L/path-to-kenlm/lib/ -lkenlm
// g++ -o outputSentences outputSentences.cpp -I/home/clsquoia/kenlm-master/ -DKENLM_MAX_ORDER=6 -L/home/clsquoia/kenlm-master/lib/ -lkenlm -lboost_regex

#include <iostream>
#include <string>
#include <locale>
#include <map>
#include "lm/model.hh"
#include <boost/algorithm/string.hpp>
#include <boost/algorithm/string/regex.hpp>
#include <boost/regex.hpp>

int sentOpts =0;
std::map< int, std::vector<std::wstring> > sentLattice;


void printMatrix(std::map< int, std::map< int, std::wstring > >sentMatrix){
	for(int opt=0; opt<sentMatrix.size();opt++){
		std::wcout << opt << L": ";
		std::map< int, std::wstring> sent = sentMatrix[opt];
		for(int i=0;i<sent.size();i++){
			std::wcout << sentMatrix[opt][i] << L" ";
		}
		std::wcout << std::endl;
	}
}

void printSents(std::map< int, std::map< int, std::wstring > >sentMatrix){
	using namespace boost;
	bool startedWithPunc=0;
	std::wstring prev, prevPunc;

	for(int opt=0; opt<sentMatrix.size();opt++){
		std::wcout << opt << L": ";
		std::map< int, std::wstring> sent = sentMatrix[opt];
				for(int i=0;i<sent.size();i++){
					//punctuation marks come with their mi tag, split
					std::wstring line = sentMatrix[opt][i];
					std::vector<std::wstring> puncs (2);
					algorithm::split_regex(puncs, line,regex("-PUNC-") );
					std::wstring word = puncs.at(0);
					std::wstring pmi;

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
						if( equals(word, L",") or ends_with(pmi,L"T")   ){
							startedWithPunc =1;
						}
						else
						{
							std::wcout << std::endl;
							word[0] = std::towupper(word[0]);
							std::wcout  << word ;
							prev = word;
							prevPunc = pmi;
							startedWithPunc=0;
						}
					}
					else{
						if(! (equals(word, L",") and equals(prev,L",") ) ){
							// if this is a punctuation mark,
							// check whether its closing (attach to previous word), pmi:
							// - ends with 'T'
							// - is FP (.), FC (,), FD (:), FX (;), FT (%), FS (...)
							// or opening (pmi ends with 'A') or is
							// special case '/' (FH) -> no space at all
							// mathematical signs: -, +, = -> treat same as words (spaces both left and right)
							wregex rx(L".*FH|FP|FC|FD|FX|FT|FS$");
//							if(regex_search(pmi,rx)){
//									std::wcout << L"matched " <<pmi << std::endl;
//							}
							if( (!equals(pmi,L"") and ends_with(pmi,L"T")) or regex_search(pmi,rx) ||  equals(pmi, L"FH") ){
								std::wcout << word;
								prevPunc =pmi;
								prev = word;
							}
							else if(ends_with(pmi,L"A") ){
								std::wcout << L" " << word;
								prevPunc =pmi;
							}
							else if(ends_with(prevPunc, L"A") or equals(prevPunc, L"FH")){
								std::wcout << word;
								prevPunc = L"";
								prev = word;
							}
							else{
								std::wcout<< L" " << word;
								prev = word;
							}
						}
					}
			}
			std::wcout << std::endl;
	}
}



void insertTransOpts(std::map< int, std::map< int, std::wstring > >&sentMatrix,int first,int last,std::vector< int > indexesOfAmbigWords){
	std::vector< std::wstring > wordarray = sentLattice[indexesOfAmbigWords[first]];
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


void printLattice(std::map< int, std::vector<std::wstring> > &sentLattice, int nbrOfAltSents){
	int nbrOfWords = sentLattice.size();
	std::map< int, std::map< int, std::wstring > >sentMatrix;
	std::wcerr << L"number of alts: " << nbrOfAltSents << std::endl;
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
				std::wcout<< L"hieeeer" <<std::endl;
				sentMatrix[opt][0]=L"dummy";
		}
		//std::wcout << L"sentLattice all ambs: " << sentLattice[0].at(0) << std::endl;
	}
	if(indexesOfAmbigWords.size()>0){
		int first =0;
		int last = indexesOfAmbigWords.size()-1;
		insertTransOpts(sentMatrix,first,last,indexesOfAmbigWords);
	}

	sentOpts=0;
	//std::wcout << sentLattice.size() <<L"###############################" << std::endl;
	//printMatrix(sentMatrix);
	//std::wcout << sentLattice.size() <<L"###############################" << std::endl;
	//sentMatrix.clear();
	printSents(sentMatrix);
	//	#print "\n--------------------------\n";

}


int main() {
	std::setlocale(LC_ALL, "en_US.utf8");
	std::wstring line; // prev, prevPunc;
	bool newSentence = 1;
	//bool startedWithPunc = 0;
	int wordcount =0;
	int nbrOfAltSents=1;

	using namespace boost;

	while(std::getline(std::wcin,line)){
		if(!line.empty()){
			// end of sentence, start new one
			if (contains(line, "#EOS")){
				newSentence = 1;
				int lastWordAlternatives = sentLattice[wordcount].size();
				nbrOfAltSents = nbrOfAltSents * lastWordAlternatives;
				printLattice(sentLattice, nbrOfAltSents);
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
				std::wstring word = line;

				//#start a new sentence
				if(newSentence ==1){
					newSentence=0;
					sentLattice[wordcount].push_back(word);
				}
				else{
					//alternative translation
					if(find_regex(word,regex("^/.+"))){
						sentLattice[wordcount].push_back(word);
						//std::wcout << word << std::endl;
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
//	while (std::getline(std::wcin),s){
//		std::wcout << s << std::endl;
//	 }
//  using namespace lm::ngram;
//  Model model("test.binary");
//  State state(model.BeginSentenceState()), out_state;
//  const Vocabulary &vocab = model.GetVocabulary();
//  std::string word;
//  while (std::cin >> word) {
//    std::cout << model.Score(state, vocab.Index(word), out_state) << '\n';
//    state = out_state;
//  }



}




