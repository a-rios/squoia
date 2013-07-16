/*
**  DeSR
**  src/desr.cpp
**  ----------------------------------------------------------------------
**  Copyright (c) 2005  Giuseppe Attardi (attardi@di.unipi.it).
**  ----------------------------------------------------------------------
**
**  This file is part of DeSR.
**
**  DeSR is free software; you can redistribute it and/or modify it
**  under the terms of the GNU General Public License, version 3,
**  as published by the Free Software Foundation.
**
**  DeSR is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program.  If not, see <http://www.gnu.org/licenses/>.
**  ----------------------------------------------------------------------
*/

//------------------------------------------------------------------//
//  adapted desr.cpp mixed with sample_analyzer.cc from FreeLing
//  - only "server mode"
//  - input and output format is conll
//  - only parse
//------------------------------------------------------------------//

// local
#include "Parser.h"
#include "EventStream.h"
#include "Corpus.h"
#include "WordCounts.h"
#include "version.h"

// IXE library
#include "Common/OptionStream.h"
#include "io/File.h"
#include "include/Timer.h"

// standard
#include <list>
#ifdef _WIN32
# include <io.h> // _setmode()
# include <fcntl.h>
#endif

// Semaphores and stuff to handle children count in server mode
#ifdef WIN32
  #define getpid() GetCurrentProcessId()
  #define pid_t DWORD
#else
  #include <sys/wait.h>
  #include <semaphore.h>
  sem_t semaf;
#endif

// freeling/morfo/util
#include "freeling/morfo/util.h"
// Default server parameters
#define DEFAULT_MAX_WORKERS 5   // maximum number of workers simultaneously active.
#define DEFAULT_QUEUE_SIZE 32   // maximum number of waiting clients

// client/server communication
#include "socket.h"
// server performance statistics
//#include "stats.h"

// Client/server socket
socket_CS *sock; 

using namespace Parser;
using namespace Tanl;
using namespace IXE;
using namespace std;
using namespace freeling;

namespace Parser {

// configuration parameters
char const*	configFileDefault = "desr.conf";

conf<string>	inputFormat("InputFormat", "CoNLL"); // CoNLL, CoNLL08, DgaXML
conf<string>	outputFormat("OutputFormat", "CoNLL"); // CoNLL, DGAXML
conf<int>	SentenceCutoff("SentenceCutoff", INT_MAX);

}

// command line options
Options::spec const commandOptions[] = {
  "help",	Options::no_arg,  'h', "-h, --help                  : Print this help message",
  "model",	Options::req_arg, 'm', "-m, --model modelFile       : Model file",
  "port",	Options::req_arg, 'P', "-P, --port portNumber       : Port number for the parsing server",
  "version",	Options::no_arg,  'v', "-v, --version               : Show the program version",
  0
};

ostream& usage(ostream& os = cerr)
{
  os << "Usage: desr_server -m modelFile --port portNumber" << endl;
  return Options::usage(commandOptions, os);
}

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
void InitServer(int portNumber) {

  pid_t myPID=getpid();
  char host[256];
  if (gethostname(host,256)!=0) 
    strcpy(host, "localhost"); 

  wcerr<<endl;
  wcerr<<L"Launched desr parser server "<<myPID<<L" at port "<<portNumber<<endl;
  wcerr<<endl;
  wcerr<<L"You can now parse text with the following command:"<<endl;
  wcerr<<L"  - From this computer: "<<endl;;
  wcerr<<L"      desr_client "<<portNumber<<L" <input.conll >output.conll"<<endl;
  wcerr<<L"      desr_client localhost:"<<portNumber<<L" <input.conll >output.conll"<<endl;
  wcerr<<L"  - From any other computer: "<<endl;
  wcerr<<L"      desr_client "<<util::string2wstring(host)<<L":"<<portNumber<<L" <input.conll >output.conll"<<endl;
  wcerr<<endl;
  wcerr<<L"Stop the server with: "<<endl;
  wcerr<<L"      kill -15 "<<myPID<<endl;
  wcerr<<endl;

  // open sockets to listen for clients
  sock = new socket_CS(portNumber,DEFAULT_QUEUE_SIZE);	// 32
  #ifndef WIN32
    // Capture terminating signals, to exit cleanly.
    signal(SIGTERM,terminate); 
    signal(SIGQUIT,terminate);   
    // Be signaled when children finish, to keep count of active workers.
    signal(SIGCHLD,child_ended); 
    // Init worker count sempahore
    sem_init(&semaf,0,DEFAULT_MAX_WORKERS);	// 5
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
  sock->write_message("DESR-SERVER-READY");  
}

//---- Read a line from input channel
bool CheckStatsCommands(const string &text) {
  bool b=false;
  if (text=="RESET_STATS") { 
    SendACK();
    b=true;
  }
  else if (text=="PRINT_STATS") {
    sock->write_message("print stats...");
    b=true;
  }
  return b;
}

bool CheckWStatsCommands(const wstring &text) {
  bool b=false;
  if (text==L"RESET_STATS") { 
    SendACK();
    b=true;
  }
  else if (text==L"PRINT_STATS") {
    sock->write_message("print stats...");
    b=true;
  }
  return b;
}

//---- Clean up and end worker when client finishes.
void CloseWorker() {
  wcerr<<L"SERVER.WORKER: client ended. Closing connection."<<endl;
  sock->close_connection();
  exit(0);
}

/////// Functions to wrap I/O mode (server socket vs stdin/stdout) ////////

//---- Read a line from input channel
int ReadLine(string &text) {
	int n=0;
	n = sock->read_message(text);
	return n;
}

int ReadWLine(wstring &text) {
	int n=0;
	string s;
	n = sock->read_message(s);
	text = util::string2wstring(s);
	return n;
}

//---- Output a string to output channel
void OutputString(const string &s) {
	sock->write_message(s);
}
void OutputWString(const wstring &s) {
	sock->write_message(util::wstring2string(s));
}
//---- Output analysis result to output channel
//void OutputSentences(output &out, list<sentence> &ls, analyzer &anlz, const document &doc=document()) {
//    if (ls.empty()) {
//      SendACK();
//      return;
//    }
    
//    wostringstream sout;
//    out.PrintResults(sout,ls,anlz,doc);
    //PrintMorfo(sout,ls,anlz);
//    sock->write_message(util::wstring2string(sout.str()));
//}

/// ======================================================================

// overwrite parameters from command line options
char const* language = 0;
char const* configFile = configFileDefault;
bool RightToLeft = false;

/// ======================================================================

int main(int argc, char* argv[])
{
  string modelFile;
  int portNumber = -1;

  ParserConfig config;

  // process options
  OptionStream options(argc, argv, commandOptions);
  for (OptionStream::Option opt; options >> opt;) {
    switch (opt) {
    case 'h':
      usage();
      return -1;
    case 'm':
      modelFile = opt.arg();
      break;
    case 'P':
      portNumber = atoi(opt.arg());
      break;
    case 'v':
      cerr << "DeSR (server alpha.04) version: " << version << endl;
      break;
    }
  }
  argc -= options.shift(), argv += options.shift();

  // determine parser input
  istream* is = 0;

  switch (argc) {
  case 0:
    is = &cin;
    break;
  default:
    cerr << usage;		// no ()
    return -1;
  }

  if (modelFile.empty() or portNumber == -1) {
    cerr << "Model file and port number are required" << endl;
    cerr << usage;
    return -2;
  }

  // First, parse the config. file (if any); then override variables
  // with options specified on the command line.
  //
  if (IXE::io::File(configFile).exists())
    config.load(configFile);
  else if (configFile != configFileDefault) {
    cerr << "Missing config file: " << configFile << endl;
    return -2;
  }

  // in parse mode certain parameters are fixed and stored in the modelFile
    // read parameters from modelFile
    ifstream ifs(modelFile.c_str());
    if (!ifs) {
      cerr << "Missing model file: " << modelFile << endl;
      return -3;
    }
    config.load(ifs);

  Language const* language = Language::get(config.lang->c_str());
  if (language == 0) {
    cerr << "Unknown language: " << *config.lang << endl;
    return -4;
  }
  // Create the Corpus for the requested inputFormat and its
  // associated SentenceReader.
  Corpus* corpus = Corpus::create(*language, inputFormat);
  if (corpus == 0) {
    cerr << "Unknown format: " << *inputFormat << endl;
    return -1;
  }
  Corpus* outCorpus = Corpus::create(*language, outputFormat);
  if (outCorpus == 0) {
    cerr << "Unknown format: " << *outputFormat << endl;
    return -1;
  }

  InitServer(portNumber);
  try {
	::Parser::Parser* parser = ::Parser::Parser::create(modelFile.c_str());
	if (parser) {
		bool stop=false;    /// The server version will never stop. 
		while (not stop) {  /// The standalone version will stop after one iteration.

			// --- Begin text analysis
			unsigned long offs=0;
			string text;
//list<word> av;  sentence sent;
//			list<sentence> ls;

			int n=WaitClient(); // Wait for a client and fork a worker to attend it.
			if (n!=0) continue; // If we are the dispatcher, go to wait for a new client.
			// main loop to parse the lines
			ostringstream sout;
			while (ReadLine(text)) {
		   
				// if we get a stats-related command, process it and wait for next line
				if (CheckStatsCommands(text)) continue;
		
	    			sout << text << "\n";
				SendACK();
			} // --- end while(readline)
			istringstream myinput;
			ostringstream myoutput;
			myinput.str(sout.str());
			is = &myinput;
			SentenceReader* sentenceReader = corpus->sentenceReader(is);
			parser->parse(sentenceReader, outCorpus, myoutput);
			OutputString(myoutput.str());

			// if we are a forked server attending a client, and the client is done, we exit.
			CloseWorker();
		}
		delete parser;
	}
  } catch (IXE::Error& e) {
    cerr << "Error: " << e.message() << endl;
  } catch (exception& e) {
    cerr << "Error: " << e.what() << endl;
  }
  delete corpus;
  delete outCorpus;
}
