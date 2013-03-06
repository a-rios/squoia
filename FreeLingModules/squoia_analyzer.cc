/* start with:
 * squoia_analyzer -f path-to-freeling.conf --outf=desrtag --server --port=PORTNUMBER 2>logdesrtag &
 * 
 * analyse with anaylzer_client from FreeLing:
 * echo "Vuestro servidor ya funciona con el nuevo formato de salida" | analyzer_client PORTNUMBER
 * or
 * analyzer_client PORTNUMBER < text.tok > text.conll
 */

//------------------------------------------------------------------//
//  adapted sample_analyzer.cc from FreeLing,
// NOTE: FreeLing 3.0 must be installed on your system to use this!
//  - output format is conll
//  some changes:
//  - proper nouns get pos=nc (common noun)
//  -> easier for parser, but morph column 
//    contains np=typeOfNp, so the original tag can 
//    later be restored
//  - numeral determiners: dn (FreeLing: Z)
// IMPORTANT: input text should be one sentence per line
//------------------------------------------------------------------//

#include <sstream>
#include <iostream> 

#include <map>
#include <list>
#include <boost/algorithm/string.hpp>

/// headers to call freeling library
#include "analyzer.h"
/// config file/options handler for this particular sample application
#include "config.h"
/// functions to print results depending on configuration options
#include "output.h"

// Semaphores and stuff to handle children count in server mode
#ifdef WIN32
  #define getpid() GetCurrentProcessId()
  #define pid_t DWORD
#else
  #include <sys/wait.h>
  #include <semaphore.h>
  sem_t semaf;
#endif

// client/server communication
#include "socket.h"
// server performance statistics
#include "stats.h"

// Client/server socket
socket_CS *sock; 
bool ServerMode; 

using namespace std;


//////// Auxiliary functions for server mode  //////////

#ifndef WIN32
//---- Capture signal informing that a child ended ---
void child_ended(int n) {
  int status;
  wait(&status);  
  sem_post(&semaf);
}

//----  Capture signal to shut server down cleanly
void terminate (int param) {
  wcerr<<L"SERVER.DISPATCHER: Signal received. Stopping"<<endl;
  exit(0);
}
#endif

//----  Initialize server socket, signals, etc.
void InitServer(config *cfg) {

  pid_t myPID=getpid();
  char host[256];
  if (gethostname(host,256)!=0) 
    strcpy(host, "localhost"); 

  wcerr<<endl;
  wcerr<<L"Launched squoia analyzer server "<<myPID<<L" at port "<<cfg->Port<<endl;
  wcerr<<endl;
  wcerr<<L"You can now analyze text with the following command:"<<endl;
  wcerr<<L"  - From this computer: "<<endl;;
  wcerr<<L"      analyzer_client "<<cfg->Port<<L" <input.txt >output.txt"<<endl;
  wcerr<<L"      analyzer_client localhost:"<<cfg->Port<<L" <input.txt >output.txt"<<endl;
  wcerr<<L"  - From any other computer: "<<endl;
  wcerr<<L"      analyzer_client "<<util::string2wstring(host)<<L":"<<cfg->Port<<L" <input.txt >output.txt"<<endl;
  wcerr<<endl;
  wcerr<<L"Stop the server with: "<<endl;
  wcerr<<L"      kill -15 "<<myPID<<endl;
  wcerr<<endl;

  // open sockets to listen for clients
  sock = new socket_CS(cfg->Port,cfg->QueueSize);
  #ifndef WIN32
    // Capture terminating signals, to exit cleanly.
    signal(SIGTERM,terminate); 
    signal(SIGQUIT,terminate);   
    // Be signaled when children finish, to keep count of active workers.
    signal(SIGCHLD,child_ended); 
    // Init worker count sempahore
    sem_init(&semaf,0,cfg->MaxWorkers);
  #endif
}

//----  Wait for a client and fork a worker to attend its requests
int WaitClient() {
  int pid=0;
  #ifndef WIN32
    wcerr<<L"SERVER.DISPATCHER: Waiting for a free worker slot"<<endl;
    sem_wait(&semaf);
  #endif
  wcerr<<L"SERVER.DISPATCHER: Waiting connections"<<endl;
  sock->wait_client();
  
  // If we are a Linux server, fork a worker.
  // On windows, only serve one client at a time.
  #ifndef WIN32
    pid = fork();
    if (pid < 0) wcerr<<L"ERROR on fork"<<endl;
    
    if (pid!=0) {
      // we are the parent. Close client socket and wait for next client
      sock->set_parent();
      wcerr<<L"SERVER.DISPATCHER: Connection established. Forked worker "<<pid<<"."<<endl;
    }
    else { 
      // we are the child. Close request socket and prepare to get data from client.
      sock->set_child();
    }
  #endif

  return pid;
}

//----  Send ACK to the client, informing that we expect more 
//----  data to be able to send back an analysis.
void SendACK () {  
  sock->write_message("FL-SERVER-READY");  
}

//---- Read a line from input channel
bool CheckStatsCommands(const wstring &text, ServerStats *stats) {
  bool b=false;
  if (text==L"RESET_STATS") { 
    stats->ResetStats();
    SendACK();
    b=true;
  }
  else if (text==L"PRINT_STATS") {
    sock->write_message(util::wstring2string(stats->GetStats()));
    b=true;
  }
  return b;
}

//---- Clean up and end worker when client finishes.
void CloseWorker(ServerStats *stats) {
  wcerr<<L"SERVER.WORKER: client ended. Closing connection."<<endl;
  delete stats;
  sock->close_connection();
  exit(0);
}

/////// Functions to wrap I/O mode (server socket vs stdin/stdout) ////////

//---- Read a line from input channel
int ReadLine(wstring &text) {
  int n=0;
  if (ServerMode) {
    string s;
    n = sock->read_message(s);
    text = util::string2wstring(s);
  }
  else 
    if (getline(wcin,text)) n=1;

  return n;
}

//---- Output a string to output channel
void OutputString(const wstring &s) {
  if (ServerMode) 
    sock->write_message(util::wstring2string(s));
  else 
    wcout<<s;
}

//---- Output a list of tokens to output channel
void OutputTokens(const list<word> &av) {
 list<word>::const_iterator w;
 for (w=av.begin(); w!=av.end(); w++) 
   OutputString(w->get_form()+L"\n");
}

//---- Output analysis result to output channel
void OutputSentences(output &out, list<sentence> &ls, analyzer &anlz, const document &doc=document()) {
  if (ServerMode) {
    if (ls.empty()) {
      SendACK();
      return;
    }
    
    wostringstream sout;
    out.PrintResults(sout,ls,anlz,doc);
    //PrintMorfo(sout,ls,anlz);
    sock->write_message(util::wstring2string(sout.str()));
  }
  else 
    out.PrintResults(wcout,ls,anlz,doc);
}

//---- Process input line when coreference resolution is requusted
void ProcessLineCoref(analyzer &anlz, const wstring &text, list<word> &av,
                      list<sentence> &ls,
                      paragraph &par, document &doc) {
  if (text==L"") { // new paragraph.
    // flush buffer
    anlz.SplitSentences(av,ls,true);
    // add sentences to current paragraph
    par.insert(par.end(), ls.begin(), ls.end());  
    // Add paragraph to document
    if (not par.empty()) doc.push_back(par);  
    // prepare for next paragraph
    av.clear(); ls.clear(); par.clear(); 
  }
  else {
    // tokenize input line
    anlz.TokenizeText(text,av);
    // accumulate list of words in splitter buffer, returning a list of sentences.
    anlz.SplitSentences(av,ls,false);

    // add sentences to current paragraph
    par.insert(par.end(), ls.begin(), ls.end());
    
    // clear temporary lists;
    av.clear(); ls.clear();
  }
}

//---- Once document is finished, flush buffers and solve correferences
void PostProcessCoreference(analyzer &anlz, output &out, const list<word> &av, list<sentence> &ls,
                            paragraph &par, document &doc, ServerStats *stats) {

  // flush splitter buffer  
  anlz.SplitSentences(av,ls,true);
  // add sentences to paragraph
  par.insert(par.end(), ls.begin(), ls.end());
  // add paragraph to document.
  doc.push_back(par);
  
  // All document read, solve correferences.
  anlz.SolveCoreferences(doc);
  
  // output results in requested format 
  for (document::iterator par=doc.begin(); par!=doc.end(); par++) {
    OutputSentences(out,*par,anlz,doc); 
    if (ServerMode) stats->UpdateStats(ls);
  }
}

//---- Proces an input line when InputFormat=TOKEN
void ProcessLineToken(analyzer &anlz, const wstring &text, unsigned long &totlen, list<word> &av, list<sentence> &ls) {

  // get next word
  word w (text);
  w.set_span (totlen, totlen + text.size ());
  totlen += text.size () + 1;
  av.push_back (w);

  // check for splitting after some words have been accumulated, 
  if (av.size () > 10) {  
    anlz.AnalyzeTokens(av,ls,false);    
    av.clear ();      // clear list of words for next use
  }
}

//---- Proces an input line when InputFormat>=SPLITTED
void ProcessLineSplitted(analyzer &anlz, config *cfg, const wstring &text, unsigned long &totlen, sentence &av, list<sentence> &ls) {
  wstring form, lemma, tag, sn, spr;
  double prob;

  if (text != L"") {  // got a word line
    wistringstream sin;
    sin.str (text);
    // get word form
    sin >> form;
    
    // build new word
    word w (form);
    w.set_span (totlen, totlen + form.size ());
    totlen += text.size () + 1;
    
    // process word line, according to input format.
    // add all analysis in line to the word.
    w.clear ();
    if (cfg->InputFormat == MORFO) {
      while (sin >> lemma >> tag >> spr) {
        analysis an (lemma, tag);
        prob = util::wstring2double (spr);     
        an.set_prob (prob);
        w.add_analysis (an);
      }
    }
    else if (cfg->InputFormat == SENSES) {
      while (sin >> lemma >> tag >> spr >> sn) {
        analysis an (lemma, tag);
        prob = util::wstring2double (spr);
        an.set_prob (prob);
        list<wstring> lpair=util::wstring2list (sn,L"/");
        list<pair<wstring,double> > lsen;
        for (list<wstring>::iterator i=lpair.begin(); i!=lpair.end(); i++) {
          size_t p=i->find(L":");
          lsen.push_back(make_pair(i->substr(0,p),util::wstring2double(i->substr(p))));
        }
        an.set_senses(lsen);
        w.add_analysis (an);
      }
    }
    else if (cfg->InputFormat == TAGGED) {
      sin >> lemma >> tag;
      analysis an (lemma, tag);
      an.set_prob (1.0);
      w.add_analysis (an);
    }
    
    // append new word to sentence
    av.push_back (w);
    // no complete sentences so far.
    ls.clear();
  }
  else { // blank line, sentence end.
    totlen += 2;
    ls.push_back(av);
    anlz.AnalyzeSentences(ls);      
    
    av.clear ();   // clear list of words for next use
  }
}  


void FlushBuffers(analyzer &anlz, config *cfg, const list<word> &av,
                  sentence &sent, list<sentence> &ls, output &out, ServerStats *stats) {

  if (ServerMode) wcerr << L"SERVER.WORKER: client ended. Flushing buffers." <<endl;
  if (cfg->InputFormat == PLAIN or cfg->InputFormat == TOKEN) {
    // flush splitter buffer
    if (cfg->OutputFormat == TOKEN) {
      OutputTokens(av);
    }
    else if (cfg->OutputFormat >= SPLITTED) {
      anlz.AnalyzeTokens(av,ls,true);
      OutputSentences(out,ls,anlz);
    }
  }
  else { // cfg->InputFormat >= SPLITTED.
    if (!sent.empty()) {
      // if a blank line after last sentence was missing, the sentence is 
      // still in the splitter buffer.
      ls.push_back(sent);
      anlz.AnalyzeSentences(ls);
      OutputSentences(out,ls,anlz);
      if (ServerMode) stats->UpdateStats(ls);    
    }
  }
}
  
//---------------------------------------------
// Main program
//---------------------------------------------

int main (int argc, char **argv) {
   
  // read configuration file and command-line options, 
  // and create appropriate analyzers
  config *cfg = new config(argc,argv);
  ServerMode = cfg->Server;

  // If server activated, make sure port was specified, and viceversa.
  if (ServerMode and cfg->Port==0) {
    wcerr <<L"Error - Server mode requires the use of option '--port' to specify a port number."<<endl;
    exit (1);    
  }
  else if (not ServerMode and cfg->Port>0) {
    wcerr <<L"Error - Ignoring unexpected server port number. Use '--server' option to activate server mode."<<endl;
    cfg->Port=0;
  }
  
  output out(cfg);
  analyzer anlz(cfg);
  cfg->MACO_DatesDetection = false;
  cfg->MACO_QuantitiesDetection = false;
  analyzer anlz2(cfg);

  if (ServerMode) {
    wcerr<<L"SERVER: Squoia analyzers loaded."<<endl;
    InitServer(cfg);
  }
  ServerStats *stats=NULL;

  bool stop=false;    /// The server version will never stop. 
  while (not stop) {  /// The standalone version will stop after one iteration.

    if (ServerMode) {
      int n=WaitClient(); // Wait for a client and fork a worker to attend it.
      if (n!=0) continue; // If we are the dispatcher, go to wait for a new client.

      stats = new ServerStats();  // If we are the worker, get ready.
    }

    // --- Begin text analysis
    unsigned long offs=0;
    wstring text; list<word> av;  sentence sent;
    list<sentence> ls; paragraph par;  document doc;

    // if language identification requested, do not enter analysis loop, 
    // just identify language for each line.
    if (cfg->OutputFormat == IDENT) {
      while (ReadLine(text)) {
        // call the analyzer to identify language
        OutputString (anlz.IdentifyLanguage(text)+L"\n");
      }
    }

    else {
      // --- Main loop: read and process all input lines up to EOF ---
      while (ReadLine(text)) {
   
        // if we get a stats-related command, process it and wait for next line
        if (ServerMode and CheckStatsCommands(text,stats)) continue;

        // coreference requested, assume plain text input, and accumulate 
        // sentences and paragrafs until the document is complete
        if (cfg->COREF_CoreferenceResolution) {
          ProcessLineCoref(anlz,text,av,ls,par,doc);
          if (ServerMode) SendACK();            
        }

        // No coreferences required
        else {
          bool outputrequired=false;

          switch (cfg->InputFormat) {
            case PLAIN: // input is plain text
              if (cfg->OutputFormat == TOKEN) { 
                // only tokenized output is requested
                anlz.TokenizeText(text,av);
                OutputTokens(av);
              }
              else {
                //  splitter (and maybe more) requested
                anlz.AnalyzeText(text,ls);
                outputrequired = true;
              }
              break;
              
            case TOKEN:  // Input is tokenized.
              ProcessLineToken(anlz,text,offs,av,ls);
              outputrequired = true;
              break; 

            default:  // Input is (at least) tokenized and splitted.
              ProcessLineSplitted(anlz,cfg,text,offs,sent,ls);  
              outputrequired = true;
              break;
          }
        
          // Output results if needed.
          if (outputrequired) {
            if (not ls.empty()) {
              OutputSentences(out,ls, anlz2);
              if (ServerMode) stats->UpdateStats(ls); 
            }
            else 
              if (ServerMode) SendACK();            
          }
        }
      } // --- end while(readline)
    
      // Document has been read. Perform appropriate post-processing
      if (cfg->COREF_CoreferenceResolution)
        // If we wanted coreference, now it's time, since we have the whole document.
        PostProcessCoreference(anlz,out,av,ls,par,doc,stats);
      else
        // no coreferences, just flush buffers and process remaining sentences
        FlushBuffers(anlz,cfg,av,sent,ls,out,stats);
    }
    
    // if we are a forked server attending a client, and the client is done, we exit.
    if (ServerMode) CloseWorker(stats);
    // if not server version, stop when document is processed
    else stop=true;   
  }
  
  // clean up and exit
  delete cfg;
}

