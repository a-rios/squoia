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

//------------------------------------------------------------------//
//  adapted analyzer_client.cc from FreeLing,
//  - DESR-SERVER-READY
//------------------------------------------------------------------//

#include <string>
#include <iostream>
#include <sstream>
#include "socket.h"

using namespace std;


//------------------------------------------
int main(int argc, char *argv[]) {

  if (argc < 2) {
    cerr<<"usage: "<<endl;
    cerr<<"   Connect to server in local host:   "<<string(argv[0])<<" port"<<endl;
    cerr<<"   Connect to server in remote host:  "<<string(argv[0])<<" host:port"<<endl;
    exit(0);
  }

  // extract host and port from argv[1]
  string p(argv[1]); 
  string host="localhost";
  int port;
  size_t i=p.find(":");
  if (i!=string::npos) {
    host = p.substr(0,i);
    p = p.substr(i+1);
  }
  istringstream ss(p);
  ss>>port;
  
  // connect to server  
  socket_CS sock(host,port);
  
  string s,r;

  // send a sync message to make sure the worker is initialized in the server side
  sock.write_message("RESET_STATS");

  // wait for server answer, so we know it is ready
  sock.read_message(r);
  if (r!="DESR-SERVER-READY") {
    cerr<<"Server not ready?"<<endl;
    exit(0);
  };

  // send lines to the server, and get answers
  while (getline(cin,s)) { 
    sock.write_message(s);

    sock.read_message(r);
    if (r!="DESR-SERVER-READY") cout<<r;
  }
  
  // input ended. Make sure to flush server's buffer
  sock.shutdown_connection(SHUT_WR);
  sock.read_message(r);
  if (r!="DESR-SERVER-READY") cout<<r;

  // terminate connection
  sock.close_connection();

  return 0;
}
