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
use PersonalPerlLibrary::FS;
use PersonalPerlLibrary::Mail;

my $imapServer="localhost";
my $port=143;

# ficheros de log

my $stderr_log         = "errores-peru.log";
my $std_log            = "std-out-peru.log";
my $general_log        = "migracion-peru.log";
my $invalid_dir_log    = "error-direcctorio-novalido-peru.log";
my $bbdd_log           = "bbdd-peru.log";

my $base_dir    = "/var/spool/mailbox/";

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
my @papelera_alias   = ("INBOX.Papelera");
my @spam_alias       = ("INBOX.Spam");
my @borradores_alias = ("INBOX.Drafts", "INBOX.Borrador");

my $mysql_server = "ip";
my $mysql_user   = "postfix";
my $mysql_pass   = "password";
my $mysql_db     = "postfixdb";

my $imapcon;

if ( $#ARGV == -1 ) {

   print "Uso:\tperl imap2imap-peru.pl PATH1 PATH2 ...\n";
   print "\t\tPATH1/dominio1.1\n\t\tPATH1/dominio1.2\n\t\t...\n";
   print "\t\tPATH2/dominio2.1\n\t\tPATH2/dominio2.1\n\t\t...\n";
   exit 0;
}

# conexion con la BBDD
my $dsn = "DBI:mysql:".$mysql_db.":".$mysql_server;

open BBDDLOG,">> $bbdd_log";

foreach my $domain (@ARGV) {

  my %users_pass = ();
  my %users_name = ();

  # obtenemos los usuarios del dominio de peru
  my $dbh = DBI->connect($dsn,$mysql_user,$mysql_pass);
  my $sth = $dbh->prepare(qq{SELECT username,password,name FROM mailbox WHERE domain = "$domain" AND (name LIKE '0%' OR name LIKE '1%' OR name LIKE '2%' OR name LIKE '3%' OR name LIKE '4%' OR name LIKE '5%' OR name LIKE '6%' OR name LIKE '7%' OR name LIKE '8%' OR name LIKE '9%')});
  $sth->execute();
  while ( my $item = $sth->fetchrow_hashref() ) {
    $users_pass{$$item{'username'}} = $$item{'password'};
    $users_name{$$item{'username'}} = $$item{'name'};
  }
  $sth->finish(); # terminamos la consulta

  $dbh->disconnect;

  # abrimos logs
  open STDERR,          "> $domain-$stderr_log";
  open STD,             "> $domain-$std_log";
  open LOG,             "> $domain-$general_log";
  open LOGINVALIDDIR,   "> $domain-$invalid_dir_log";

  foreach my $user ( keys %users_name ) {
    my $mailbox_base_dir = "/var/spool/mailbox/migracion-peru/testeando-peru/dominios/$domain/";
    my $user_dir_path = $mailbox_base_dir.uc(substr $user,0,1)."/".$users_name{$user}."/";

    # En caso de no existir el directorio logea y siguiente
    if ( ! -d $user_dir_path ) {
      print LOGINVALIDDIR "$user - $user_dir_path\n";
      next;
    }
else {
open TEST,"> test.log";
print TEST "$user - $user_dir_path\n";
close TEST;
}
next;
    my $user_log_file = '';
    my @folders = ();
    # la clave sera el nombre original del folder y el valor de la clave sera
    # el nombre con el que se creara esa carpeta en el servidor
    my %final_folders = %base_folders;
    my $imapcon; # conexion con el servidor IMAP
    my @user_files = (); # ficheros dentro del mailbox del usuario
    my @smtp_user_files = (); # mensajes de correo a almacenar
    my @junk_files = (); # ficheros que no son entendidos como mensajes de correo

    # Fichero de log para el usuario
    $user_log_file = lc($user).".log";

    # logeamos el usuario que se esta procesando
    print STD "Procesando usuario $user.\n";

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
    $imapcon = connect_imap($imapServer, $port, $user, $users_pass{$user});

    if ( !defined($imapcon) ) {
      print LOG "ERROR -  No se pudo abrir conexion con el servidor imap $imapServer ($user/$users_pass{$user}).\n";
      next;
    }
    else {
      print USERLOG "OK - $user/$users_pass{$user}\n";
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
      while ( shift(@msg_path) !~ $users_name{$user} ) { ; }
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

      # almacenamos el mensaje de correo en $msg
      open MSG, "< $mailmsg";
      foreach my $line (<MSG>) {
        # Eliminamos los final de linea tipo DOS
        $line =~ s/\r/\n/g;
        $msg = $msg.$line;
      }
      close MSG;
      # Almacenamos el mensaje para que quede el transformado
      # como mensaje original
      open MSG, "+> $mailmsg";
      print MSG "$msg";
      close MSG;

      # determinamos el folder del mensaje
      foreach my $dir ( @msg_path ) {
        if ( $dir =~ /^\.\w/ ) {
          # el mensaje pertenece a un folder distinto del INBOX
          $tofolder = $tofolder.$dir;
          last;
        }
      }

      # almacenamos el mensaje
      my $uid = $imapcon->append_string($final_folders{$tofolder}, $msg, $msg_flags);
        if ( !defined($uid) ) {
          print USERLOG "ERROR - $mailmsg\n";
        }
        else {
          print USERLOG "OK - $mailmsg\n";
        }

    }

    # cerramos y comprimimos el fichero de log de usuarios
    $imapcon->disconnect;
    print USERLOG "OK - Se cerro la conexion con el usuario $user.\n";
    close USERLOG;
    `gzip -f $user_log_file`;

  }

  # cerramos y comprimimos el log generico
  close LOG;
  `gzip -f $domain-$general_log`;

  # cerramos y comprimimos el log de las direcciones de correo
  close LOGINVALIDDIR;
  `gzip -f $domain-$invalid_dir_log`;

  # cerramos la salida estandar y la comprimimos
  close STD;
  `gzip -f $domain-$std_log`;

  # cerramos y comprimimos el log de la salida estandar de errores
  close STDERR;
  `gzip -f $domain-$stderr_log`;

  # cerramos la conexion con la BBDD
  $dbh->disconnect;
  close BBDDLOG;

}

# cerramos el fichero de log y lo comprimimos
`gzip -f $bbdd_log`;
