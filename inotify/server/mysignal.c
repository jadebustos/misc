/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#include <signal.h>
#include <stdlib.h>

#include "finish.h"

/* function to handle signals */

void signal_handler(int signal) { /* begin - signal_handler */

    finish("Terminado por señal SIGTERM.");

    return;

} /* end - signal_handler */

