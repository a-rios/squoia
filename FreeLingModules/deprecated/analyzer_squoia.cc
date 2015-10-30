//////////////////////////////////////////////////////////////////
//
//    FreeLing - Open Source Language Analyzers
//
//    Copyright (C) 2004   TALP Research Center
//                         Universitat Politecnica de Catalunya
//
//    This library is free software; you can redistribute it and/or
//    modify it under the terms of the GNU General Public
//    License as published by the Free Software Foundation; either
//    version 3 of the License, or (at your option) any later version.
//
//    This library is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//    General Public License for more details.
//
//    You should have received a copy of the GNU General Public
//    License along with this library; if not, write to the Free Software
//    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
//
//    contact: Lluis Padro (padro@lsi.upc.es)
//             TALP Research Center
//             despatx C6.212 - Campus Nord UPC
//             08034 Barcelona.  SPAIN
//
////////////////////////////////////////////////////////////////

#include "analyzer.h"

using namespace std;

//---------------------------------------------
// read configuration file and command-line options, 
// and create appropriate analyzers
//---------------------------------------------

analyzer::analyzer(config *c) {

  iden=NULL; tk=NULL; sp=NULL; morfo=NULL; neclass=NULL; sens=NULL;
  dsb=NULL; tagger=NULL; phon=NULL; parser=NULL; dep=NULL; corfc=NULL;
  
  cfg = c;
  offs = 0;
  nsentence = 1;

  /// set the locale to UTF to properly handle special characters.
  util::init_locale(cfg->Locale);

  if (cfg->OutputFormat==IDENT) {
    // language identification requested. We're not doing anything else
    iden = new lang_ident(cfg->IDENT_identFile);
    return;
  }

  if (!((cfg->InputFormat < cfg->OutputFormat) or
        (cfg->InputFormat == cfg->OutputFormat and cfg->InputFormat == TAGGED
         and cfg->NEC_NEClassification)))
    {
      wcerr <<L"Error - Input format cannot be more complex than desired output."<<endl;
      exit (1);
    }

  if (cfg->COREF_CoreferenceResolution and cfg->OutputFormat<=TAGGED) {
    wcerr <<L"Error - Requested coreference resolution is only compatible with output format 'parsed' or 'dep'." <<endl;
    exit (1);
  }

  if (cfg->OutputFormat < TAGGED and (cfg->SENSE_WSD_which == UKB))   {
    wcerr <<L"Error - UKB word sense disambiguation requires PoS tagging. Specify 'tagged', 'parsed' or 'dep' output format." <<endl;
    exit (1);
  }

  if (cfg->OutputFormat != TAGGED and cfg->TrainingOutput) {
    wcerr <<L"Warning - OutputFormat changed to 'tagged' since option --train was specified." <<endl;
    cfg->OutputFormat = TAGGED;
  }
  
  //--- create needed analyzers, depending on given options ---//

  // load tagset information
  if (not cfg->TAGSET_TagsetFile.empty())
    tags = new tagset(cfg->TAGSET_TagsetFile);

  // tokenizer requested
  if (cfg->InputFormat < TOKEN and cfg->OutputFormat >= TOKEN)
    tk = new tokenizer (cfg->TOK_TokenizerFile);
  // splitter requested
  if (cfg->InputFormat < SPLITTED and cfg->OutputFormat >= SPLITTED)
    sp = new splitter (cfg->SPLIT_SplitterFile);

  // morfological analysis requested
  if (cfg->InputFormat < MORFO and cfg->OutputFormat >= MORFO) {
    // the morfo class requires several options at creation time.
    // they are passed packed in a maco_options object.
    maco_options opt (cfg->Lang);
    // boolean options to activate/desactivate modules
    // default: all modules deactivated (options set to "false")
    opt.set_active_modules (cfg->MACO_UserMap,
                            cfg->MACO_AffixAnalysis,
                            cfg->MACO_MultiwordsDetection,
                            cfg->MACO_NumbersDetection,
                            cfg->MACO_PunctuationDetection,
                            cfg->MACO_DatesDetection,
                            cfg->MACO_QuantitiesDetection,
                            cfg->MACO_DictionarySearch,
                            cfg->MACO_ProbabilityAssignment,
                            cfg->MACO_NERecognition,
                            cfg->MACO_OrthographicCorrection);

  // NEC requested
  //if (cfg->InputFormat <= TAGGED and cfg->OutputFormat >= TAGGED and 
    //  (cfg->NEC_NEClassification or cfg->COREF_CoreferenceResolution)) {
    //neclass = new nec (cfg->NEC_NECFile);
    //}
    if(cfg->NEC_NEClassification or cfg->COREF_CoreferenceResolution){
    neclass = new nec (cfg->NEC_NECFile);
    }
    // decimal/thousand separators used by number detection
    opt.set_nummerical_points (cfg->MACO_Decimal, cfg->MACO_Thousand);
    // Minimum probability for a tag for an unkown word
    opt.set_threshold (cfg->MACO_ProbabilityThreshold);
    // Whether the dictionary offers inverse acces (lemma#pos -> form). 
    // Only needed if your application is going to do such an access.
    opt.set_inverse_dict(false);
    // Whether contractions are splitted by the dictionary right away,
    // or left for later "retok" option to decide.
    opt.set_retok_contractions(cfg->MACO_RetokContractions);

    // Data files for morphological submodules. by default set to ""
    // Only files for active modules have to be specified 
    opt.set_data_files (cfg->MACO_UserMapFile,
                        cfg->MACO_LocutionsFile, cfg->MACO_QuantitiesFile,
                        cfg->MACO_AffixFile, cfg->MACO_ProbabilityFile,
                        cfg->MACO_DictionaryFile, cfg->MACO_NPDataFile,
                        cfg->MACO_PunctuationFile,cfg->MACO_CorrectorFile);

    // create analyzer with desired options
    morfo = new maco (opt);
  }


  // sense annotation requested/needed
  if (cfg->InputFormat < SENSES and cfg->OutputFormat >= MORFO and cfg->SENSE_WSD_which != NONE)
    sens = new senses(cfg->SENSE_ConfigFile);

  // sense disambiguation requested
  if ((cfg->InputFormat < SENSES and cfg->OutputFormat >= TAGGED
            and cfg->SENSE_WSD_which==UKB) or cfg->COREF_CoreferenceResolution)      
    dsb = new ukb(cfg->UKB_ConfigFile);

  // tagger requested, see which method
  if (cfg->InputFormat < TAGGED and cfg->OutputFormat >= TAGGED) {
    if (cfg->TAGGER_which == HMM)
      tagger =
        new hmm_tagger (cfg->TAGGER_HMMFile, cfg->TAGGER_Retokenize,
                        cfg->TAGGER_ForceSelect);
    else if (cfg->TAGGER_which == RELAX)
      tagger =
        new relax_tagger (cfg->TAGGER_RelaxFile, cfg->TAGGER_RelaxMaxIter,
                          cfg->TAGGER_RelaxScaleFactor,
                          cfg->TAGGER_RelaxEpsilon, cfg->TAGGER_Retokenize,
                          cfg->TAGGER_ForceSelect);
  }

  // phonetics requested
  if (cfg->PHON_Phonetics) {
    phon = new phonetics (cfg->PHON_PhoneticsFile);
  }
  
  // NEC requested
  if (cfg->InputFormat <= TAGGED and cfg->OutputFormat >= TAGGED and 
      (cfg->NEC_NEClassification or cfg->COREF_CoreferenceResolution)) {
    neclass = new nec (cfg->NEC_NECFile);
  }
  
  // Chunking requested
  if (cfg->InputFormat < SHALLOW and (cfg->OutputFormat >= SHALLOW or cfg->COREF_CoreferenceResolution)) {
    parser = new chart_parser (cfg->PARSER_GrammarFile);
  }

  // Dependency parsing requested
  if (cfg->InputFormat < SHALLOW and cfg->OutputFormat >= PARSED) 
    dep = new dep_txala (cfg->DEP_TxalaFile, parser->get_start_symbol ());

  if (cfg->COREF_CoreferenceResolution)
    corfc = new coref(cfg->COREF_CorefFile);
}


//---------------------------------------------
// Destroy analyzers 
//---------------------------------------------

analyzer::~analyzer() {

  // clean up. Note that deleting a null pointer is a safe operation
  delete iden;
  delete tk;
  delete sp;
  delete morfo;
  delete phon;
  delete tagger;
  delete neclass;
  delete sens;
  delete dsb;
  delete parser;
  delete dep;
  delete corfc;
}

//---------------------------------------------
// Apply analyzer cascade to sentences in given list
//---------------------------------------------

void analyzer::AnalyzeSentences(list<sentence> &ls) {

  if (cfg->InputFormat < MORFO && cfg->OutputFormat >= MORFO) {
    morfo->analyze (ls);
    if (cfg->OutputFormat == CRFMORF and cfg->NEC_NEClassification) {
      neclass->analyze (ls);
      return;
    }
  }
  if (cfg->OutputFormat >= MORFO and cfg->SENSE_WSD_which != NONE) 
    sens->analyze (ls);
  if (cfg->InputFormat < TAGGED && cfg->OutputFormat >= TAGGED) 
    tagger->analyze (ls);
  if (cfg->PHON_Phonetics) 
    phon->analyze (ls);
  if (cfg->OutputFormat >= TAGGED and (cfg->SENSE_WSD_which == UKB)) 
    dsb->analyze (ls);
  if (cfg->OutputFormat >= TAGGED and cfg->NEC_NEClassification) 
    neclass->analyze (ls);
  if (cfg->OutputFormat >= SHALLOW)
    parser->analyze (ls);
  if (cfg->OutputFormat >= PARSED)
    dep->analyze (ls);
}


//---------------------------------------------
void analyzer::TokenizeText(const wstring &text, list<word> &av) {
  tk->tokenize (text, offs, av);
}

//---------------------------------------------
void analyzer::SplitSentences(const std::list<word> &av, std::list<sentence> &ls, bool flush) {
  // split sentences into a list of sentences (ls)
  sp->split(av,flush,ls);
  // assign an id to each sentence.
  for (list<sentence>::iterator s=ls.begin(); s!=ls.end(); s++) {
    s->set_sentence_id(util::int2wstring(nsentence));
    nsentence++;
  }
}

//---------------------------------------------
void analyzer::SplitSentences(const std::list<word> &av, std::list<sentence> &ls) {
  SplitSentences(av,ls,cfg->AlwaysFlush);
}

//---------------------------------------------
void analyzer::AnalyzeTokens(const list<word> &av, list<sentence> &ls, bool flush) {
  SplitSentences (av,ls,flush);
  AnalyzeSentences(ls);
}

//---------------------------------------------
void analyzer::AnalyzeTokens(const list<word> &av, list<sentence> &ls) {
  AnalyzeTokens(av,ls,cfg->AlwaysFlush);
}

//---------------------------------------------
void analyzer::AnalyzeText(const wstring &text, list<sentence> &ls, bool flush) {
  list<word> av;
  tk->tokenize (text,offs,av);
  AnalyzeTokens(av,ls,flush);
}

//---------------------------------------------
void analyzer::AnalyzeText(const wstring &text, list<sentence> &ls) {
  AnalyzeText(text,ls,cfg->AlwaysFlush);
}

//---------------------------------------------
void analyzer::ResetOffset() {
  offs=0;
}

//---------------------------------------------
wstring analyzer::IdentifyLanguage(const wstring &text) {

  // list of languages to consider. (Empty -> all known languages)
  set<wstring> candidates=set<wstring>(); 

  // the funcion identify_language returns the code for the best language,
  // or "none" if no model yields a large enough probabilitiy
  return iden->identify_language (text, candidates);

  // Alternatively, we could obtain a sorted list with the probability 
  // for each language:
  //      vector<pair<double,wstring> > result;
  //      iden->rank_languages(result, text, candidates);  
} 
  

//---------------------------------------------
void analyzer::SolveCoreferences(document &doc) {
  
  // Analyze each document paragraph with all required analyzers
  for (document::iterator p=doc.begin(); p!=doc.end(); p++) {
    morfo->analyze(*p);
    tagger->analyze(*p);
    neclass->analyze(*p);
    dsb->analyze(*p);
    parser->analyze(*p);
  }
  
  // solve coreference
  corfc->analyze(doc);
  
  // if dependence analysis was requested, do it now (coref solver
  // only works on chunker output, not over complete trees)
  if (dep)
    for (document::iterator p=doc.begin(); p!=doc.end(); p++)
      dep->analyze(*p);  
}
