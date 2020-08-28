#!/usr/bin/perl -w

# script para la migracion de la BBDD de spain

use strict;

use DBI;
use PersonalPerlLibrary::Mail;

my $server_src = 'localhost';
my $bbdd_src   = 'usuariosES';
my $user_src   = 'postfix';
my $pwd_src    = 'password';

my $server_target = 'localhost';
my $bbdd_target   = 'postfixdb';
my $user_target   = 'postfix';
my $pwd_target    = 'password';

# conexion con la BBDD a migrar
my $dsn_src      = "DBI:mysql:".$bbdd_src.":".$server_src;
my $dbh_src      = DBI->connect($dsn_src,$user_src,$pwd_src);
my $query_src    = '';

# conexion con la BBDD donde se va a migrar
my $dsn_target      = "DBI:mysql:".$bbdd_target.":".$server_target;
my $dbh_target      = DBI->connect($dsn_target,$user_target,$pwd_target);
my $query_target    = '';

my @usuarios = ();
my @domains  = ( "maildomain1", "maildomain2", "maildomain3");

my %tmp = ();

my @result_query = ();
my @lastlogin = ();

my $maildir  = "";
my $password = "password";
my $quota    = "10240000";
my $dump_file = 'emails.txt';

my $base_dir = '/var/spool/mailbox/';

my $uid = 5000;
my $gid = 5000;

# se utilizaran en el proceso del fichero /etc/postfix/canonical
my $email_src    = ''; # direccion de correo @maildomain (a modificar)
my $email_target = ''; # direccion de correo @xxx.maildomain (direccion final)
my $domain       = ''; # dominio del usuario

my $log_invalid_email = 'migracion-spain-invalid-email.log';
my $log               = 'migracion-spain.log';

# abrimos ficheros de log
open LOGINVALIDEMAIL,"> $log_invalid_email";

# abrimos el fichero y sacamos los usuarios de correo
open FILE,"< $dump_file";

foreach my $line ( <FILE> ) {
  chomp($line);
  $line = (split /[\t ]+/,$line)[1];
  if ( validate_email($line) eq 0 ) {
    my $domain = lc((split /\@/,$line)[1]);
    push @usuarios,$line if grep /^$domain$/, @domains;
  }
  else {
    print LOGINVALIDEMAIL "ERROR - $line\n";
  }
}

close FILE;

# cerramos fichero
close LOGINVALIDEMAIL;

# eliminamos las entradas duplicadas de usuarios
%tmp   = map { $_, 1 } @usuarios;
@usuarios = keys %tmp;

# abrimos log general
open LOG,"> $log";

# insertamos los dominios
foreach my $domain ( @domains ) {
  $#result_query = -1;
  $query_target = $dbh_target->prepare(qq{SELECT domain FROM domain WHERE domain="$domain"});
  $query_target->execute();
  while ( my $item = $query_target->fetchrow_array() ) {
    push @result_query, $item;
  }

  # Si el dominio no existe lo insertamos
  if ( $#result_query == -1 ) {
    $query_target = $dbh_target->do("INSERT INTO domain (domain,description,aliases,mailboxes,maxquota,transport,created,modified,active) VALUES (\"$domain\",\"\",\"0\",\"0\",\"100\",\"virtual\",now(),now(),\"1\")");
    # verificacion de error
    if ( defined($query_target) ) {
      print LOG "OK - Insertado el dominio $domain en la BBDD.\n";
    }
    else {
      print LOG "ERROR - Insertando el dominio $domain en la BBDD.\n";
    }
  }
}

# insertamos los usuarios
foreach my $user ( @usuarios ) {
  my ($login,$domain) = (split /\@/,$user)[0,1];
  my $goto = '';
  $domain = lc($domain);

  $#result_query = -1;
  $query_target = $dbh_target->prepare(qq{SELECT username FROM mailbox WHERE username="$user"});
  $query_target->execute();
  while ( my $item = $query_target->fetchrow_array() ) {
    push @result_query, $item;
  }

  # Si el usuario no existe lo insertamos
  if ( $#result_query == -1 ) {
    $maildir = "es/$domain/".lc(substr($user,0,1))."/".lc(substr($user,0,2))."/".(split(/\@/,$user))[0]."/";
    }
  else {
    print LOG "ERROR - Insertando el usuario $user en la BBDD.\n";
    next;
  }

  # alias del usuario
  $goto = $user;

  # atacamos la BBDD original para extraer los alias
  $#result_query = -1;
  $#lastlogin    = -1;
  $query_src = $dbh_src->prepare(qq{SELECT dest,lastlogin FROM virtual WHERE alias="$login"});
  $query_src->execute();
  while ( my $item = $query_src->fetchrow_hashref() ) {
    push @result_query, $$item{'dest'};
  }

  # procesamos los alias
  if ( $#result_query == 0 ) {
    $result_query[0] =~ s/;/,/g;
    $result_query[0] =~ s/,[\t ]*/, /g;
    $result_query[0] =~ s/$login,/$user,/g;
    $result_query[0] =~ s/.*mailforwardingaddress=(\.*)/$1/g;

    # eliminamos las direcciones de correo que no esten bien formadas
    foreach ( split /, /,$result_query[0] ) {
      $result_query[0] =~ s/$_,* *//g if validate_email($_) ne 0;
    }
    $result_query[0] =~ s/, *$//g;
    $goto = $result_query[0];
  }

  $query_src = $dbh_src->prepare(qq{SELECT dest,lastlogin FROM virtual WHERE alias="$user"});
  $query_src->execute();
  while ( my $item = $query_src->fetchrow_hashref() ) {
    push @lastlogin, $$item{'lastlogin'};
  }

  $lastlogin[0] = 0 if !(defined($lastlogin[0]));

  # insertamos los datos en la BBDD
  $query_target = $dbh_target->do("INSERT INTO mailbox (name,password,username,quota,maildir,domain,created,modified,lastlogin,logincount,active) VALUES (\"$login\",\"$password\",\"$user\",\"$quota\",\"$maildir\",\"$domain\",now(),now(),\"$lastlogin[0]\",\"0\",\"1\")");
  # verificacion de error
  if ( defined($query_target) ) {
    print LOG "OK - Insertado el usuario $user en la BBDD.\n";
    # insertamos el alias
    $query_target = $dbh_target->do("INSERT INTO alias (address,goto,domain,created,modified,active) VALUES (\"$user\",\"$goto\",\"$domain\",now(),now(),\"1\")");
    # verificacion de error
    if ( defined($query_target) ) {
      my $userdir   = $base_dir.$maildir;
      my $quotafile = $userdir."maildirsize"; 
      my $quota     = "20480000S";

      print LOG "OK - Insertado el alias $goto para $user en la BBDD.\n";
      # creamos el directorio de spool para el usuario
      print LOG "OK - Creando el mailbox $userdir\n";
      create_user_spool_dir($userdir,700,755,$uid,$gid);
      # generamos la cuota del usuario
      print LOG "OK - Generando la cuota de $user.\n";
      system "maildirmake -q $quota $userdir";
      system "chown $uid:$gid $quotafile";

    }
    else {
      print LOG "ERROR - Insertanto el alias $goto para $user en la BBDD.\n";
    }
  }
  else {
    print LOG "ERROR - Insertando el usuario $user en la BBDD.\n";
  }

}

# cerramos la conexion con la BBDD a migrar
$dbh_src->disconnect;

# cerramos la conexion con la BBDD a donde estamos migrando
$dbh_target->disconnect;

# Cerramos ficheros de log
close LOG;

# cambiamos el propietario
my $dir = $base_dir."es/";
system "chown -R $uid:$gid $dir";
