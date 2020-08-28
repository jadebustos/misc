#!/usr/bin/perl -w

# busca mensajes duplicados basandose en el msgid

use strict;
use DBI;

use PersonalPerlLibrary::FS;
use PersonalPerlLibrary::Mail;

my @mensajes = ();

my $mysql_server = 'ip';
my $mysql_user   = 'postfix';
my $mysql_pass   = 'password';
my $mysql_db     = 'postfixdb';

my $domain   = 'maildomain';
my $base_dir = '/var/spool/mailbox/';

my %users;

# conexion con la BBDD
my $dsn = "DBI:mysql:".$mysql_db.":".$mysql_server;
my $dbh = DBI->connect($dsn,$mysql_user,$mysql_pass);

# Extraemos todos los usuarios a comprobar
my $sth = $dbh->prepare(qq{SELECT username,maildir FROM mailbox WHERE domain = "$domain" AND name like 'e%'});
$sth->execute();
while ( my $item = $sth->fetchrow_hashref() ) {
  $users{$$item{'username'}} = $base_dir.$$item{'maildir'};
}
$sth->finish(); # terminamos la consulta

$dbh->disconnect;

foreach my $user ( keys %users ) {
  my %msgid;
  my @duplicate_msg = ();
  # obtenemos los mensajes de los usuarios
  @mensajes = get_mail_msgs_from_dir($users{$user});

  # la clave es el path del mensaje y el valor es el msgid del mensaje
  foreach ( @mensajes ) {
    $msgid{$_} = get_msgid($_);
  }

  # localizamos los repetidos
  foreach my $msg_id ( keys %msgid ) {
    foreach my $msg_id_inner ( keys %msgid ) {
      next if $msg_id eq $msg_id_inner;
      push @duplicate_msg,$msg_id." - ".$msg_id_inner if $msgid{$msg_id} eq $msgid{$msg_id_inner};
    }
  }

  next if $#duplicate_msg == -1;

  open LOGUSER,"> msgs-$user.log";
  $,="\n";
  print LOGUSER @duplicate_msg;
  close LOGUSER;

}
