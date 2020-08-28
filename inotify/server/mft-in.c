/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/stat.h>

#include "mft-in.h"
#include "read-config.h"
#include "inotify.h"
#include "mysignal.h"

/* needed for signal_handler to delete pid file under controllated exit */
mftinConf myCfg; /* configuration data, using global variables is so disgusting ... */

int main(int argc, char *argv[]) { /* begin - main function */

    int rc = 0;

    pid_t pid, /* pid */
	sid; /* session id */

    FILE *pidfd;

    struct stat st;
    
    /* intercepting signals to log exit */
    signal(SIGKILL, signal_handler);
    signal(SIGTERM, signal_handler);

    /* args process  */
    rc = processing_args(argc, argv);

    /* if no configuration file is supplied error */
    if ( rc != 0 ) { /* begin - if */
	perror("No se indicó un fichero de configuración.\n");
	exit(1);
    } /* end - if */

    rc = read_configuration();

    /* daemonize */

    pid = fork(); /* child proccess creation */

    if ( pid < 0 ) { /* begin - if */
	perror("Error al daemonizar");
	exit(1);
    } /* end - if */

    /* killing father process */
    if ( pid > 0 ) { /* begin - if */
	exit(0);
    } /* end - if */

    umask(0); /* unmasking the file mode */

    sid = setsid(); /* setting new session id */

    if( sid < 0 ) { /* begin - if */
	perror("Error al hacer el fork");
	exit(1);
    } /* end - if */

    /* if pid file exist then finish */
    rc = stat(myCfg.pidFile, &st);
    if ( rc == 0 ) { /* begin - if */
	perror("El fichero de pid existe, proceso en ejecución?");
	exit(1);
    } /* end - if */
    
    /* writing pid to a file */
    pidfd = fopen(myCfg.pidFile, "w");
    if ( pidfd == NULL ) { /* begin - if */
       	perror("No se pudo crear el fichero del pid");
	exit(1);
    } /* end - if */

    fprintf(pidfd, "%d", sid);
    fclose(pidfd);

    /* setting current working directory to root */
    chdir("/");

    /* closing stdin. stdout and stderr */
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    while (1) { /* begin - while */
	myinotify();
    } /* end - while */

    return 0;
    
} /* end -main function */
