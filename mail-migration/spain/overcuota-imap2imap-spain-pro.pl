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

use strict;

use DBI;
use Time::Local;

use PersonalPerlLibrary::FS;
use PersonalPerlLibrary::Mail;

my $imapServer="ip";
my $port=1430;
my $password="";

# ficheros de log

my $stderr_log         = "errores-overcuota-spain.log";
my $std_log            = "std-out-spain.log";
my $general_log        = "migracion-spain.log";

my $base_dir = "/var/spool/mailbox/migracion-spain/";
my $mail_dir = '';

# carpetas que han de tener al crear las cuentas
my %base_folders = ( "INBOX"     , "INBOX",
                     "Enviados"  , "INBOX.Enviados",
                     "Papelera"  , "INBOX.Trash", 
                     "Spam"      , "INBOX.Spam",
                     "Borradores", "INBOX.Borradores");

my %usuarios    = ();
my %directorios = ();

my @folders = (); # Folders a crear para los usuarios

# se utilizaran para convertir todas estas carpetas a las estandar
my @enviados_alias   = ("INBOX.Sent");
my @spam_alias       = ("INBOX.Spam");
my @borradores_alias = ("INBOX.Drafts");
my @papelera_alias   = ("INBOX.Papelera");

my $mysql_server = "ip";
my $mysql_user   = "postfix";
my $mysql_pass   = "password";
my $mysql_db     = "postfixdb";

my $user_pwd = $password;

my $imapcon;

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

my $day;
my $month;
my $year;
my $file_date;
my $hour;
my $min;
my $sec;

# los correos anteriores a esta fecha se marcaran como leidos y los posteriores como no leidos
my $start_migration_date_year  = 2007;
my $start_migration_date_month = 6;
my $start_migration_date_day   = 6;

my $mail_date_year  = '';
my $mail_date_month = '';
my $mail_date_day   = '';

# abrimos logs
open STDERR,          "> $stderr_log";
open STD,             "> $std_log";

# conexion con la BBDD
my $dsn = "DBI:mysql:".$mysql_db.":".$mysql_server;
my $dbh = DBI->connect($dsn,$mysql_user,$mysql_pass);

open OVERCUOTA,"< usuarios.overcuota.log";

foreach my $user ( <OVERCUOTA> ) {
  chomp($user);
  $usuarios{$user} = 'password';
}
 
open LOG, "> $general_log";

foreach my $user ( keys %usuarios ) {
  my $domain = lc((split /\@/,$user)[1]);
  my @correos = ();
  $#folders = -1;

  foreach ( values %base_folders ) {
    push @folders,$_;
  }

  # abrimos conexion con el servidor imap
 $imapcon = connect_imap($imapServer, $port, $user, $usuarios{$user});

  if ( !defined($imapcon) ) {
    print LOG "ERROR -  No se pudo abrir conexion con el servidor imap $imapServer ($user/$usuarios{$user}).\n";
    next;
  }
  else {
    open USERLOG, "> $user.overcuota.log";
    print USERLOG "OK - $user/$usuarios{$user}\n";
  }

  # abrimos el fichero de log y procesamos los que esten con error
  my $status = open OVERCUOTA, "< logs/$user.log";

  if ( ! defined($status) ) {
    print USERLOG "ERROR - No se pudo abrir el fichero de log.\n";
    next;
  }

  my $tmp= '';

  # consideramos solo los correos que no se migraron
  foreach my $line ( <OVERCUOTA> ) {
    next if $line !~ /^ERROR/;
    $tmp = (split / - /,$line)[1];
    chomp($tmp);
    push @correos,$tmp;
  }
  close OVERCUOTA;

  foreach my $mail ( @correos ) {
    my @tmp = split /\//,$mail;
    my $login = lc((split /\@/,$user)[0]);
    my $msg = '';
    my $msg_date = '';
    my $fecha = '';
    my $msg_flags = '\\Seen';
    my $control = 0;
    next if $tmp[$#tmp] !~ /^\d+\.$/; 
    # obtenemos el folder del mensaje
    my $folder = $mail;
    $folder =~ s/^\/var.*\/user\/(.+)\/\d*\./$1/g;
    $folder =~ s/$login/INBOX/g;
    $folder =~ s/\//\./g;
    $#folders = -1;
    push @folders,$folder;

    open MAIL, "< $mail";
    foreach ( <MAIL> ) {

      # Recogemos la informacion horaria
      if ( $_ =~ /^D[a|A][t|T][e|E]:/ && $control == 0 ) {
        $_ =~ s/[\+|-].+$/\+0100/g;
        $fecha = $_;
        $fecha =~ s/[A-Z][a-z][a-z],[ \t]+//g;

        # obtenemos la fecha
        if ( $msg_date eq "" && $_ =~ /[Mon|Tue|Wed|Thu|Fri|Sat|Sun], \d{1,2} [Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec]/ ) {
          my $tmpdate = $_;
          my $day;
          my $month;
          my $year;

          $tmpdate =~ s/.*(\w{3}, \d{1,2} \w{3} .{4}).*/$1/g;
          $msg_date = $tmpdate;
          chomp($msg_date);
          $day   = $msg_date;
          $month = $msg_date;
          $year  = $msg_date;
          $day   =~ s/(\w{3}), (\d{1,2}) (\w{3})(.{5})/$2/g;
          $month =~ s/(\w{3}), (\d{1,2}) (\w{3})(.{5})/$3/g;
          $year  =~ s/(\w{3}), (\d{1,2}) (\w{3})(.{5})/$4/g;
          $year  =~ s/[\t ]*//g;
 
          # preparamos la fecha para la comprobacion de los flags
          $mail_date_year  = $year;
          $mail_date_month = $months{$month};
          $mail_date_month =~ s/^0(\d)/$1/g;
          $mail_date_day   = $day; 
          $mail_date_day   =~ s/^0(\d)/$1/g;

          $day = "0".$day if length($day) == 1;
          $msg_date = $year.$months{$month}.$day;
        }

        $control = 1;
      }

      $msg = $msg.$_;
    }

    if ( $mail_date_year >= $start_migration_date_year && $mail_date_month >= $start_migration_date_month && $mail_date_day >= $start_migration_date_day ) {
      $msg_flags = "";
    }

    # almacenamos el mensaje
    if ( ! $imapcon->exists($folder) ) {
      create_imap_folders(\@folders, $imapcon);
      $imapcon->subscribe($folder);
      print USERLOG "OK - Suscrito al folder $folder\n";
    }

    next if $folder =~ /Papelera$/;
    chomp($fecha);
    my $uid = $imapcon->append_file($folder, $mail);
    if ( !defined($uid) ) {
      print USERLOG "ERROR - $mail\n";
     }
     else {
       print USERLOG "OK - $mail\n";
     }

    close MAIL;
  }
  
  # cerramos el fichero de log del usuario
  close USERLOG;

  # cerramos conexion con el servidor imap
  $imapcon->disconnect;
}

# cerramos logs
close LOG;
`gzip -f $general_log`;

close STDERR;
`gzip -f $stderr_log`;

close STD;
`gzip -f $std_log`;
