#!/usr/bin/perl -w

# script para 
# Jose Angel de Bustos Perez <jadebustos@gmail.com>

use strict;
use POSIX;
use DBI;

my $log_file = '/var/log/mysql-queries/';
my $fecha    = '';

my $serverdb = 'ip';
my $userdb   = 'user';
my $passdb   = 'password';
my $db       = '';

my @now_tm   = localtime(); # hora actual en formato tm_time
my $month    = 0;

my @campos = ("Id", "User", "Host", "DB", "Command", "Time", "State", "Info");

my $umbral_process = 500;  # A partir de este numero de procesos se empieza a actuar
my $umbral_locked  = 1000; # segundos para las tablas bloqueadas

my $number_process = 0;

# abrimos conexion con la BBDD
my $dsn   = "DBI:mysql:".$db.":".$serverdb;
my $dbh   = DBI->connect($dsn,$userdb,$passdb);
my $query = '';
my @datos_query = ();

my @mysql_ids = (); # IDs de procesos de mysql a matar

# generacion de fecha
$fecha = $now_tm[5]+1900;

$now_tm[4] += 1;
if ( $now_tm[4] =~ /^\d\d$/ ) {
  $month = $now_tm[4];
}
else {
  $month = "0".$now_tm[4];
}
$fecha = $fecha.$month;

# ponemos el dia con dos digitos
if ( $now_tm[3] =~ /^\d\d$/ ) {
  $fecha = $fecha.$now_tm[3];
}
else {
  $fecha= $fecha."0".$now_tm[3];
}

# fichero de log

$log_file = $log_file."mysql-process-status-$fecha-$now_tm[2]:$now_tm[1]:$now_tm[0].log";

# fin en caso de no poder establecer conexion con la BBDD
if ( ! defined($dbh) ) {
  open LOGFILE,">> $log_file";
  print LOGFILE "[$fecha $now_tm[2]:$now_tm[1]:$now_tm[0]] ERROR - No se pudo iniciar la conexion con la BBDD ($serverdb).\n";
  close LOGFILE;
  exit 1;
}

# listado de procesos
$query = $dbh->prepare(qq{show processlist});
$number_process = $query->execute();

exit 0 if $number_process <= $umbral_process;

open LOGFILE,">> $log_file";

$, = "\t";
print LOGFILE "@campos \n";
while ( my @row = $query->fetchrow_array ) {
    foreach my $item (@row) {
      print LOGFILE "$item * ";
      @datos_query = ($row[0], $row[5], $row[6]);
      push @mysql_ids, $row[0] if $row[6] eq "Locked" and $row[5] gt $umbral_process;
    }
    print LOGFILE "\n";
}

# matamos los procesos de mysql

if ( $#mysql_ids >= 1 ) {
  foreach my $process ( @mysql_ids ) {
    $query = $dbh->prepare(qq{kill $process});
    $number_process = $query->execute();

    print LOGFILE "ERROR - No se pudo terminar el ID $process.\n" if ! defined ($number_process);
  }
}

close LOGFILE;
