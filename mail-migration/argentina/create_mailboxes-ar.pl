#!/usr/bin/perl -w

use strict;

use DBI;
use PersonalPerlLibrary::Mail;

my $mysql_server = 'ip';
my $mysql_user   = 'postfix';
my $mysql_pass   = 'password';
my $mysql_db     = 'postfixdb';

my $base_dir = '/var/spool/mailbox/';

my $domain = 'maildomain';
my $prefix = 'ar';

my $logfile = "create_mailboxes-".$domain.".log";

my $uid = 'mailbox';
my $gid = 'mailbox';

my @dirs; # Directorios a crear
my @folders = ("INBOX.Spam", "INBOX.Enviados", "INBOX.Borradores", "INBOX.Trash");
my %users_p; # passwords
my %users_q; # quotas
my %users_d; # directorios

my $imapcon = '';

# conexion con la BBDD
my $dsn = "DBI:mysql:".$mysql_db.":".$mysql_server;
my $dbh = DBI->connect($dsn,$mysql_user,$mysql_pass);

# Extraemos todos los usuarios del dominio
my $sth = $dbh->prepare(qq{SELECT username,password,maildir,quota FROM mailbox WHERE domain = "$domain"});
$sth->execute();
while ( my $item = $sth->fetchrow_hashref() ) {
  push @dirs,$base_dir.$$item{'maildir'} if ! -d $base_dir.$$item{'maildir'};
  $users_p{$$item{'username'}} = $$item{'password'};
  $users_q{$$item{'username'}} = $$item{'quota'}."S";
  $users_d{$$item{'username'}} = $base_dir.$$item{'maildir'};
}
$sth->finish(); # terminamos la consulta

$dbh->disconnect;

open LOG,"> $logfile";

foreach (@dirs) {
  print LOG "Creando el mailbox $_\n";
  create_user_spool_dir($_,700,755,$uid,$gid);
}

system "chown -R $uid:$gid $base_dir/$prefix";

foreach ( keys %users_d) {
  print LOG "Generando cuota de $_.\n";
  system "maildirmake -q $users_q{$_} $users_d{$_}";
  system "chown mailbox:mailbox $users_d{$_}maildirsize";
}

close LOG;
