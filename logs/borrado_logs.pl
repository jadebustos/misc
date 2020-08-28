#!/usr/bin/perl -w

# script para borrar los logs de mas de un determinado tiempo

# se le pasan como argumentos ficheros de configuracion con la 
# siguiente sintaxis

# DIR = directorio a procesar
# REGEX = expresion regular para los archivos
# TIME = fecha de antiguedad en dias. Los que sean mas antiguos
#        seran borrados

use strict;
use POSIX;

my @now_tm     = localtime(); # hora actual en formato tm_time
my $seg_day    = 60*60*24;     # segundos que tiene un dia 
my $umbral_time = '';
my $now_string = strftime "[%e %b %a %Y %H:%M:%S]", @now_tm; 

my $log_file = '/var/log/borrado-logs.log';

$now_string =~ s/^\[[\t ]*/\[/g;

# Establecemos la hora 00:00:00 de hoy
$now_tm[0] = 0;
$now_tm[1] = 0;
$now_tm[2] = 0;

if ( $#ARGV == -1 ) {
  print "Numero insuficiente de argumentos.\n";
  exit 0;
}

open LOGFILE,">> $log_file";

foreach my $conf ( @ARGV ) {

  my $dir   = '';
  my $regex = '';
  my $time  = '';
   
  my $res = '';

  my $file = '';
  my $file_last_mod_time = '';

  # procesamos los ficheros de configuracion
  next if ! -f $conf;
  
  # abrimos el fichero de configuracion
  open CONF,"< $conf";
  foreach my $line ( <CONF> ) {
    $dir   = $line if $line =~ /^DIR/;
    $regex = $line if $line =~ /^REGEX/;
    $time  = $line if $line =~ /^TIME/;
  }
  close CONF;

  $dir   =~ s/^\w+[\t ]*=[\t ]*//g; chomp($dir);
  $dir   =~ s/(.+)/$1\//g if $dir !~ /\/$/;
  $regex =~ s/^\w+[\t ]*=[\t ]*//g; chomp($regex);
  $time  =~ s/^\w+[\t ]*=[\t ]*//g; chomp($time);

  # adecuamos los comodines a las expresiones 
  # regulares habituales
  $regex =~ s/\./\\./g;
  $regex =~ s/\*/\.\*/g;

  # calculamos los tiempos restandole al dia de hoy los
  # dias que queremos guardar. Todo lo anterior se borrara
  $umbral_time = mktime(@now_tm) - ($time * $seg_day);

  # procesamos los ficheros del directorio
  next if ! -d $dir;
  opendir(DIR, $dir);
  while (defined($file = readdir(DIR))) {
    $file = $dir.$file;
    next if ! -f $file;
    next if $file !~ /$regex$/;

    $file_last_mod_time = (stat($file))[9];
    if ( $file_last_mod_time < $umbral_time ) {
       $res = unlink $file;
       if ( $res == 1 ) {
         print LOGFILE "$now_string - Borrado $file.\n";
       }
       else {
         print LOGFILE "$now_string - Error al borrar $file.\n";
       }
    }
  }
  closedir(DIR);

}

close LOGFILE;
