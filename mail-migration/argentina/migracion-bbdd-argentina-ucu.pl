#!/usr/bin/perl -w

use strict;
use DBI;
use PersonalPerlLibrary::Mail;

my $mysql_server_source = 'localhost';
my $mysql_user_source   = 'root';
my $mysql_pass_source   = 'password';

my $mysql_server_target = 'ip';
my $mysql_user_target   = 'postfix';
my $mysql_pass_target   = 'password';

my $mysql_target_db = 'postfixdb';
my $mysql_source_db = 'usuario';

my $quota    = '10240000';
my $password = 'password';
my $domain   = 'maildomain';
my %email    = ();
my %alias    = ();
my %maildir  = ();

# conexion con la BBDD
my $dsn_target = "DBI:mysql:".$mysql_target_db.":".$mysql_server_target;
my $dbh_target = DBI->connect($dsn_target,$mysql_user_target,$mysql_pass_target);
my $sth_target = '';

my $dsn_source = "DBI:mysql:".$mysql_source_db.":".$mysql_server_source;
my $dbh_source = DBI->connect($dsn_source,$mysql_user_source,$mysql_pass_source);
my $sth_source = '';

open MAILDIR, "> maildir.log";
open ALIAS, "> alias.log";
# Extraemos todos los usuarios del dominio
$sth_source = $dbh_source->prepare(qq{SELECT usuario,email,mailfwd FROM usuarios WHERE email LIKE '%\@maildomain%'});
$sth_source->execute();
while ( my $item = $sth_source->fetchrow_hashref() ) {
  next if !defined($$item{'email'});
  next if $$item{'email'} !~ "@";
  $$item{'email'} =~ s/"//g;
  next if validate_email($$item{'email'});
  my $usuario = (split /@/,$$item{'email'})[0];
  $usuario =~ s/"//g;
  $email{$$item{'email'}} = $$item{'email'};
  $maildir{$$item{'email'}} = "ar/$domain/".lc(substr($usuario,0,1))."/".lc(substr($usuario,0,2))."/".$usuario."/";
  $$item{'mailfwd'} = $$item{'email'} if ! defined($$item{'mailfwd'});
  my $validation = validate_email($$item{'mailfwd'});
  if ( $validation ne 0 ) {
    $alias{$$item{'email'}} = $$item{'email'};
  }
  else {
    $alias{$$item{'email'}} = $$item{'mailfwd'};
  }
  $alias{$$item{'email'}} =~ s/"//g;
print MAILDIR "$email{$$item{'email'}}: $maildir{$$item{'email'}}\n";
print ALIAS "$email{$$item{'email'}}: $alias{$$item{'email'}}\n";
  $sth_target = $dbh_target->do("INSERT INTO mailbox (name,password,username,quota,maildir,domain,created,modified,lastlogin,logincount,active) VALUES (\"$usuario\",\"$password\",\"$email{$$item{'email'}}\",\"$quota\",\"$maildir{$$item{'email'}}\",\"$domain\",now(),now(),now(),\"0\",\"1\")");
  $sth_target = $dbh_target->do("INSERT INTO alias (address,goto,domain,created,modified,active) VALUES (\"$email{$$item{'email'}}\",\"$alias{$$item{'email'}}\",\"$domain\",now(),now(),\"1\")");   
}
$sth_source->finish(); # terminamos la consulta

$dbh_target->disconnect;
$dbh_source->disconnect;

close MAILDIR;
close ALIAS;
