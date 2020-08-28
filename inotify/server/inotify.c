/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/inotify.h>

#include "inotify.h"
#include "mft-in.h"
#include "finish.h"

extern mftinConf myCfg;

void myinotify(void) { /* begin - function myinotify */

    int fd, /* file descriptor for an inotify event queue */
	uwd; /* unique watch descriptor for a watch in a path */
    
    char buffer[BUF_LEN];

    char *cmd; /* command to process the file */

    int length;
    
    /* read es bloqueante, pero dado que solo se va a esperar a la creación de ficheros en principio no
       veo problemas por no multiplexar E/S con select, poll o epoll */ 
    
    /* initializing a inotify event queue */
    fd = inotify_init();

    if ( fd < 0 ) { /* begin - if */
	finish("Error al inicializar el subsistema inotify");
	exit(1);
    } /* end - if */

    switch(myCfg.event) { /* begin - switch */
    case 0:
	uwd = inotify_add_watch(fd, myCfg.directory, IN_CREATE);
	break;
    } /* end - switch */

    if ( uwd < 0 ) { /* begin - if */
	finish("Error al crear el watcher con inotify");
	exit(1);
    } /* end - if */

    length = read(fd, buffer, BUF_LEN);

    struct inotify_event *event = ( struct inotify_event * ) &buffer;

    /* full path to command to process the file */
    cmd = (char *)calloc(strlen(myCfg.cmd) + strlen(myCfg.directory) + strlen(event->name) + 3, sizeof(char));

    if ( cmd == NULL ) { /* begin - if */
	finish("Error de memoria en myinotify");
	exit(1);
    } /* end - if */

    /* building command full path name */
    strcpy(cmd, myCfg.cmd);
    strcat(cmd, " ");
    strcat(cmd, myCfg.directory);
    strcat(cmd, "/");
    strcat(cmd, event->name);

    /* processing the file */
    system(cmd);
    
    /* freeing memory */
    free(cmd);
    
    return;
} /* end - function myinotify */
