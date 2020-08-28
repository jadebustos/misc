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

use strict;

use DBI;
use PersonalPerlLibrary::FS;
use PersonalPerlLibrary::Mail;

my $base_dir = "/var/spool/mailbox/";

my $mysql_server = "ip";
my $mysql_user   = "postfix";
my $mysql_pass   = "password";
my $mysql_db     = "postfixdb";

if ( $#ARGV == -1 ) {
   print "Uso:\tperl imap2imap-chile.pl domain1 domain1 ...\n";
   exit 0;
}


for my $domain ( @ARGV ) {

  # clave usuario, valor maildir
  %users = ();

  # conexion con la BBDD
  my $dsn = "DBI:mysql:".$mysql_db.":".$mysql_server;
  my $dbh = DBI->connect($dsn,$mysql_user,$mysql_pass);

  # obtenemos los usuarios del dominio
  my $sth = $dbh->prepare(qq{SELECT username,maildir FROM mailbox WHERE domain = "$domain"});
  $sth->execute();
  while ( my $item = $sth->fetchrow_hashref() ) {
    $users{$$item{'username'}} = $base_dir.$$item{'maildir'};
  }
  $sth->finish(); # terminamos la consulta

  # cerramos la conexion con la BBDD
  $dbh->disconnect;

  foreach my $user ( keys %users ) {
    my @user_files = get_files_from_directory($users{$user});
    my @smtp_user_files = ();

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
    }

    foreach my $smtpmsg ( @smtp_user_files ) {

      my $this_msg_user = '';
      my $tofolder = get_folder_from_filename($smtpmsg);
      $tofolder =~ s/^\.//g;

      # verificamos que el destinatario de este mensaje es el mismo que el
      # propietario del mailbox
      if ( $tofolder eq "Enviados" ) {
        $this_msg_user = get_email_from_sent_file($mailmsg);
      }
      elsif ( $tofolder eq "Borradores" ) {
        $this_msg_user = get_email_from_draft_file($mailmsg);
      }
      else {
        $this_msg_user = get_email_from_file($mailmsg);
      }

     if ( $this_msg_user ne $user ) {
       open LOGUSER,">> $user.log";
       print LOGUSER "$smtpmsg\n";
       close LOGUSER;
     }

    }
  }
}
