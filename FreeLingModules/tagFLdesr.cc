/*
compile: g++ -o tagFLdesr tagFLdesr.cc -lboost_filesystem-mt -lpcre -lcfg+ -ldb_cxx -lfreeling -lboost_program_options-mt -I/opt/matxin/local/include/ -L/opt/matxin/local/lib/

 */

using namespace std;

#include <sstream>
#include <iostream>

#include <map>
#include <vector>
#include <boost/algorithm/string.hpp>

#include "config.h"
#include "freeling.h"
#include "analyzer.h"
#include <freeling/morfo/language.h>

wstring MapEagleTagMorphoFeat(wstring s) { // s: eagletag already in lowercase
  wostringstream features;

  wstring cpos = s.substr(0,1);
  wstring gen;
  wstring num;
  wstring form;
  wstring per;
  wstring mod;
  wstring ten;
  wstring pno;
  wstring fun;
  wstring cas;
  wstring type;
  wstring semclass;
  
  if (cpos == L"a") // Adjectives => 4:gen,5:num[,6:fun]
  {
    gen = s.substr(3,1);
    num = s.substr(4,1);
    fun = s.substr(5,1);
    features<<L"gen="<<gen<<L"|num="<<num;
    if (fun == L"p")
    {
      features<<L"|fun="<<fun;
    }
  }
  else if (cpos == L"d")		// Determiners => 4:gen,5:num[,3:per[,6:pno]]
  {
    gen = s.substr(3,1);
    num = s.substr(4,1);
    per = s.substr(2,1);
    pno = s.substr(5,1);
    features<<L"gen="<<gen<<L"|num="<<num;
    if (per != L"0")
    {
      features<<L"|per="<<per;
      if (pno != L"0")
      {
        features<<L"|pno="<<pno;
      }
    }
  }
  else if (cpos == L"n")	// Nouns => 3:gen,4:num, special case, proper nouns: give them pos=nc, but mark as np in morph column (np=SP,O0,G0,V0)-> delete, desr can't handle this
  {
    gen = s.substr(2,1);
    if (gen == L"0")
    {
      gen = L"c";
    }
    num = s.substr(3,1);
    if (num == L"0")
    {
      num = L"c";
    }
    type = s.substr(1,1);
    //if proper noun, add type to morph
    if(type == L"p")
    {
       semclass = s.substr(4,2);
       features<<L"gen="<<gen<<L"|num="<<num<<L"|np="<<semclass;
       
    }
    else
    {
      features<<L"gen="<<gen<<L"|num="<<num;
    }
  }
  else if (cpos == L"v")	// Verbs => 7:gen,6:num[,5:per],3:mod[,4:ten]
  {
    gen = s.substr(6,1);
    if (gen == L"0")
    {
      gen = L"c";
    }
    num = s.substr(5,1);
    if (num == L"0")
    {
      num = L"c";
    }
    features<<L"gen="<<gen<<L"|num="<<num;
    per = s.substr(4,1);
    mod = s.substr(2,1);
    ten = s.substr(3,1);
    if (per != L"0")
    {
      features<<L"|per="<<per;
    }
    features<<L"|mod="<<mod;
    if (ten != L"0")
    {
      features<<L"|ten="<<ten;
    }
  }
  else if (cpos == L"p")	// Pronouns => 4:gen,5:num[,3:per][,6:cas]
  {	// TODO: desr ignores the number of the possessor (position 7) in possessive pronouns!?!  and politeness (position 8) in general?!?
    // possessive FL: PX PX1MS0P0=> px1ms000 nuestro	nuestro	p	px	gen=m|num=s|per=1
    // interrogative FL: PT000000 => Dónde	Dónde	p	pt	gen=c|num=c
    gen = s.substr(3,1);
    num = s.substr(4,1);
    // relative pronouns
    // que: FL: PR0CN000 => que	que	p	pr	gen=0|num=c
    // donde: FL PR000000 => donde	donde	p	pr	gen=0|num=0
    if (boost::iequals(s.substr(0,2),L"pr"))
    {
      gen = L"0";
      if (num == L"n")
      {
        num = L"c";
      }
    }
    else
    { 
      if (gen == L"0")
      {
        gen = L"c";
      }
      if (num == L"0" || num == L"n")
      {
        num = L"c";
      }
    }
    features<<L"gen="<<gen<<L"|num="<<num;
    // special case 'se' FL: P00CN000, should be -> gen=c|num=c|per=3 (not p0!, per=3)
    per = s.substr(2,1);
    if(per == L"0" && boost::iequals(s.substr(0,2),L"p0") )
    {
      features<<L"|per="<<L"3";
    }
    else if (per != L"0")
    {
      features<<L"|per="<<per;
    }
    cas = s.substr(5,1);
    if (cas != L"0")
    {
      features<<L"|cas="<<cas;
    }
  }
  else if (cpos == L"s")	// Prepositions => 4:gen,5:num,3:for
  {
    gen = s.substr(3,1);
    {
      if (gen == L"0")
      {
	gen = L"c";
      }
    }
    num = s.substr(4,1);
    if (num == L"0")
    {
      num = L"c";
    }
    form = s.substr(2,1);
    features<<L"gen="<<gen<<L"|num="<<num<<L"|for="<<form;
  }  
  else// if (cpos == L"r") c|f|i|r|y|w|z
  {
    features<<L"_";
  }
  features<<L"\t_\t_\t_\t_";
  return features.str();
}

void PrintNumber(sentence::const_iterator &w, int c)
{
		wcout<<c;				//ID
		wcout<<L"\t"<<w->get_form();			//FORM
		wcout<<L"\t"<<w->get_form();			//LEMMA take the form as lemma
		wcout<<L"\tz";			//CPOS
		wcout<<L"\tZ";			//POS
		wcout<<L"\t"<<MapEagleTagMorphoFeat(w->get_tag());	//MORPH
		wcout<<endl;
}


void PrintMorfo(list<sentence> &ls, POS_tagger *tagger, maco *morfo2) {
 // word::const_iterator a;
  sentence::const_iterator w;
  sentence::const_iterator next_w;
  sentence::const_iterator prior_w;
  list<sentence>::iterator is;
  
  
  //for (is=ls.begin(); is!=ls.end(); is++) { wcout<<L"ddd\n";}

//  wcout<<L"----------- MORPHOLOGICAL INFORMATION -------------"<<endl;
//ID	FORM	LEMMA	CPOS	POS	MORPH	HEAD	DEP	PH	PD

//1	La	el	d	da	gen=f|num=s	2	spec	_	_
//2	madre	madre	n	nc	gen=f|num=s	3	suj	_	_
//3	come	comer	v	vm	gen=c|num=s|per=3|mod=i|ten=p	0	sentence	_	_
//4	manzanas	manzana	n	nc	gen=f|num=p	3	cd	_	_
//5	.	.	F	Fp	_	3	f	_	_


  for (is=ls.begin(); is!=ls.end(); is++) {

    
    // for each word in sentence
    int c = 1;
    for (w=is->begin(); w!=is->end(); w++) 
    {
      
      wstring eagletag = w->get_tag();
      std::transform(eagletag.begin(), eagletag.end(), eagletag.begin(), ::tolower);
      wstring pos = eagletag.substr(0,2);
      if(boost::iequals(pos,L"p0"))
      {
	pos = L"pp";
      }
      else if(boost::iequals(pos,L"np"))
      {
	pos = L"nc";
      }
      wstring cpos = eagletag.substr(0,1);
      wstring form = w->get_form();
       
      if (cpos == L"w")
	// dates: 24_de_junio     [??:24/6/??:??.??:??] -> 
	// 6	24	24	w	w	_	3	cc	_	_
	// 7	de	de	s	sp	gen=c|num=c|for=s	6	CONCAT	_	_
	// 8	junio	junio	n	nc	gen=m|num=s	7	CONCAT	_	_
	{
	  vector<wstring> tokens;
	  split(tokens,form,boost::is_any_of("_"));
	  
	  for(vector<wstring>::const_iterator p=tokens.begin();p!=tokens.end();p++)
	  {

 	    word wd = word(*p);
	  //  wcout<<wd.get_form();
  	    list<word> l (1,wd);  
  	    sentence s = sentence(l);
	  //  wcout<<s.words_begin()->get_form();
	    morfo2->analyze(s);
  	    tagger->analyze(s);
	    wcout<<c;
	    wcout<<L"\t"<<s.words_begin()->get_form();
	    wcout<<L"\t"<<s.words_begin()->get_lemma();
	    wstring eagletag2 = s.words_begin()->get_tag();
	    std::transform(eagletag2.begin(), eagletag2.end(), eagletag2.begin(), ::tolower);
	    wstring pos2 = eagletag2.substr(0,2);
	    //punctuation, should not occur here (?)
	    if (pos2.find(L"f") ==0)
	    {
	    pos2.replace(0,1,L"F");
	    }
	    //number in a date -> change tag from 'z' to 'w' (not very regular done in Tanl!!)
	    else if (pos2.find(L"z") ==0)
	    {
	    pos2.replace(0,1,L"w");
	    }
	    wcout<<L"\t"<<pos2.substr(0,1);	//CPOS

	    wcout<<L"\t"<<pos2;		//POS
	    wcout<<L"\t"<<MapEagleTagMorphoFeat(eagletag2);	//MORPH
	    wcout<<endl;
	    c++;
	  }
	}
      // change tag of numbers to dn if they modify a noun
      else if(cpos == L"z" && boost::next(w)!=is->end())
      {
	  //save iterator at this point, then go to the next token
	  next_w =boost::next(w);
	  wstring next_tag = next_w->get_tag();
	  if( boost::iequals(next_tag.substr(0,2),L"NC") ||next_tag.find(L"A") ==0 )
	  {
	    wstring next_pos_n = next_tag.substr(0,2);
	    wstring next_pos_a = next_tag.substr(0,1);
	    wstring next_number_n = next_tag.substr(3,1);
	    wstring next_number_a = next_tag.substr(4,1);
	   
	    if((boost::iequals(next_pos_n,L"NC") && boost::iequals(next_number_n,L"P"))|| (boost::iequals(next_pos_a,L"A") && boost::iequals(next_number_a,L"P"))  )
	    {
	      eagletag = L"dn0cp0";
	      wcout<<c;				//ID
	      wcout<<L"\t"<<w->get_form();	//FORM
	      wcout<<L"\t"<<w->get_form();	//LEMMA
	      wcout<<L"\t"<<L"d";			//CPOS
	      wcout<<L"\t"<<L"dn";		//POS
	      wcout<<L"\t"<<MapEagleTagMorphoFeat(eagletag);	//MORPH
	      wcout<<endl;
	    }
	    else
	    {
	      PrintNumber(w,c);
	    }
	    
	  }
	  else
	  {
	    // change tag of year numbers 'en el 2008' (freeling fails here) from 'z' to 'w'
	    if(boost::prior(w)!=is->begin())
	    {
	      prior_w = boost::prior(w);
	      if(boost::iequals(prior_w->get_form(),L"el"))
	      {
		wcout<<c;				//ID
		wcout<<L"\t"<<form;			//FORM
		wcout<<L"\t"<<form;			//LEMMA take the form as lemma
		wcout<<L"\tw";			//CPOS
		wcout<<L"\tw";			//POS
		wcout<<L"\t"<<MapEagleTagMorphoFeat(eagletag);	//MORPH
		wcout<<endl;
	      }
	      else
	      { 
		PrintNumber(w,c);
	      }
	    } 
	    else
	    {
	      PrintNumber(w,c);
	    }
	  }
	  
	  //set iterator back to where it was
	 // w = this_w;
	 // w--;
	  //wcout<<L"new this word: "<<w->get_form()<<L"\n";
	  c++;
      }
      else
      {
	wcout<<c;			//ID
	wcout<<L"\t"<<w->get_form();	//FORM
	// special case lemma: lemma for forms of estar are the word forms (desr expects that).. also set VA to VM
	wstring lemma = w->get_lemma();
	if(boost::iequals(lemma, L"estar"))
	{
	  wcout<<L"\t"<<w->get_form();	
	}
	else
	{
	  wcout<<L"\t"<<lemma;	//LEMMA
	}
	if (pos.find(L"f") ==0)
	{
	  pos = eagletag;
	  pos.replace(0,1,L"F"); 
	}
	else if (pos.find(L"z") ==0)
	{
	  pos.replace(0,1,L"Z");
	}
	wcout<<L"\t"<<pos.substr(0,1);	//CPOS
	wcout<<L"\t"<<pos;		//POS
	wcout<<L"\t"<<MapEagleTagMorphoFeat(eagletag);	//MORPH
	wcout<<endl;
	c++;
      }
  //  wcout<<endl;
    }
    wcout<<endl;
  }
}


//---------------------------------------------
// Plain text, start with tokenizer.
//---------------------------------------------
void ProcessPlain(const config &cfg, tokenizer *tk, splitter *sp, maco *morfo,
                  POS_tagger *tagger, nec* neclass, senses* sens, maco *morfo2)
{
  wstring text;
  list<word> av;
  list<word>::const_iterator i;
  list<sentence> ls;
  int nsentence = 1;

  //long unsigned int offset = 0;
  while (std::getline(std::wcin, text))
  {
      av = tk->tokenize(text);
      ls = sp->split(av, cfg.AlwaysFlush);
      morfo->analyze(ls);
//       if (cfg.SENSE_SenseAnnotation != NONE)
//         sens->analyze(ls);
      tagger->analyze(ls);
      PrintMorfo(ls,tagger,morfo2);

      av.clear(); // clear list of words for next use
      ls.clear(); // clear list of sentences for next use
    }

    // process last sentence in buffer (if any)
    av = tk->tokenize(text);
    ls = sp->split(av, true);  //flush splitter buffer
    morfo->analyze(ls);
//     if (cfg.SENSE_SenseAnnotation!=NONE)
//       sens->analyze(ls);
    tagger->analyze(ls);
    PrintMorfo(ls,tagger,morfo2);

}

//---------------------------------------------
// Sample main program
//---------------------------------------------
int main(int argc, char **argv)
{
   
  // we use pointers to the analyzers, so we
  // can create only those strictly necessary.
  tokenizer *tk = NULL;
  splitter *sp = NULL;
  maco *morfo = NULL;
  maco *morfo2 = NULL;
  nec *neclass = NULL;
  senses *sens = NULL;
  POS_tagger *tagger = NULL;

  // read configuration file and command-line options
  config cfg(argc, argv);
  
    // set locale to an UTF8 comaptible locale
  //util::init_locale(L"default");
  util::init_locale(cfg.Locale);
  
  
  // create required analyzers

  tk = new tokenizer(cfg.TOK_TokenizerFile);
  sp = new splitter(cfg.SPLIT_SplitterFile);

  // the morfo class requires several options at creation time.
  // they are passed packed in a maco_options object.
  maco_options opt(cfg.Lang);
  // boolean options to activate/desactivate modules
  // default: all modules activated (options set to "false")
 
  opt.set_active_modules(bool(cfg.MACO_UserMap),
			 bool(cfg.MACO_AffixAnalysis),    bool(cfg.MACO_MultiwordsDetection),
                         bool(cfg.MACO_NumbersDetection), bool(cfg.MACO_PunctuationDetection),
                         bool(cfg.MACO_DatesDetection),   bool(cfg.MACO_QuantitiesDetection),
                         bool(cfg.MACO_DictionarySearch), bool(cfg.MACO_ProbabilityAssignment),
                         bool(cfg.MACO_NERecognition), bool(cfg.MACO_OrthographicCorrection));
  // decimal/thousand separators used by number detection
  opt.set_nummerical_points(cfg.MACO_Decimal,cfg.MACO_Thousand);
  // Minimum probability for a tag for an unkown word
  opt.set_threshold(cfg.MACO_ProbabilityThreshold);
  // Data files for morphological submodules. by default set to ""
  // Only files for active modules have to be specified  

  opt.set_data_files(cfg.MACO_UserMapFile,
		     cfg.MACO_LocutionsFile,   cfg.MACO_QuantitiesFile,
                     cfg.MACO_AffixFile,       cfg.MACO_ProbabilityFile,
                     cfg.MACO_DictionaryFile,  cfg.MACO_NPDataFile,
                     cfg.MACO_PunctuationFile, cfg.MACO_CorrectorFile);
  // create analyzer with desired options
  morfo = new maco(opt);
  
  // set DatesDetection to false and create another morfo, in order to analyze the splitted  multiword tokens
    opt.set_active_modules(bool(cfg.MACO_UserMap),
			 bool(cfg.MACO_AffixAnalysis),    bool(cfg.MACO_MultiwordsDetection),
                         bool(cfg.MACO_NumbersDetection), bool(cfg.MACO_PunctuationDetection),
                         false,  false,
                         bool(cfg.MACO_DictionarySearch), bool(cfg.MACO_ProbabilityAssignment),
                         bool(cfg.MACO_NERecognition), bool(cfg.MACO_OrthographicCorrection));
    morfo2 = new maco(opt);
    
  if (cfg.TAGGER_which == HMM)
    tagger = new hmm_tagger(cfg.Lang, cfg.TAGGER_HMMFile, bool(cfg.TAGGER_Retokenize),
                            cfg.TAGGER_ForceSelect);
  else if (cfg.TAGGER_which == RELAX)
    tagger = new relax_tagger(cfg.TAGGER_RelaxFile, cfg.TAGGER_RelaxMaxIter,
                              cfg.TAGGER_RelaxScaleFactor, cfg.TAGGER_RelaxEpsilon,
                              cfg.TAGGER_Retokenize, cfg.TAGGER_ForceSelect);

  if (cfg.NEC_NEClassification)
    neclass = new nec(cfg.NEC_NECFile);

//   if (cfg.SENSE_SenseAnnotation!=NONE)
//     sens = new senses(cfg.SENSE_SenseFile);

  // Input is plain text.
  ProcessPlain(cfg, tk, sp, morfo, tagger, neclass, sens, morfo2);

  // clean up. Note that deleting a null pointer is a safe (yet useless) operation
  delete tk;
  delete sp;
  delete morfo;
  delete morfo2;
  delete tagger;
  delete neclass;
  delete sens;
}

