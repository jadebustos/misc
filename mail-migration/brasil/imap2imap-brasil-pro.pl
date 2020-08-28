#!/usr/bin/perl -w

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# You can get it from http://www.gnu.org/licenses/gpl.txt
#
# (c) Jose Angel de Bustos Perez <jadebustos@gmail.com>
#

#
# Script que coge los correos de los usuarios y los pasa a la cuenta
# de correo correspondiente a traves de un servidor IMAP.
#
# Observaciones:
#   - Utiliza autenticacion en claro.
#   - Coge los parametros pasados en linea de comando como base
#     de donde encontrara los directorios de los dominios.
#   - Supone que se utiliza maildir.
#   - La estructura es directorio_base/dominio/X/usuario.
#     donde X es la primera letra del nombre del usuario y
#     usuario puede ser el login del usuario o su direccion
#     completa de correo.
#   - Lo directorios terminan en "/".
#   - Por cada usuario crea un fichero comprimido con gzip en el
#     que se logea la actividad realizada para dicho usuario.
#   - Crea los folders que estan por debajo de INBOX, no subfolders,
#     en el servidor.
#   - Repone los flags, aunque no estan todos soportados (ver codigo).
#   - Si se excede la cuota del usuario no almacena el mensaje, pero
#     se logea en el fichero correspondiente.
#

use strict;

use DBI;
use Time::Local;

use PersonalPerlLibrary::FS;
use PersonalPerlLibrary::Mail;

my $imapServer="195.149.210.98";
my $port=1430;
my $password="";

# ficheros de log

my $stderr_log         = "errores-brasil.log";
my $std_log            = "std-out-brasil.log";
my $general_log        = "migracion-brasil.log";
my $get_email_log      = "error-extraer-direccion-brasil.log";
my $invalid_email_log  = "error-direccion-novalida-brasil.log";
my $invalid_domain_log = "error-dominio-brasil.log";
my $bbdd_log           = "bbdd-brasil.log";

my $base_dir = "/var/spool/mailbox/";
my $mail_dir = $base_dir."br/"; # directorio base en el que se almacenaran los dominios

# carpetas que han de tener al crear las cuentas
my %base_folders = ( "INBOX"     , "INBOX",
                     "Enviados"  , "INBOX.Enviados",
                     "Papelera"  , "INBOX.Trash", 
                     "Spam"      , "INBOX.Spam",
                     "Borradores", "INBOX.Borradores");

my @valid_folders = ("INBOX"); # Folders validos para buscar la direccion de correo

my $sent_folder = ".Sent"; # Nombre de la carpeta .Sent en el dominio, personalizar para cada
                           # dominio

# se utilizaran para convertir todas estas carpetas a las estandar
my @enviados_alias   = ("INBOX.Sent");
my @spam_alias       = ("INBOX.Spam");
my @borradores_alias = ("INBOX.Rascunhos");
my @papelera_alias   = ("INBOX.Lixeira");

my $mysql_server = "ip";
my $mysql_user   = "postfix";
my $mysql_pass   = "password";
my $mysql_db     = "postfixdb";

my $user_pwd = $password;

my @domains;

my $imapcon;

my $fecha;
my $unix_time;

my %months = ( "Jan" , "01",
               "Feb" , "02",
               "Mar" , "03",
               "Apr" , "04",
               "May" , "05",
               "Jun" , "06",
               "Jul" , "07",
               "Aug" , "08",
               "Sep" , "09",
               "Oct" , "10",
               "Nov" , "11",
               "Dec" , "12");

my %dias = ( "1" , "01",
              "2" , "02",
              "3" , "03",
              "4" , "04",
              "5" , "05",
              "6" , "06",
              "7" , "07",
              "8" , "08",
              "9" , "09");

my $day;
my $month;
my $year;
my $file_date;
my $hour;
my $min;
my $sec;

if ( $#ARGV == -1 ) {

   print "Uso:\tperl imap2imap-chile.pl PATH1 PATH2 ...\n";
   print "\t\tPATH1/dominio1.1\n\t\tPATH1/dominio1.2\n\t\t...\n";
   print "\t\tPATH2/dominio2.1\n\t\tPATH2/dominio2.1\n\t\t...\n";
   exit 0;


# conexion con la BBDD
my $dsn = "DBI:mysql:".$mysql_db.":".$mysql_server;
my $dbh = DBI->connect($dsn,$mysql_user,$mysql_pass);

my $dbh_password = DBI->connect($dsn,$mysql_user,$mysql_pass);

open BBDDLOG,"> $bbdd_log";

# obtenemos los dominios a procesar
get_directory_list(check_dir_path($ARGV[0]),\@domains);

foreach my $domain (@domains) {

  my @users = ();
  my @result_query = ();
  my $work_domain = lc($domain);
  my $domain_path = check_dir_path(check_dir_path($ARGV[0]).$domain);
  my $domain_maildir_path = check_dir_path(check_dir_path($mail_dir).$domain);
  my @domain_dirs = (); # directorios del dominio

  # abrimos logs
  open STDERR,          "> $work_domain-$stderr_log";
  open STD,             "> $work_domain-$std_log";
  open LOG,             "> $work_domain-$general_log";
  open LOGGETEMAIL,     "> $work_domain-$get_email_log";
  open LOGEXTRACTEMAIL, "> $work_domain-$invalid_email_log";
  open LOGGETDOMAIN,    "> $work_domain-$invalid_domain_log";

  # obtenemos la inicial de las cuentas creadas (letras del abecedario)
  get_directory_list($domain_path,\@domain_dirs);

  foreach my $dir (@domain_dirs) {
    my $mailbox_base_dir = check_dir_path($domain_maildir_path.lc($dir));
    my @user_mailboxes = ();

    get_directory_list(check_dir_path($domain_path.$dir),\@user_mailboxes);

    foreach my $user (@user_mailboxes) {
      my $user_dir_path = check_dir_path(check_dir_path($domain_path.$dir).$user);
      my $user_mail = get_email_from_rfc822_message($user_dir_path,\@valid_folders);

      # dominio/x/xy/xy...@dominio
      my $mailbox_userdir = check_dir_path($mailbox_base_dir);
      my $user_inbox_dir = get_user_inbox_dir($user_dir_path);
      my $user_log_file = '';
      my @folders = ();
      # la clave sera el nombre original del folder y el valor de la clave sera
      # el nombre con el que se creara esa carpeta en el servidor
      my %final_folders = %base_folders;
      my $imapcon; # conexion con el servidor IMAP
      my @user_files = (); # ficheros dentro del mailbox del usuario
      my @smtp_user_files = (); # mensajes de correo a almacenar
      my @junk_files = (); # ficheros que no son entendidos como mensajes de correo

      $user_mail =~ s/maildomainold/maildomainnew/g;

      # LOS USUARIOS QUE NO TIENEN NINGUN CORREO DEVUELVE '' ¿QUE HACEMOS CON ELLOS?
      if ($user_mail eq '' ) {

# Variar para cada pais

        my $user_sent_folder = $user_dir_path."Maildir/".$sent_folder;
        $user_mail = get_email_from_sent_folder($user_sent_folder) if -d $user_sent_folder;
        if ( $user_mail eq '' ) {
          print LOG "ERROR - No se ha podido extraer una direccion de correo del buzon $user_dir_path\n";
          print LOGGETEMAIL "ERROR - $user_dir_path\n";
          next;
        }
      }

      # validamos la direccion de correo
      if ( validate_email($user_mail) ne 0 ) {
        print LOG "ERROR - Direccion $user_mail no valida ($user_dir_path)\n";
        print LOGEXTRACTEMAIL "ERROR - $user_mail\n";
        next;
      }

      # Fichero de log para el usuario
      $user_log_file = lc($user_mail).".log";

print "Procesando $user - Direccion: $user_mail - Log: $user_log_file\n";

      # borramos el contenido de result_query
      $#result_query = -1;

      my $sth = $dbh->prepare(qq{SELECT maildir FROM mailbox WHERE username = "$user_mail"});
      $sth->execute();
      while ( my $item = $sth->fetchrow_array() ) {
        push @result_query,$item;
      }
      $sth->finish(); # terminamos la consulta

      # Si el usuario no existe logeamos
      if ( $#result_query == -1 ) {
        print BBDDLOG "ERROR - $user_mail\n";
        print LOG "ERROR - No existe entrada en la BBDD para $user_mail.\n";
        next;
      }
      elsif ( $#result_query != 0 ) {
        print BBDDLOG "ERROR - $user_mail\n";
        print LOG "ERROR - Existen varias entradas de $user_mail en la BBDD.\n";
        next;
      }

      my ($user_name,$user_domain) = (split /\@/,$user_mail)[0,1];
      $user_domain = lc($user_domain);

      # si no coinciden ambos dominios logearlo y pasar al siguiente
      if ( $user_domain ne $work_domain ) {
        print LOG "ERROR - No coincide el dominio del usuario ($user_mail) con el dominio que se esta migrando ($user_dir_path).\n";
        print LOGGETDOMAIN "ERROR - El usuario ($user_mail) tiene como dominio $user_domain cuando deberia tener $work_domain ($user_dir_path).\n";
	next;
      }

      # logeamos el usuario que se esta procesando
      print STD "Procesando usuario $user_mail.\n";

      # obtenemos el password del usuario
      my $sth_password = $dbh_password->prepare(qq{SELECT password FROM mailbox WHERE username="$user_mail"});
      $sth_password->execute();
      while ( my $item = $sth_password->fetchrow_array() ) {
        $password = $item; 
      }
      $sth_password->finish();

      # obtenemos las folders de cada usuario
      @folders = get_folders_from_directory($user_dir_path);

      # convertimos las folders encontradas al estandar
      foreach my $folder (@folders) {
        $final_folders{$folder} = $folder;
      }

      # nos aseguramos de que los nombres de los folders son los correctos
      foreach my $key (keys %final_folders) {

        foreach my $item (@enviados_alias) {
          if ( lc($key) eq lc($item) ) {
            $final_folders{$key} = $base_folders{"Enviados"};
            last;
          }
        }
        foreach my $item (@papelera_alias) {
          if ( lc($key) eq lc($item) ) {
            $final_folders{$key} = $base_folders{"Papelera"};
            last;
          }
        }
        foreach my $item (@spam_alias) {
          if ( lc($key) eq lc($item) ) {
            $final_folders{$key} = $base_folders{"Spam"};
            last;
          }
        }
        foreach my $item (@borradores_alias) {
          if ( lc($key) eq lc($item) ) {
            $final_folders{$key} = $base_folders{"Borradores"};
            last;
          }
        }
      }

      # obtenemos los ficheros en el maildir del usuario
      @user_files = get_files_from_directory($user_dir_path);

      # seleccionamos solo aquellos que sean mensajes validos de correo
      foreach my $file (@user_files) {
        if ( is_file_smtp_message($file) ) {
          push @smtp_user_files,$file;
        }
        # hay mensajes que no se almacenan como smtp mail text (rfc822) y que tambien son
        # mensajes de correo validos:
        #          * ASCII mail text
        #          * ISO-8859 mail text
        #          * Non-ISO extended-ASCII mail text
        elsif ( $file =~ /^[\w\.]*,S=\d*/ ) {
          # el nombre del fichero en el cual se guarda el mensaje de correo tiene un nombre
          # similar a: 1103673566.M830443P9842V0000000000006806I008F41AD_0.webmail,S=8981:2,S
          push @smtp_user_files,$file;
        }
        # incluimos los mensajes enviados como mensajes validos de correo
        elsif ( is_file_a_sent_message($file) ) {
          push @smtp_user_files,$file;
        }
        else {
          push @junk_files,$file;
        }
      }

      # abrimos un fichero de log por usuario
      open USERLOG,"> $user_log_file";

      # establecemos conexion con el servidor y creamos las carpetas que no existan
      $imapcon = connect_imap($imapServer, $port, $user_mail, $password);

      if ( !defined($imapcon) ) {
        print LOG "ERROR -  No se pudo abrir conexion con el servidor imap $imapServer ($user_mail/$password).\n";
        next;
      }
      else {
        print USERLOG "OK - $user_mail/$password\n";
      }

      # logeamos las folders obtenidas
      $#folders = -1;
      foreach my $key (keys %final_folders) {
        print USERLOG "OK - $key => $final_folders{$key}\n";
        push @folders,$final_folders{$key};
      }

      @folders = values %final_folders;

      create_imap_folders(\@folders, $imapcon);

      # suscribimos a las folders
      foreach my $folder (@folders) {
        next if $folder eq "INBOX";
        $imapcon->subscribe($folder);
        print USERLOG "OK - Suscrito al folder $folder\n";
      }

      # procesamos los mensajes validos de correo
      foreach my $mailmsg (@smtp_user_files) {
        my @msg_path = split /\//,$mailmsg;
        my $status = "Stored";
        my $msg_flags = ""; # flags del mensaje
        my @tmp = ();
        my $msg = ""; # mensaje a almacenar
        my $tofolder = "INBOX"; # folder de destino del mensaje
        my $this_msg_user = ""; # destinatario del correo en cuestion

        # eliminamos el primer elemento que es un blanco
        @msg_path=reverse(@msg_path);
        pop(@msg_path);
        @msg_path=reverse(@msg_path);

        # eliminamos todos los directorios anteriores al del Mailbox principal del
        # usuario
        while ( shift(@msg_path) !~ $user ) { ; }
        # obtenemos los flags del mensaje
        @tmp = split /,S=\d*:\d,/,$msg_path[$#msg_path];
        if ( $#tmp > 0 ) {
          $msg_flags = $tmp[$#tmp];
        }
        # se soportan los siguients flags de rfc2060
        # S -> \Seen
        # R -> \Answered
        # D -> \Draft
        $msg_flags =~ s/S/\\Seen /;
        $msg_flags =~ s/R/\\Answered /;
        $msg_flags =~ s/D/\\Draft /;
         
        my $control = 0;
        # almacenamos el mensaje de correo en $msg
        open MSG, "< $mailmsg";
        foreach my $line (<MSG>) {
          # Eliminamos los final de linea tipo DOS
          $line =~ s/\r/\n/g;

          # Recogemos la informacion horaria
          if ( $line =~ /^D[a|A][t|T][e|E]:/ ) {
            last if $control ne 0;
            $line =~ s/[A-Z][a-z][a-z],//g;
            $fecha = $line;
            $control = 1;
          }

          $msg = $msg.$line;
        }
        close MSG;

        # Almacenamos el mensaje para que quede el transformado
        # como mensaje original
        open MSG, "+> $mailmsg";
        print MSG "$msg";
        close MSG;

        # determinamos el folder del mensaje
        foreach $dir ( @msg_path ) {
          if ( $dir =~ /^\.\w/ ) {
            # el mensaje pertenece a un folder distinto del INBOX
            $tofolder = $tofolder.$dir;
            last;
          }
        }

        # verificamos que el destinatario de este mensaje es el mismo que el
        # obtenido antes y almacenado en $user_mail
        if ( $final_folders{$tofolder} eq $base_folders{'Enviados'} ) {
          $this_msg_user = get_email_from_sent_file($mailmsg);
        }
        elsif ( $final_folders{$tofolder} eq $base_folders{'Borradores'} ) {
          $this_msg_user = get_email_from_draft_file($mailmsg);
        }
        else {
          $this_msg_user = get_email_from_file($mailmsg);
        }

        if ( $this_msg_user eq '' ) {
          print USERLOG "NULL - $mailmsg\n";
        }

        # almacenamos el mensaje
        my $uid = $imapcon->append_string($final_folders{$tofolder}, $msg, $msg_flags, $fecha);
        if ( !defined($uid) ) {
          print USERLOG "ERROR - $mailmsg\n";
        }
        else {
          print USERLOG "OK - $mailmsg\n";
        }

      }

      # cerramos y comprimimos el fichero de log de usuarios
      $imapcon->disconnect;
      print USERLOG "OK - Se cerro la conexion con el usuario $user_mail.\n";
      close USERLOG;
      `gzip -f $user_log_file`;

    }

  }

  # cerramos y comprimimos el log generico
  close LOG;
  `gzip -f $work_domain-$general_log`;

  # cerramos y comprimimos el log de los dominios
  close LOGGETDOMAIN;
  `gzip -f $work_domain-$invalid_domain_log`;

  # cerramos y comprimimos el log de las direcciones de correo
  close LOGGETEMAIL;
  `gzip -f $work_domain-$get_email_log`;

  # cerramos y comprimimos el log de las direcciones de correo
  close LOGEXTRACTEMAIL;
  `gzip -f $work_domain-$invalid_email_log`;

  # cerramos la salida estandar y la comprimimos
  close STD;
  `gzip -f $work_domain-$std_log`;

  # cerramos y comprimimos el log de la salida estandar de errores
  close STDERR;
  `gzip -f $work_domain-$stderr_log`;

}

# cerramos la conexion con la BBDD, el fichero de log y lo comprimimos
$dbh->disconnect;
close BBDDLOG;
`gzip -f $bbdd_log`;
