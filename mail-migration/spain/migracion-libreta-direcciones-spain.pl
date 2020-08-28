#!/usr/bin/perl -w

# script para la migracion de la BBDD de spain

use strict;

use DBI;
use PersonalPerlLibrary::Mail;

my $server_src = 'ip';
my $bbdd_src   = 'libretasES';
my $user_src   = 'postfix';
my $pwd_src    = 'password';

my $server_target = 'ip';
my $bbdd_target   = 'squirreldb_es';
my $user_target   = 'postfix';
my $pwd_target    = 'password';

my $server_check = 'ip';
my $bbdd_check   = 'postfixdb';
my $user_check   = 'postfix';
my $pwd_check    = 'password';

# conexion con la BBDD a migrar
my $dsn_src   = "DBI:mysql:".$bbdd_src.":".$server_src;
my $dbh_src   = DBI->connect($dsn_src,$user_src,$pwd_src);
my $query_src = '';

# conexion con la BBDD donde se va a migrar
my $dsn_target      = "DBI:mysql:".$bbdd_target.":".$server_target;
my $dbh_target      = DBI->connect($dsn_target,$user_target,$pwd_target);
my $query_target    = '';

# conexion con la BBDD de postfix
my $dsn_check   = "DBI:mysql:".$bbdd_check.":".$server_check;
my $dbh_check   = DBI->connect($dsn_check,$user_check,$pwd_check);
my $query_check = '';

my @usuarios = ();

my $log               = 'migracion-libreta-direcciones-spain.log';

open LOG, "> $log";

# migramos tabla address

$query_src = $dbh_src->prepare(qq{SELECT * FROM address});
$query_src->execute();

while ( my $item = $query_src->fetchrow_hashref() ) {
  # sino existe un registro en la tabla address del destino con el mismo 
  # valor que nickname insertamos el registro
  my $insert_query = "";
  my $check_query = "SELECT username FROM mailbox WHERE username LIKE '$$item{'owner'}\@%maildomain'";
  $check_query =~ s/_/\\_/g;
  $query_check = $dbh_check->prepare($check_query);
  $query_check->execute();
  $$item{'nickname'} =~ s/"/\\"/g;
  $$item{'firstname'} =~ s/"/\\"/g;
  $$item{'lastname'} =~ s/"/\\"/g;
  $$item{'email'} =~ s/"/\\"/g;
  $$item{'label'} =~ s/"/\\"/g;
  while ( my $item_check = $query_check->fetchrow_array ) {
    $insert_query = "INSERT INTO address (owner,nickname,firstname,lastname,email,label) VALUES (\"$item_check\",\"$$item{'nickname'}\",\"$$item{'firstname'}\",\"$$item{'lastname'}\",\"$$item{'email'}\",\"$$item{'label'}\")";
    $query_target = $dbh_target->do($insert_query);
    print LOG "Inserccion address (Primera)\n" if defined($query_target);
  }
}

# migramos la tabla addressgroups

$query_src = $dbh_src->prepare(qq{SELECT * FROM addressgroups});
$query_src->execute();

while ( my $item = $query_src->fetchrow_hashref() ) {
  # sino existe un registro en la tabla address del destino con el mismo
  # valor que nickname insertamos el registro
  my $insert_query = "";
  my $check_query = "SELECT username FROM mailbox WHERE username LIKE '$$item{'owner'}\@%maildomain'";
  $check_query =~ s/_/\\_/g;
  $query_check = $dbh_check->prepare($check_query);
  $query_check->execute();
  while ( my $item_check = $query_check->fetchrow_array ) {
    # en caso de no existir entrada en mailbox no se migra el registro
    $insert_query = "INSERT INTO addressgroups (owner,nickname,addressgroup,type) VALUES (\"$item_check\",\"$$item{'nickname'}\",\"$$item{'addressgroup'}\",\"$$item{'type'}\")";
    $query_target = $dbh_target->do($insert_query);
    print LOG "Inserccion addressgroup (Segunda)\n" if defined($query_target);
  }
}

# cerramos la conexion con la BBDD a migrar
$dbh_src->disconnect;

# cerramos la conexion con la BBDD a donde estamos migrando
$dbh_target->disconnect;

close LOG;
