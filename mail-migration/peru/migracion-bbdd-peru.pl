#!/usr/bin/perl -w

use strict;
use DBI;

my $mysql_server = 'ip';
my $mysql_user   = 'postfix';
my $mysql_pass   = 'password';

my $mysql_target_db = 'postfixdb';
my $mysql_source_db = 'registro';

my $domain   = 'domainmail';
my $quota    = '10240000';
my $password = 'password';
my $usuario  = '';
my $maildir  = '';
my $email    = '';

my @usuarios = ();

# conexion con la BBDD
my $dsn_target = "DBI:mysql:".$mysql_target_db.":".$mysql_server;
my $dbh_target = DBI->connect($dsn_target,$mysql_user,$mysql_pass);
my $sth_target = '';

my $dsn_source = "DBI:mysql:".$mysql_source_db.":".$mysql_server;
my $dbh_source = DBI->connect($dsn_source,$mysql_user,$mysql_pass);
my $sth_source = '';

# Insertamos la informacion relativa al dominio
$sth_target = $dbh_target->do("INSERT INTO domain (domain,description,aliases,mailboxes,maxquota,transport,created,modified,active) VALUES (\"$domain\",\"Correo Peru\",\"0\",\"0\",\"100\",\"virtual\",now(),now(),\"1\")");

# Extraemos todos los usuarios del dominio
$sth_source = $dbh_source->prepare(qq{SELECT usuario,email,cuota FROM datosusu});
$sth_source->execute();
while ( my $item = $sth_source->fetchrow_hashref() ) {
  next if !defined($$item{'email'});
  next if $$item{'email'} eq '';

  $usuario = $$item{'usuario'};
  $quota =~ s/\$\$item{'cuota'}/S/g;
  push @usuarios,$$item{'email'};
  $maildir = "pe/$domain/".lc(substr($$item{'usuario'},0,1))."/".lc(substr($$item{'usuario'},0,2))."/".$usuario."/";
  $email = $$item{'email'};
  $sth_target = $dbh_target->do("INSERT INTO mailbox (name,password,username,quota,maildir,domain,created,modified,lastlogin,logincount,active) VALUES (\"$usuario\",\"$password\",\"$email\",\"$quota\",\"$maildir\",\"$domain\",now(),now(),now(),\"0\",\"1\")");
}
$sth_source->finish(); # terminamos la consulta

# Insertamos en la BBDD
foreach (@usuarios) {
    my @goto = ();
    my $name =(split /\@/,$_)[0];
    # Si existe entrada en la original sustituimos $goto
    $sth_source = $dbh_source->prepare(qq{SELECT mailfwd  FROM mail_fwd WHERE usuario=\'$name\'});
    $sth_source->execute();
    @goto = $sth_source->fetchrow_array;
    $goto[0] = $_ if  $#goto == -1;
    $sth_target = $dbh_target->do("INSERT INTO alias (address,goto,domain,created,modified,active) VALUES (\"$_\",\"$goto[0]\",\"$domain\",now(),now(),\"1\")");
}

$dbh_target->disconnect;
$dbh_source->disconnect;
