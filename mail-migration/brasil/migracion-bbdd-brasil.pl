#!/usr/bin/perl -w

use strict;
use DBI;
use PersonalPerlLibrary::Mail;

my $mysql_server_target = 'localhost';
my $mysql_user_target   = 'postfix';
my $mysql_pass_target   = 'password';

my $mysql_target_db = 'postfixdb';

my $quota    = '51200000';
my $password = 'password';
my $domain   = '';
my $name     = '';
my $maildir  = '';
my $maxquota = '0';

my $dir         = '';
my $base_dir    = '/var/spool/mailbox/';
my $quotaS      = $quota."S";
my $maildirsize = '';

# conexion con la BBDD
my $dsn_target = "DBI:mysql:".$mysql_target_db.":".$mysql_server_target;
my $dbh_target = DBI->connect($dsn_target,$mysql_user_target,$mysql_pass_target);
my $sth_target = '';

foreach my $file ( @ARGV ) {

  my @usuarios = ();

  # dominio que estamos procesando
  $domain = $file;
  $domain =~ s/-txt//g;

  # abrimos fichero de log
  open LOG,"> $domain.log";
  
  # abrimos fichero para coger los usuarios del dominio
  open FILE,"< $file";
  @usuarios = <FILE>;
  close FILE;

  # registramos el dominio en la BBDD
  $sth_target = $dbh_target->do("INSERT INTO domain (domain,description,aliases,mailboxes,maxquota,transport,backupmx,created,modified,active) VALUES (\"$domain\",\"Brasil\",\"0\",\"0\",\"$maxquota\",\"virtual\",\"0\",now(),now(),\"1\")");

  foreach my $user ( @usuarios ) {
    $user =~ s/\n//g;
    my $validation = validate_email($user);

    if ( $validation != 0 ) {
      print LOG "INVALID - $user\n";
      next;
    }
    elsif ( (split /@/,$user)[1] ne $domain ) {
      print LOG "DOMAIN ERROR - $user\n";
      next;
    }

   $name    =  (split /@/,$user)[0];
   $maildir = "br/$domain/".lc(substr($user,0,1))."/".lc(substr($user,0,2))."/".$user."/";

   # insertamos los usuarios en la BBDD
   $sth_target = $dbh_target->do("INSERT INTO mailbox (username,password,crypt,name,maildir,uid,gid,quota,domain,created,modified,lastlogin,logincount,active) VALUES (\"$user\",\"$password\",\"\",\"$name\",\"$maildir\",\"5000\",\"5000\",\"$quota\",\"$domain\",now(),now(),now(),\"0\",\"1\")");

   print LOG "OK - $user\n";
   # Creando mailboxes
   $dir=$base_dir.$maildir;
   $maildirsize= $dir."maildirsize";
   create_user_spool_dir($dir,700,755,5000,5000);
   system "maildirmake -q $quotaS $dir";
   system "chown mailbox:mailbox $maildirsize";

  }
  
  # cerramos fichero de log
  close LOG;

}

$dbh_target->disconnect;
