/*     Foma: a finite-state toolkit and library.                             */

#include <stddef.h>

/*     Copyright © 2008-2010 Mans Hulden                                     */

/*     This file is part of foma.                                            */

/*     Foma is free software: you can redistribute it and/or modify          */
/*     it under the terms of the GNU General Public License version 2 as     */
/*     published by the Free Software Foundation.                            */

/*     Foma is distributed in the hope that it will be useful,               */
/*     but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*     GNU General Public License for more details.                          */

/*     You should have received a copy of the GNU General Public License     */
/*     along with foma.  If not, see <http://www.gnu.org/licenses/>.         */

#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
#include <getopt.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include "fomalib.h"

#define LINE_LIMIT 262144
#define MED_PORT 6062

char *usagestring = "Usage: fmed [-l med_limit] [-c cutoff] <binary foma file>\n";
char *helpstring = 
"Applies med search (spellcheck) to words from stdin to a foma automaton read from a file\n"
"Options:\n"
"-h\t\tprint help\n"
"-l med_limit\tset maximum number of suggestions (default is 5)\n"
"-c cutoff\tset maximum levenshtein distance for suggestions (default is 15)"
"UDP Server\n"
"-p\tPort\n"
"-a\tAddress\n";

int main(int argc, char *argv[]) {
    int opt = 1;
    char *infilename, line[LINE_LIMIT], *result, *separator = "\t";
    char *lineCorrect;
    struct fsm *net;

    //struct apply_handle *ah;
    struct apply_med_handle *medh;
    FILE *INFILE;
    extern g_med_limit;
    extern g_med_cutoff;
    int g_med_port = MED_PORT;
    char *g_med_address = NULL;
    
    while ((opt = getopt(argc, argv, "l:c:h:p:a")) != -1) {
        switch (opt) {
            case 'l':
                if (atoi(optarg) == 0) {
                    printf("Maximum number of suggestions can not be zero! Using default value (5).\n");
                    //because med search won't terminate with g_med_limit = 0*/
                    break;
                } else {
                    g_med_limit = atoi(optarg);
                    break;
                }
            case 'c':
                g_med_cutoff = atoi(optarg);
                break;
            case 'p':
                g_med_port = atoi(optarg);
                break;
            case 'a':
                g_med_address = strdup(optarg);
                break;
            case 'h':
                printf("%s%s\n", usagestring, helpstring);
                exit(0);
            default:
                fprintf(stderr, "%s", usagestring);
                exit(EXIT_FAILURE);
        } 
    }

    infilename = argv[optind];
    net = fsm_read_binary_file(infilename);
    if (net == NULL) {
        fprintf(stderr, "%s: %s\n", "File error", infilename);
        exit(EXIT_FAILURE);
    }
    medh = apply_med_init(net);
    INFILE = stdin;
    while (fgets(line, LINE_LIMIT, INFILE) != NULL) {
        line[strcspn(line, "\n")] = '\0'; /* chomp */
     
        //result = apply_med(medh, line);
        apply_med_set_heap_max(medh, 4194304 + 1);
        apply_med_set_med_limit(medh, g_med_limit);
        apply_med_set_med_cutoff(medh, g_med_cutoff);
        
        result = apply_med(medh, line);
        /* IMPLEMENTACIÓN RICHARD */
        if (result == NULL) {
            lineCorrect = apply_med_get_instring(medh);
            char str[8000];
            strcat(str, lineCorrect);
            strcat(str, ",");
        }
        else {
            lineCorrect = apply_med_get_instring(medh);
            char str[8000];
            strcat(str, result);
            strcat(str, ",");
            while ((result = apply_med(medh, NULL)) != NULL) {
                strcat(str, result);
                strcat(str, ",");
            }
            char dst[sizeof str];
            int instringLength = strlen(str);
            sprintf(dst, "%.*s", instringLength - 1, &str[0]);
            fprintf(stdout,"%s\n", dst);
        }
        /*
        if (result == NULL) {
            printf("???\n");
            printf("%s\n\n", line);
        }
        else {
            printf("%s\n", result);
            printf("%s\n", apply_med_get_instring(medh));
            printf("Cost[f]: %i\n\n", apply_med_get_cost(medh));

            while ((result = apply_med(medh, NULL)) != NULL) {
                printf("%s\n", result);
                printf("%s\n", apply_med_get_instring(medh));
                printf("Cost[f]: %i\n\n", apply_med_get_cost(medh));
            }
        }
        */
    }
    if (medh != NULL) {
        apply_med_clear(medh);
    }
    if (net != NULL) {
        fsm_destroy(net);
    }
    exit(0);
}
