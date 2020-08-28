/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#include <stdlib.h>
#include <libconfig.h>
#include <syslog.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>

#include "mft-in.h"
#include "read-config.h"

extern mftinConf myCfg;

int read_configuration(void) { /* begin - read_configuration function */

    config_t cfg; /* structure to store all config parameters */

    const char *tmpData;
	
    /* config initialization */
    config_init(&cfg);

    /* read configuration. If there is an error, report it and exit. */
    if (!config_read_file(&cfg, myCfg.confFile)) { /* begin - if */
	config_destroy(&cfg);
	finish("Error leyendo configuracion");
	exit(1);
    } /* end - if */

    /* getting the pid file name */ 
    if (!config_lookup_string(&cfg, "pid", &tmpData)) { /* begin - if */
	finish("Error obteniendo pid file");
	exit(1);
    } /* end - if */

    myCfg.pidFile = (char *)calloc(strlen(tmpData) + 1, sizeof(char));
    if ( myCfg.pidFile == NULL ) { /* begin - if */
	finish("Error en asignación de memoria");
        exit(1);
    } /* end - if */
    strcpy(myCfg.pidFile, tmpData);

    /* getting directory to be monitorized */
    if (!config_lookup_string(&cfg, "directory", &tmpData)) { /* begin - if */
	finish("Error obteniendo el directorio");
	exit(1);
    } /* end - if */

    myCfg.directory = (char *)calloc(strlen(tmpData) + 1, sizeof(char));
    if ( myCfg.directory == NULL ) { /* begin - if */
	finish("Error en asignación de memoria");
        exit(1);
    } /* end - if */
    strcpy(myCfg.directory, tmpData);

    /* getting command to execute */
    if (!config_lookup_string(&cfg, "cmd", &tmpData)) { /* begin - if */
	finish("Error obteniendo el comando a ejecutar");
	exit(1);
    } /* end - if */

    myCfg.cmd = (char *)calloc(strlen(tmpData) + 1, sizeof(char));
    if ( myCfg.cmd == NULL ) { /* begin - if */
	finish("Error en asignación de memoria");
        exit(1);
    } /* end - if */
    strcpy(myCfg.cmd, tmpData);
 
    /* getting log service */
    if (!config_lookup_int(&cfg, "log_service", &myCfg.log_service)) { /* begin - if */
	finish("Error obteniendo el servicio de log");
	exit(1);
    } /* end - if */
    
    /* getting event to monitor */
    if (!config_lookup_int(&cfg, "event", &myCfg.event)) { /* begin - if */
	finish("Error obteniendo el servicio de log");
	exit(1);
    } /* end - if */

    /* destroy configuration */
    config_destroy(&cfg);

   return 0;

} /* end - read_configuration function */
