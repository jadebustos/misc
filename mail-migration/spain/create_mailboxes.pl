#!/usr/bin/perl -w

# script para la migracion de la BBDD de spain

use strict;

use DBI;
use PersonalPerlLibrary::Mail;

my $server_src = 'ip';
my $bbdd_src   = 'postfixdb';
my $user_src   = 'password';
my $pwd_src    = 'jakarta';

# conexion con la BBDD a migrar
my $dsn_src      = "DBI:mysql:".$bbdd_src.":".$server_src;
my $dbh_src      = DBI->connect($dsn_src,$user_src,$pwd_src);
my $query_src    = '';

my %usuarios = ();
my @domains  = ( "maildomain1", "maildomain2", "maildomain3");

my $quota    = "20480000S";
my $uid      = 5000;
my $gid      = 5000;

my $base_dir = '/var/spool/mailbox/';

my $log               = 'creacion-mailboxes.log';

# abrimos log general
open LOG,"> $log";

# extraemos los usuarios

foreach my $domain ( @domains ) {

  $query_src = $dbh_src->prepare(qq{SELECT username,maildir FROM mailbox WHERE domain LIKE "%maildomain" AND username LIKE "m%"});
  $query_src->execute();
  while ( my $item = $query_src->fetchrow_hashref() ) {
    $usuarios{$$item{'username'}} = $base_dir.$$item{'maildir'};
  }

}

# cerramos la conexion con la BBDD a donde estamos migrando
$dbh_src->disconnect;

# creamos los directorios

foreach my $user ( keys %usuarios ) {
  create_user_spool_dir($usuarios{$user},700,755,$uid,$gid);
  # generamos la cuota del usuario
  print LOG "OK - Generando la cuota de $user.\n";
  system "maildirmake -q $quota $usuarios{$user}";
}

# Cerramos ficheros de log
close LOG;

# cambiamos el propietario
my $dir = $base_dir."es/";
system "chown -R $uid:$gid $dir";
