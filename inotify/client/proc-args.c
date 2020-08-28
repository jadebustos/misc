/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mft-out.h"

extern mftoutConf myCfg;

int processing_args(int argc, char *argv[]) { /* begin - processing_args function */

    int opt = 0,
	long_index = 0,
	rc = -1;

    /* arguments */
    static struct option long_options[] = {
	{"directory", required_argument, 0, 'd'},
	{"threads", required_argument, 0, 't'},
	{"number", required_argument, 0, 'n'},
	{0            , 0                , 0, 0}
    };

    /* process arguments */
    while ( (opt = getopt_long(argc, argv, "apl:b:", long_options, &long_index)) != -1 ) { /* begin - while getopt_long */

	switch(opt) { /* begin - switch */
	case 'd':
	    /* char strings ends with '\0' */
            myCfg.directory = (char *)calloc(strlen(optarg) + 1, sizeof(char));
	    if ( myCfg.directory == NULL ) { /* begin - if */
		perror("Error de memoria en procesamiento de argumentos");
		exit(1);
	    } /* end - if */
	    strcpy(myCfg.directory, optarg);
	    rc = 0;
	    break;
	case 't':
	    myCfg.threads = atoi(optarg);
	    rc = 0;
	    break;
	case 'n':
	    myCfg.numFiles = (unsigned int) atoi(optarg);
	    rc = 0;
	    break;
	default:
	    perror("Argumentos no válidos.");
	    exit(1);
	} /* end - switch */

    } /* end - while getopt_long */

    return rc;    
    
} /* end - processing_args function */
