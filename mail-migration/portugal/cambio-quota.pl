#!/usr/bin/perl -w

# cambio de quotas

use strict;

use DBI;

my $server_target = 'ip';
my $bbdd_target   = 'postfixdb';
my $user_target   = 'password';
my $pwd_target    = 'jakarta';

# conexion con la BBDD donde se va a migrar
my $dsn_target      = "DBI:mysql:".$bbdd_target.":".$server_target;
my $dbh_target      = DBI->connect($dsn_target,$user_target,$pwd_target);
my $query_target    = '';
my $update_query    = '';

my $quota    = "45600000S";
my $quota_n  = $quota;

my $base_dir = '/var/spool/mailbox/';
my $maildir  = "";
my $res      = "";

# usuarios a los que hay que cambiar la quota de disco
my $datos_usuarios = "usuarios-overcuota-pt.log"; 

my $uid = 5000;
my $gid = 5000;

my $log_file = "cambio-quota.log";

open LOG, " > $log_file";
open USUARIOS,"< $datos_usuarios" or die;

$quota_n =~ s/S//g;

# insertamos los usuarios
foreach my $user ( <USUARIOS> ) {
  chomp($user);
  print LOG "OK - $user\n";
  $query_target = $dbh_target->prepare(qq{SELECT maildir FROM mailbox WHERE username="$user"});
  $query_target->execute();
  $update_query = $dbh_target->do("UPDATE mailbox SET quota=\"$quota_n\" WHERE username=\"$user\"");

  $res = $query_target->fetchrow_array();  
  next if ! defined($res);

  $maildir = $base_dir.$res;
  # borramos la papelera
  system "find $maildir.Trash -name \"*backup*\" | xargs -n 1 rm -f" if -d $maildir.".Trash";
  system "maildirmake -q $quota $maildir" if -d $maildir; 
  system "chown mailbox. $maildir/maildirsize";
}

close USUARIOS;
close LOG;

# cerramos la conexion con la BBDD a donde estamos migrando
#$dbh_target->disconnect;
