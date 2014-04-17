/*                             */


#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
#include <getopt.h>
#include "fomalib.h"
#include <sys/socket.h>

#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>


#define LINE_LIMIT 262144
#define FLOOKUP_PORT 8888
#define DIR_UP 1
#define UDP_MAX 65535

//TODO
char *usagestring = "Usage: spellcheck [-l med_limit] [-c cutoff] -1 <analyzer.bin> <chain.bin> <spellcheckUnificado.bin>\n";
char *helpstring = "Applies spell checking to words from stdin to foma finite state tranducers read from 3 files:\n"
"\t<analyzer.bin> :\t\tstrict analyzer that decides whether a word needs spell checking or not\n"
"\t<chain.bin> :\t\t\tchain of normalizers that will to correct typical misspelings (e.g. '-nqui' -> '-nki', 'hua' -> 'wa')\n"
"\t<spellcheckUnificado.bin> :\tactual spell checker that suggests similar words based on minimum edit distance\nOptions:\n"
"-h\t\tprint help\n"
"-l med_limit\tset maximum number of suggestions (default is 5)\n"
"-c cutoff\tset maximum levenshtein distance for suggestions (default is 15)\n"
"-A\t\t  specify address of server\n"
"-P\t\t  specify port of server (default 8888)\n";

struct lookup_chain {
    struct fsm *net;
    struct apply_handle *ah;
    struct lookup_chain *next;
    struct lookup_chain *prev;
};

    static struct sockaddr_in serveraddr, clientaddr;
    static int                listen_sd, numbytes;
    static socklen_t          addrlen;

    static struct fsm *analyzernet;
    static struct apply_handle *ah;
    
    static struct fsm *net;
    static fsm_read_binary_handle fsrh;
    static struct lookup_chain *chain_head, *chain_tail, *chain_new, *chain_pos;
    static int  numnets = 0, echo = 1, apply_alternates = 1, index_flag_states = 0, index_cutoff = 0, index_mem_limit = INT_MAX , index_arcs = 0, direction = DIR_UP, buffered_output = 1, results, port_number = FLOOKUP_PORT, udpsize;
    static char  *server_address = NULL, *line, *serverstring = NULL;
    
    static struct fsm *mednet;
    static struct apply_med_handle *medh;
    
    static FILE *INFILE;

    static char *(*applyer)() = &apply_up;  /* Default apply direction = up */ 
    static void handle_line(char *s);
   // static char *get_next_line();
    char *result, *separator = "\t";
  //  static char *line;
    static void server_init();


int main(int argc, char *argv[]) {
    int opt = 1, sortarcs = 1;
    char *chainname, *analyzername, *medname;
    struct fsm *net;
    INFILE = stdin;
    
    extern g_med_limit;
    extern g_med_cutoff;

    while ((opt = getopt(argc, argv, "l:c:A:P:h")) != -1) {
        switch(opt) {
        case 'l':
	   if(atoi(optarg) == 0)
	    {
	     printf("Maximum number of suggestions can not be zero! Using default value (5).\n");
	     //because med search won't terminate with g_med_limit = 0*/
	      break;
	    }
	   else
	   {
	    g_med_limit = atoi(optarg);
	    break;
	   }
        case 'c':
	   g_med_cutoff = atoi(optarg);
	  break;
	case 'h':
	    printf("%s%s\n", usagestring,helpstring);
            exit(0);
	case 'A':
	    server_address = strdup(optarg);
	    break;
	case 'P':
	    port_number = atoi(optarg);
	    break;
	default:
            fprintf(stderr, "%s", usagestring);
            exit(EXIT_FAILURE);
    }}
    
    /* get analyzer binary  */
    analyzername = argv[optind];
    analyzernet = fsm_read_binary_file(analyzername);
    if (analyzernet == NULL) {
	fprintf(stderr, "%s: %s\n", "File error", analyzername);
	exit(EXIT_FAILURE);
    }
    ah = apply_init(analyzernet);
    
    /* get chain binary  */
    chainname = argv[optind+1];
    if ((fsrh = fsm_read_binary_file_multiple_init(chainname)) == NULL) {
        perror("File error");
	exit(EXIT_FAILURE);
    }
    
    chain_head = chain_tail = NULL;

    while ((net = fsm_read_binary_file_multiple(fsrh)) != NULL) {
	numnets++;
	chain_new = xxmalloc(sizeof(struct lookup_chain));	
	if (direction == DIR_UP && net->arcs_sorted_out != 1 && sortarcs) {
	    fsm_sort_arcs(net, 2);
	}
	chain_new->net = net;
	chain_new->ah = apply_init(net);

	if (direction == DIR_UP && index_arcs) {
	    apply_index(chain_new->ah, APPLY_INDEX_OUTPUT, index_cutoff, index_mem_limit, index_flag_states);
	}

	chain_new->next = NULL;
	chain_new->prev = NULL;
	if (chain_tail == NULL) {
	    chain_tail = chain_head = chain_new;
	} else if ( apply_alternates == 1) {
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
	fprintf(stderr, "%s: %s\n", "File error", chainname);
	exit(EXIT_FAILURE);
    }
 
    /* get spellchecker binary (last argument) */
    medname = argv[optind+2];
    mednet = fsm_read_binary_file(medname);
    if (mednet == NULL) {
	fprintf(stderr, "%s: %s\n", "File error", medname);
	exit(EXIT_FAILURE);
    }
    medh = apply_med_init(mednet);
    apply_med_set_heap_max(medh,4194304+1);
    apply_med_set_med_limit(medh,g_med_limit);
    apply_med_set_med_cutoff(medh,g_med_cutoff);
    

	server_init();
	serverstring = xxcalloc(UDP_MAX+1, sizeof(char));
	line = xxcalloc(UDP_MAX+1, sizeof(char));
	addrlen = sizeof(clientaddr);
	for (;;) {
	    numbytes = recvfrom(listen_sd, line, UDP_MAX, 0,(struct sockaddr *)&clientaddr, &addrlen);
	    if (numbytes == -1) {
		perror("recvfrom() failed, aborting");
		break;
	    }
	    line[numbytes] = '\0';
	    line[strcspn(line, "\n\r")] = '\0';
	    fflush(stdout);
	    results = 0;
	    udpsize = 0;
	    serverstring[0] = '\0';
	    handle_line(line);
// 	    if (!buffered_output) {
// 		fflush(stdout);
// 	    }
	    if (serverstring[0] != '\0') {
		numbytes = sendto(listen_sd, serverstring, strlen(serverstring), 0, (struct sockaddr *)&clientaddr, addrlen);
		if (numbytes < 0) {
		    perror("sendto() failed"); fflush(stdout);
		}
	    }
	}
	
	
      /* Cleanup */
      for (chain_pos = chain_head; chain_pos != NULL; chain_pos = chain_head) 
      {
	  chain_head = chain_pos->next;
	  if (chain_pos->ah != NULL) {
	      apply_clear(chain_pos->ah);
	  }
	  if (chain_pos->net != NULL) {
	      fsm_destroy(chain_pos->net);
	  }
	  xxfree(chain_pos);
      }
	 
      if (medh != NULL) {
	  apply_med_clear(medh);
      }
      if (mednet != NULL) {
	    fsm_destroy(mednet);
      }
      
      if (ah != NULL) {
	  apply_clear(ah);
      }
      if (analyzernet != NULL) {
	    fsm_destroy(analyzernet);
      }
 
      exit(0);
}  
    

// char *get_next_line() {
//     char *r;
//     if ((r = fgets(line, LINE_LIMIT, INFILE)) != NULL) {
// 	line[strcspn(line, "\n\r")] = '\0';
//     }
//     return r;
// }

void handle_line(char *s) {
    char *result, *tempstr;
    int normalized=0;
    
    /* make sure string is not empty */
    if(line[0] != '\0')
    {
	/* Apply analyzer.bin */  
	result = apply_up(ah, line);
	
	/* if no result from analyzer, spell check this word with normalizer */
	if(result == NULL)
	{
	  /* apply chain.bin (normalizer) */
	    if (apply_alternates == 1) {
	      for (chain_pos = chain_head, tempstr = s;   ; chain_pos = chain_pos->next) {
		  result = applyer(chain_pos->ah, tempstr);
		  if (result != NULL) {
		      results++;
		    printf("%s:\n \t%s\n", line, result);
		      normalized=1;
		      while ((result = applyer(chain_pos->ah, NULL)) != NULL) {
			  results++;
			printf("%s:\n \t%s\n", line, result);
		      }
		      break;
		  }
		  if (chain_pos == chain_tail) {
		      break;
		  }
	      }
	    } else {    
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
			  printf("%s:\n \t%s\n", line, result);
			  normalized=1;
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
	  /* if no result from chain.bin (normalizer), use med search with spellcheckUnificado.bin */
	  if(normalized == 0){
		/*apply med search*/
		printf("%s\n", line);
		result = apply_med(medh, line);
		if (result == NULL) 
		{
		    printf("\t???\n");
		} 
		else 
		{
		    printf("\t%s\n",result);
		    printf("\t%s\n", apply_med_get_instring(medh));
		    printf("\tCost[f]: %i\n\n", apply_med_get_cost(medh));
		  
		    while ((result = apply_med(medh,NULL)) != NULL) {
		      printf("\t%s\n",result);
		      printf("\t%s\n", apply_med_get_instring(medh));
		      printf("\tCost[f]: %i\n\n", apply_med_get_cost(medh));
		      }
		}
	    }
	  
	}
	/* word was recognized by analyzer.bin */
	else{
	  printf("%s:\n \t%s\n", line, "--");
	}
    }
}

void server_init(void) {
    unsigned int rcvsize = 262144;

    if ((listen_sd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
	perror("socket() failed");
	exit(1);
    }
    if (setsockopt(listen_sd, SOL_SOCKET, SO_RCVBUF, (char *) &rcvsize, sizeof(rcvsize)) < 0) {
    	perror("setsockopt() failed");
    	exit(1);
    }
    if (setsockopt(listen_sd, SOL_SOCKET, SO_SNDBUF, (char *) &rcvsize, sizeof(rcvsize)) < 0) {
    	perror("setsockopt() failed");
    	exit(1);
    }

    memset((char *) &serveraddr, 0, sizeof(serveraddr));
    serveraddr.sin_family = AF_INET;
    serveraddr.sin_port = htons(port_number);
    if (server_address != NULL) {
	serveraddr.sin_addr.s_addr = inet_addr(server_address);
    } else {
	serveraddr.sin_addr.s_addr = INADDR_ANY;
    }
    if (bind(listen_sd, (struct sockaddr *) &serveraddr, sizeof(serveraddr)) == -1) {
	perror("bind() failed");
	exit(1);
    }
    printf("Started spellcheck server on %s port %i\n", inet_ntoa(serveraddr.sin_addr), port_number); fflush(stdout);
}
