/* (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> */
/*     Distributed under GNU GPL v2 License                    */
/*     See COPYING.txt for more details                        */

#ifndef MFTIN_H
  #define MFTIN_H

  #define LOG_SYS_SYSLOG 0
  #define LOG_SYS_SYSTEMD 1

  #define EVENT_FILE_CREATION 0

  /* configuration data */
  typedef struct {
      int log_service, /* log service to be used */
	  event;       /* event to be monitored */

      char *pidFile,  /* default pid file */
	  *confFile,  /* configuration file */
	  *directory, /* directory to be monitored */
	  *cmd;       /* command to be executed on event */   
      
  } mftinConf;
#endif
