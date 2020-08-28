/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#include <sys/inotify.h>

#ifndef INOTIFY_H
  #define INOTIFY_H

  #define EVENT_SIZE (sizeof (struct inotify_event))
  #define BUF_LEN    (1024 * (EVENT_SIZE + 16))

  void myinotify(void);
#endif
