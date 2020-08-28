/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#include <stdio.h>
#include <unistd.h>

#include "mft-in.h"

extern mftinConf myCfg;

void finish(char *msg) { /* begin - function finish */

    int rc;

    perror(msg);
    
    rc = unlink(myCfg.pidFile);

    return;
} /* end - function finish */
