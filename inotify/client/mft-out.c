/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#include <omp.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <string.h>

#include "mft-out.h"
#include "proc-args.h"

mftoutConf myCfg;

int main (int argc, char *argv[]) { /* begin - main function */

    int rc;
    unsigned int i;
    
    time_t current_time = time(NULL);
    char filename[256],
	tmp[256],
	fullpath[514];

    FILE *fd;
    
    rc = processing_args(argc, argv);

    if ( rc != 0 ) { /* begin - if */
	perror("Argumentos no validos");
	exit(1);
    } /* end - if */

#pragma omp parallel num_threads(threads) private(current_time, i, filename, tmp, fullpath, fd)

    #pragma omp for
    for(i=0;i<myCfg.numFiles;i++) { /* begin - for */
	/* current time */
	current_time = time(NULL);
	/* file name */
	sprintf(filename, "%d", (int)current_time);
	sprintf(tmp, "%ud", i);
	strcat(filename, "-");
	strcat(filename, tmp);
	/* full path */
	strcpy(fullpath, myCfg.directory);
	strcat(fullpath,"/");
	strcat(fullpath,filename);

	fd = fopen(fullpath,"w");
	fprintf(fd, "%s", fullpath);
	fclose(fd);
    } /* end - for */
    
    return 0;
} /* end - main function */
