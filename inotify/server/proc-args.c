/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#include <unistd.h>
#include <getopt.h>
#include <string.h>
#include <stdlib.h>

#include "mft-in.h"

extern mftinConf myCfg;

int processing_args(int argc, char *argv[]) { /* begin - processing_args function */

    int opt = 0,
	long_index = 0,
	rc = -1;

    /* arguments */
    static struct option long_options[] = {
	{"config-file", required_argument, 0, 'c'},
	{0            , 0                , 0, 0}
    };

    /* process arguments */
    while ( (opt = getopt_long(argc, argv, "apl:b:", long_options, &long_index)) != -1 ) { /* begin - while getopt_long */

	switch(opt) { /* begin - switch */
	case 'c':
	    /* char strings ends with '\0' */
            myCfg.confFile = (char *)calloc(strlen(optarg) + 1, sizeof(char));
	    if ( myCfg.confFile == NULL ) { /* begin - if */
		finish("Error de memoria en procesamiento de argumentos");
		exit(1);
	    } /* end - if */
	    strcpy(myCfg.confFile, optarg);
	    rc = 0;
	    break;
	default:
	    finish("Argumentos no válidos.");
	    exit(1);
	} /* end - switch */

    } /* end - while getopt_long */

    return rc;

} /* end - processing_args function */
