#!/usr/bin/perl -w

use strict;
use DBI;

use PersonalPerlLibrary::Mail;

my $mysql_server_prod = 'ip';
my $mysql_user_prod   = 'postfix';
my $mysql_pass_prod   = '';

my $mysql_server_pre = 'localhost';
my $mysql_user_pre   = 'root';
my $mysql_pass_pre   = 'password';

my $mysql_target_db = 'postfixdb'; # BBDD en la que se almacenaran los datos     
my $mysql_source_db = 'mailCompartidoCL'; # BBDD de la que se cogeran los datos

my %domains  = ();
my $quota    = '10240000';
my $password = 'password';
my $usuario  = '';
my $domain   = '';
my $maildir  = '';
my $email    = '';

my @usuarios = ();

my $logfile = 'bbdd-chile-no-migrados.log';

# conexion con la BBDD de produccion
my $dsn_target = "DBI:mysql:".$mysql_target_db.":".$mysql_server_prod;
my $dbh_target = DBI->connect($dsn_target,$mysql_user_prod,$mysql_pass_prod);
my $sth_target = '';

# conexion con la BBDD de preproduccion
my $dsn_source = "DBI:mysql:".$mysql_source_db.":".$mysql_server_pre;
my $dbh_source = DBI->connect($dsn_source,$mysql_user_pre,$mysql_pass_pre);
my $sth_source = '';

# Dominios
$domains{'maildomain1'} = 'description';
$domains{'maildomain2'} = 'description';

# Insertamos la informacion relativa a los dominios
foreach (keys %domains) {
  $sth_target = $dbh_target->do("INSERT INTO domain (domain,description,aliases,mailboxes,maxquota,transport,created,modified,active) VALUES (\"$_\",\"$domains{$_}\",\"0\",\"0\",\"100\",\"virtual\",now(),now(),\"1\")");
}

# Extraemos todos los usuarios del dominio
$sth_source = $dbh_source->prepare(qq{SELECT email,quota FROM postfix_users});
$sth_source->execute();

open LOGFILE,"> $logfile" or die "Error al abrir el fichero $logfile.\n";
print LOGFILE "Usuarios no migrados de la BBDD del correo de Chile\n\n";

# Insertamos en la BBDD
while ( my $item = $sth_source->fetchrow_hashref() ) {
  next if !defined($$item{'email'});
  next if $$item{'email'} eq '';
  if ( validate_email($$item{'email'}) != 0 ) {
    print LOGFILE "$$item{'email'}\n";
    next;
  }

  $email = lc($$item{'email'});
  ($usuario,$domain) = (split /@/,$email);
  #$quota =~ s/\$\$item{'quota'}/S/g;
  $quota = 52428800;
  push @usuarios,$email;
  $maildir = "cl/$domain/".lc(substr($$item{'email'},0,1))."/".lc(substr($$item{'email'},0,2))."/".$usuario."/";
  $sth_target = $dbh_target->do("INSERT INTO mailbox (name,password,username,quota,maildir,domain,created,modified,lastlogin,logincount,active) VALUES (\"$usuario\",\"$password\",\"$email\",\"$quota\",\"$maildir\",\"$domain\",now(),now(),now(),\"0\",\"1\")");
}
$sth_source->finish(); # terminamos la consulta

# 
foreach (@usuarios) {
    my @goto = ();
    ($usuario,$domain) = (split /@/,$email);
    # Si existe entrada en la original sustituimos $goto
    $sth_source = $dbh_source->prepare(qq{SELECT destination FROM postfix_virtual WHERE email=\'$_\'});
    $sth_source->execute();
    @goto = $sth_source->fetchrow_array;
    $goto[0] = $_ if  $#goto == -1;
    $sth_target = $dbh_target->do("INSERT INTO alias (address,goto,domain,created,modified,active) VALUES (\"$_\",\"$goto[0]\",\"$domain\",now(),now(),\"1\")");
}

$dbh_target->disconnect;
$dbh_source->disconnect;
