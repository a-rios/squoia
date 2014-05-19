//gcc -o flookup_tcpServer flookup_tcpServer.c /usr/local/lib/libfoma.a -lz

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <time.h> 
#include <limits.h>

#include <getopt.h>
#include "fomalib.h"

#define LINE_LIMIT 262144
#define FLOOKUP_PORT 8888

#define DIR_DOWN 0
#define DIR_UP 1

char *usagestring = "Usage: flookup_server [-P port number] <binary foma file>)\n";
char *helpstring = "starts flookup as tcp server on localhost"
"Use with flookup_client to apply up/down words from stdin:\n"
"Options:\n"
"-h\t\tprint this help\n"
"-a\t\ttry alternatives (in order of nets loaded, default is to pass words through each)\n"
"-i\t\tinverse application (apply down instead of up)\n"
"-P\t\tspecify port of server (default 8888)\n";

struct lookup_chain {
    struct fsm *net;
    struct apply_handle *ah;
    struct lookup_chain *next;
    struct lookup_chain *prev;
};
    
    static struct fsm *net;
    static fsm_read_binary_handle fsrh;
    static struct lookup_chain *chain_head, *chain_tail, *chain_new, *chain_pos;
    static int  numnets = 0, echo = 1, apply_alternates = 1, index_flag_states = 0, index_cutoff = 0, index_mem_limit = INT_MAX , index_arcs = 0, direction = DIR_UP, results, port_number = FLOOKUP_PORT;
    //static char  *server_address = NULL, *line, *serverstring = NULL;
    struct sockaddr_in serv_addr; 
    
    static FILE *INFILE;
    static struct lookup_chain *chain_head, *chain_tail, *chain_new, *chain_pos;

    static char *(*applyer)() = &apply_up;  /* Default apply direction = up */ 

    static char *handle_line(char *line);
    static char *get_next_line();
    char* concat_outstr(char *s1, char *s2);
    char* concat_3(char *s1, char *s2, char *s3);
    char* concat(char *s1, char *s2);

    
    char *result, *separator = "\t";
//    static char *line;
  //  static void server_init();
    

int main(int argc, char *argv[])
{
  
    int opt = 1, sortarcs = 1;
    char *chainname;
    struct fsm *net;
    INFILE = stdin;

    while ((opt = getopt(argc, argv, "ahiP:")) != -1) {
        switch(opt) {
        case 'a':
	    apply_alternates = 1;
	    break;
	case 'i':
	    direction = DIR_DOWN;
	    applyer = &apply_down;
	    break;
	case 'h':
	    printf("%s%s\n", usagestring,helpstring);
            exit(0);
	case 'P':
	    port_number = atoi(optarg);
	    break;
	default:
            fprintf(stderr, "%s", usagestring);
            exit(EXIT_FAILURE);
    }}
    
    /* get chain binary  */
    chainname = argv[optind];
    if ((fsrh = fsm_read_binary_file_multiple_init(chainname)) == NULL) {
        fprintf(stderr, "%s: %s\n%sprint -h for help\n", "File error", chainname, usagestring);
	exit(EXIT_FAILURE);
    }
    
    chain_head = chain_tail = NULL;

    while ((net = fsm_read_binary_file_multiple(fsrh)) != NULL) {
	numnets++;
	chain_new = xxmalloc(sizeof(struct lookup_chain));
	if (direction == DIR_DOWN && net->arcs_sorted_in != 1 && sortarcs) {
	    fsm_sort_arcs(net, 1);
	}
	if (direction == DIR_UP && net->arcs_sorted_out != 1 && sortarcs) {
	    fsm_sort_arcs(net, 2);
	}
	chain_new->net = net;
	chain_new->ah = apply_init(net);
	if (direction == DIR_DOWN && index_arcs) {
	    apply_index(chain_new->ah, APPLY_INDEX_INPUT, index_cutoff, index_mem_limit, index_flag_states);
	}
	if (direction == DIR_UP && index_arcs) {
	    apply_index(chain_new->ah, APPLY_INDEX_OUTPUT, index_cutoff, index_mem_limit, index_flag_states);
	}

	chain_new->next = NULL;
	chain_new->prev = NULL;
	if (chain_tail == NULL) {
	    chain_tail = chain_head = chain_new;
	} else if (direction == DIR_DOWN || apply_alternates == 1) {
	    chain_tail->next = chain_new;
	    chain_new->prev = chain_tail;
	    chain_tail = chain_new;
	} else {
	    chain_new->next = chain_head;
	    chain_head->prev = chain_new;
	    chain_head = chain_new;
	}
    }
    if (numnets < 1) {
	fprintf(stderr, "%s: %s\nprint -h for help\n", "File error", chainname);
	exit(EXIT_FAILURE);
    }
 
   
    
    //########################################//
    int listenfd = 0, connfd = 0;
    int  byte_count;
    char sendBuff[1025];
 

    listenfd = socket(AF_INET, SOCK_STREAM, 0);
    memset(&serv_addr, '0', sizeof(serv_addr));
    memset(sendBuff, '0', sizeof(sendBuff)); 

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    serv_addr.sin_port = htons(port_number); 

   // bind(listenfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
    /* Now bind the host address using bind() call.*/
    if (bind(listenfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) < 0)
    {
         perror("ERROR on binding");
         exit(1);
    }
    else{
        printf("started server on port %d\n", port_number);
    }

    listen(listenfd, 10); 

     while(1)
     {
        connfd = accept(listenfd, (struct sockaddr*)NULL, NULL); 
    
	
	// fork child
	int pid = fork();
	if (pid < 0){
            perror("ERROR could not fork");
	    exit(1);
        }
        if (pid == 0)  
        {
	  /* This is the client process */
            close(listenfd);
            do {
	      byte_count = recv(connfd, sendBuff, 1024,0);
	      if (byte_count < 0){
		  perror("ERROR reading from socket");
		  exit(1);
	      }
		sendBuff[byte_count] = '\0';
		//fprintf(stderr,"string received:\t%s\n", sendBuff);    
		char *line = concat(sendBuff,"");
		//handle_line(line, connfd);;
		char *outstr = handle_line(line);
		// printf("sent outstring: %s", outstr);
		write(connfd, outstr, strlen(outstr));
	    } while(byte_count > 0);
            exit(0);
        }
        else
        {
            close(connfd);
        }

      }

        close(connfd);
        sleep(1);
}
char *handle_line(char *s) {
    char *result, *tempstr, *outstr;
    char *line = concat(s,"");
    
    /* make sure string is not empty */
    if(line[0] != '\0')
    {
	/* apply chain.bin (normalizer) */
	if (apply_alternates == 1) {
	// printf("apply_alternates is true, line is %s\n",  line);
	  for (chain_pos = chain_head, tempstr = s;   ; chain_pos = chain_pos->next) {
	      result = applyer(chain_pos->ah, tempstr);
	      if (result != NULL) {
		  results++;
		  //printf("%s:\n \t%s\n", line, result);
		  outstr = concat_outstr(line, result);
		  outstr = concat(outstr, "\n");
		  // write(connfd, outstr, strlen(outstr));
		  while ((result = applyer(chain_pos->ah, NULL)) != NULL) {
			  results++;
			//printf("%s:\n \t%s\n", line, result);
			   char *outstr1 = concat_outstr(line, result);
			   outstr = concat_3(outstr, outstr1, "\n");
		      }
		      break;
		  }
		  if (chain_pos == chain_tail) {
		      break;
		  }
	      }
	    } 
	    else {    
	      /* Get result from chain */
	      for (chain_pos = chain_head, tempstr = s;  ; chain_pos = chain_pos->next) {		
		  result = applyer(chain_pos->ah, tempstr);		
		  if (result != NULL && chain_pos != chain_tail) {
		      tempstr = result;
		      continue;
		  }
		  if (result != NULL && chain_pos == chain_tail) {
		      do {
			  results++;
			 // printf("%s:\n \t%s\n", line, result);
			  char *outstr2 = concat_outstr(line, result);
			  outstr = concat(outstr, outstr2);
		      } while ((result = applyer(chain_pos->ah, NULL)) != NULL);
		  }
		  if (result == NULL) {
		      /* Move up */
		      for (chain_pos = chain_pos->prev; chain_pos != NULL; chain_pos = chain_pos->prev) {
			  result = applyer(chain_pos->ah, NULL);
			  if (result != NULL) {
			      tempstr = result;
			      break;
			  }
		      }
		  }
		  if (chain_pos == NULL) {
		      break;
		  }
	      }
	  }
	}
    return outstr;
}

char* concat_outstr(char *s1, char *s3)
{
    char *s2 = "\t";
    size_t len1 = strlen(s1);
    size_t len2 = strlen(s2);
    size_t len3 = strlen(s3);
    char *result = malloc(len1+len2+len3+1);//+1 for the zero-terminator
    memcpy(result, s1, len1);
    memcpy(result+len1, s2, len2);//+1 to copy the null-terminator
     memcpy(result+len1+len2, s3, len3+1);
    return result;
}


char* concat_3(char *s1, char *s2,char *s3)
{

    size_t len1 = strlen(s1);
    size_t len2 = strlen(s2);
    size_t len3 = strlen(s3);
    char *result = malloc(len1+len2+len3+1);//+1 for the zero-terminator
    memcpy(result, s1, len1);
    memcpy(result+len1, s2, len2);//+1 to copy the null-terminator
    memcpy(result+len1+len2, s3, len3+1);
    return result;
}

char* concat(char *s1, char *s2)
{
  
    size_t len1 = strlen(s1);
    size_t len2 = strlen(s2);
    char *result = malloc(len1+len2+1);//+1 for the zero-terminator
    memcpy(result, s1, len1);
    memcpy(result+len1, s2, len2+1);//+1 to copy the null-terminator
    return result;
}




