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
#   - Lo directorios terminan en "/".
#   - Por cada usuario crea un fichero comprimido con gzip en el
#     que se logea la actividad realizada para dicho usuario.
#   - Crea los folders que estan por debajo de INBOX, no subfolders,
#     en el servidor.
#   - Si se excede la cuota del usuario no almacena el mensaje, pero
#     se logea en el fichero correspondiente.
#   - Este script utiliza los maildir obtenidos del mbox que se obtuvo
#     de los mailboxes del i-Planet
#   - Los argumentos que se le pasan al script son los directorios donde
#     estan los maildir obtenidos con mb2md
#

use strict;

use DBI;
use PersonalPerlLibrary::FS;
use PersonalPerlLibrary::Mail;

my $imapServer="ip";
my $port=1430;
my $password="";

# ficheros de log

my $stderr_log         = "errores-ar.log";
my $general_log        = "migracion-ar.log";
my $bbdd_log           = "bbdd-ar.log";

my $base_dir             = "/var/spool/mailbox/";
my $mail_dir             = $base_dir."ar/"; # directorio base en el que se almacenaran los dominios
my $domain               = "maildomain";


my $start_migration_date = "20070330"; # Los mensajes posteriores a este se almacenaran
                                       # como no leidos
my $mysql_server = "ip";
my $mysql_user   = "postfix";
my $mysql_pass   = "icarus";
my $mysql_db     = "postfixdb";

my @users;
my $fecha = '';

open STDERR,          "> $stderr_log";
open LOG,             "> $general_log";

# conexion con la BBDD
my $dsn = "DBI:mysql:".$mysql_db.":".$mysql_server;
my $dbh = DBI->connect($dsn,$mysql_user,$mysql_pass);

my $dbh_password = DBI->connect($dsn,$mysql_user,$mysql_pass);

open BBDDLOG,"> $bbdd_log";

# obtenemos los usuarios a procesar que estaran en maildomain/.username
# si se paso como argumento maildomain

get_directory_list(check_dir_path($ARGV[0]),\@users);

foreach my $user_dir (@users) {

  my $user_email    = $user_dir;
  my $user          = "";
  my $password      = "";
  my $user_log_file = "";

  # debido a la conversion que hace el mb2md de los mailboxes quitamos
  # lo que sobra para tener el nombre del usuario
  $user_email =~ s/\.(.*)_mbox/$1/g;
  $user = $user_email;
  $user_email = $user_email."@".$domain;
  $user_log_file = $user_email.".log";

  # obtenemos los ficheros que contienen los mensajes de correo.
  my $dir = check_dir_path(check_dir_path($ARGV[0]).$user_dir);
  my @mail_msgs = get_files_from_directory($dir);

  my @result_query = (); # resultados de las queries

  my $imapcon = ""; # conexion con el servidor imap

  # carpetas que han de tener al crear las cuentas
  my %user_folders = ( "INBOX" , "INBOX",
                       "Sent"  , "INBOX.Enviados",
                       "Trash" , "INBOX.Trash",
                       "Spam"  , "INBOX.Spam",
                       "Drafts", "INBOX.Borradores");

  my @folders = values %user_folders;

  # abrimos una conexion con la BBDD para comprobar que el usuario existe y en caso afirmativo
  # obtener el password

  # borramos el contenido de result_query
  $#result_query = -1;

  my $sth = $dbh->prepare(qq{SELECT maildir FROM mailbox WHERE username = "$user_email"});
  $sth->execute();
  while ( my $item = $sth->fetchrow_array() ) {
    push @result_query,$item;
  }
  $sth->finish(); # terminamos la consulta

  # Si el usuario no existe logeamos
  if ( $#result_query != 0 ) {
    print LOG "ERROR - No existe el usuario $user_email en la BBDD o existen varias entradas.\n";
    next;
  }

  # abrimos un fichero de log por usuario
  open USERLOG,"> $user_log_file";

  # obtenemos el password del usuario
  my $sth_password = $dbh_password->prepare(qq{SELECT password FROM mailbox WHERE username="$user_email"});
  $sth_password->execute();
  while ( my $item = $sth_password->fetchrow_array() ) {
    $password = $item;
  }
  $sth_password->finish();

  # abrimos conexion con el servidor imap
  $imapcon = connect_imap($imapServer, $port, $user_email, $password);

  if ( ! defined($imapcon) ) {
    print LOG "ERROR - No se pudo abrir conexion con el servidor imap $imapServer y usuario $user_email.\n";
    next;
  }

  print USERLOG "OK - $user_email/$password\n";

  # creamos y registramos las folders por defecto

  create_imap_folders(\@folders,$imapcon);
  foreach my $folder ( values %user_folders ) {
    $imapcon->subscribe($folder);
    print USERLOG "OK - Suscrito al folder $folder.\n";
  }

  # procesamos cada mensaje
  foreach my $mail_msg (@mail_msgs) {

  my $msg       = "";
  my $msg_flags = ""; # flags del mensaje
  my $folder    = "";
  my $msg_date  = "";
  open MSG," < $mail_msg";

  my $control = 0;
 
  # almacenamos el mensaje en una variable
  foreach (<MSG>) {
    my $msg_flags = ""; # flags del mensaje
    # el programa que se utiliza en windows para convertir el
    # formato del i-Planet anyade en el Subject una cadena, la
    # removemos
    $_ =~ s/^Subject:[\t ]*\[[\w \#]*\] /Subject: /;
    $msg = $msg.$_;

    # Recogemos la informacion horaria
    if ( $_ =~ /^D[a|A][t|T][e|E]:/ ) {
      last if $control ne 0;
      my $tmp = $_;
      $tmp =~ s/[A-Z][a-z][a-z],//g;
      $fecha = $tmp;
      $control = 1;
    }

    # obtenemos la fecha
    if ( $msg_date eq "" && $_ =~ /[Mon|Tue|Wed|Thu|Fri|Sat|Sun], \d{1,2} [Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec]/ ) {
      my $tmpdate = $_;
      my $day;
      my $month;
      my $year;
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

      $tmpdate =~ s/.*(\w{3}, \d{2} \w{3}.{5}).*/$1/g;
      $msg_date = $tmpdate;
      chomp($msg_date);
      $day = $month = $year = $msg_date;
      $day   =~ s/(\w{3}), (\d{2}) (\w{3})(.{5})/$2/g;
      $month =~ s/(\w{3}), (\d{2}) (\w{3})(.{5})/$3/g;
      $year  =~ s/(\w{3}), (\d{2}) (\w{3})(.{5})/$4/g;
      $year  =~ s/[\t ]*//g;
      $msg_date = $year.$months{$month}.$day;
    }
    # extraemos el folder del mensaje
    chomp($_);
    if ( $_ =~ /^X-Folder/) {
      $folder = (split / /,$_)[1];
      
      if ( $folder ne $user ) {
        $folder = (split /\\/,$folder)[1] if $folder =~ /\\/;
        $folder = "Trash" if $folder eq "Papelera";

        # eliminamos el caracter + que aparece en las folders
        $folder =~ s/\+//g;

        # anyadimos las nuevas folders
        if ( !exists($user_folders{$folder}) ) {
          $user_folders{$folder} = "INBOX.".$folder;
        }
        # convertimos el folder al formato necesario
        $folder = $user_folders{$folder};
        # creamos la carpeta en caso de no existir
        if ( !$imapcon->exists($folder) ) {
          $imapcon->create($folder);
          print USERLOG "OK - Creada la carpeta $folder.\n";
          $imapcon->subscribe($folder);
          print USERLOG "OK - Suscrito la carpeta $folder.\n";
        }
      }
      else {
        # el mensaje esta en el INBOX
        $folder = $user_folders{"INBOX"}; 
      }

    }
  }

  close MSG;

  # no migramos los mensajes que esten en la papelera
  if  ( $folder eq "INBOX.Trash" ) {
    print USERLOG "SKIPPED - $mail_msg - $folder\n";
    next;
  }

  # flags
  $msg_flags = "\\Seen" if $msg_date < $start_migration_date;

  # almacenamos el mensaje
  my $uid = $imapcon->append_string($folder, $msg, $msg_flags, $fecha);
  if ( !defined($uid) ) {
    print USERLOG "ERROR - $mail_msg - $folder\n";
  }
  else {
    print USERLOG "OK - $mail_msg - $folder\n";
  }
  
  }

  # cerramos el fichero de log por usuario y lo comprimimos
  print USERLOG "OK - Se cerro la conexion con el usuario $user_email.\n";
  close USERLOG;
  `gzip -f $user_log_file`;

}

# cerramos la conexion con la BBDD, el log y lo comprimimos
$dbh->disconnect;
close BBDDLOG;
`gzip -f $bbdd_log`;

# cerramos el log generico y lo comprimimos
close LOG;
`gzip -f $general_log`;

# cerramos el log de la salida estandar y lo comprimimos
close STDERR;
`gzip -f $stderr_log`;

