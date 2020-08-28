/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#ifndef MFTIOUT_H
  #define MFTOUT_H

  /* configuration data */
  typedef struct {
      int threads;    /* threads */

      unsigned int numFiles; /* numero de ficheros */

      char  *directory; /* directory where files are going to be created */
	        
  } mftoutConf;
#endif
