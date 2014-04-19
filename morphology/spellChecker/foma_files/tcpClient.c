#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <arpa/inet.h> 
#include "fomalib.h"


#define LINE_LIMIT 262144
#define FLOOKUP_PORT 8888
static int port_number = FLOOKUP_PORT;
static FILE *INFILE;
int opt = 1;
static char  *line;
// static void app_print(char *result);

char *usagestring = "Usage: tcpClient [-P port number]\n";
char *helpstring = "tcpClient reads (tokenized) data from stdin and calls tcpServer for spell checking\n"
"Options:\n"
"-h\t\tprint help\n"
"-P\t\tspecify port of server (default 8888)\n";

static char *get_next_line();

// void app_print(char *result) {
// 	if (echo == 1) {
// 	    strncat(serverstring+udpsize, line, UDP_MAX-udpsize);
// 	    udpsize += strlen(line);
// 	    strncat(serverstring+udpsize, separator, UDP_MAX-udpsize);
// 	    udpsize += strlen(separator);
// 	}
// 	if (result == NULL) {
// 	    strncat(serverstring+udpsize, "?+\n", UDP_MAX-udpsize);
// 	    udpsize += 3;
// 	} else {
// 	    strncat(serverstring+udpsize, result, UDP_MAX-udpsize);
// 	    udpsize += strlen(result);
// 	    strncat(serverstring+udpsize, "\n", UDP_MAX-udpsize);
// 	    udpsize++;
// 	}
// }

int main(int argc, char *argv[])
{
    while ((opt = getopt(argc, argv, "P:h")) != -1){
              switch(opt) {
		case 'h':
		  printf("%s%s\n", usagestring,helpstring);
		  exit(0);
		case 'P':
		  port_number = atoi(optarg);
		break;
		default:
		  fprintf(stderr, "%s", usagestring);
		  exit(EXIT_FAILURE);
	      }
    }
      
    int sockfd = 0, n = 0;
    char recvBuff[1024];
    struct sockaddr_in serv_addr; 
    INFILE = stdin;
    

    if(argc != 3)
    {
        printf("\n Usage: %s  -P <port number> \n",argv[0]);
        return 1;
    } 

    memset(recvBuff, '0',sizeof(recvBuff));
    if((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    {
        printf("\n Error : Could not create socket \n");
        return 1;
    } 

    memset(&serv_addr, '0', sizeof(serv_addr)); 

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port_number); 

    if(inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr)<=0)
    {
        printf("\n inet_pton error occured\n");
        return 1;
    } 

    if( connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
    {
       printf("\n Error : Connect Failed \n");
       return 1;
    } 
    
    /* Standard read from stdin */
    line = xxcalloc(LINE_LIMIT, sizeof(char));
    
    while (get_next_line() != NULL) {
	 //results = 0; 
        // printf("sent %s\n\n",line); 
	 n = write(sockfd,line,strlen(line));
	 
	if (n < 0) 
	{
	    perror("ERROR writing to socket");
	    exit(1);
	}
	/* Now read server response */
	bzero(recvBuff,256);
	n = read(sockfd,recvBuff,255);
	if (n < 0) 
	{
	    perror("ERROR reading from socket");
	    exit(1);
	}
	printf("%s\n",recvBuff); 
// 	 while ( (n = read(sockfd, recvBuff, sizeof(recvBuff)-1)) > 0)
// 	{
// 	    recvBuff[n] = 0;
// 	    if(fputs(recvBuff, stdout) == EOF)
// 	    {
// 		printf("\n Error : Fputs error\n");
// 	    }
// 	} 
}


    if(n < 0)
    {
        printf("\n Read error \n");
    } 

    return 0;
}

char *get_next_line() {
    char *r;
    if ((r = fgets(line, LINE_LIMIT, INFILE)) != NULL) {
	line[strcspn(line, "\n\r")] = '\0';
    }
    return r;
}