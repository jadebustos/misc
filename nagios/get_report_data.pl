#!/usr/bin/perl -w

# script para generar un informe de disponibilidad en formato csv
# Jose Angel de Bustos Perez <jadebustos@gmail.com>

use strict;
use POSIX;
use DBI;

use MIME::Lite;
use Net::SMTP;

my $base_url    = "https://nagiosserver";
my $user        = "username";
my $password    = "password";

my $availability_report = '';
my $report_path         = "/home/jadebustos/informes/";
my $log_file            = "/var/log/informes_disponibilidad.log";

my %services = ();

my %servicesES   = ();
my %servicesGEN  = ();
my %servicesPE   = ();
my %servicesBR   = ();
my %servicesMX   = ();
my %servicesUY   = ();
my %servicesCL   = ();
my %servicesAR   = ();
my %servicesPT   = ();
my %servicesPR   = ();
my %servicesNET  = ();
my %servicesCO   = ();
my %servicesVE   = ();
my %serv_generi  = ();

  my %months = ( "01" => "Enero",
                 "02" => "Febrero",
                 "03" => "Marzo",
                 "04" => "Abril",
                 "05" => "Mayo",
                 "06" => "Junio",
                 "07" => "Julio",
                 "08" => "Agosto",
                 "09" => "Septiembre",
                 "10" => "Octubre",
                 "11" => "Noviembre",
                 "12" => "Diciembre");

my @timestamps = undef;

my $year     = "";
my $month    = "";
my @begin_tm = ();
my @end_tm   = ();
my @dates    = ();

my $today = `date +"%A %d de %B %G (%X)"`;

my $serverdb = '10.0.2.95';
my $userdb   = 'report';
my $passdb   = 'sard1na.1';
my $db       = 'nagiosqlCORP';

my $report_file = '';

if ( $#ARGV != 0 ) {
  print "get_report_data week para la ultima semana.\n";
  print "get_report_data month para el ultimo mes.\n";
  exit 1;
}

@timestamps = get_timestamp_last_month() if $ARGV[0] =~ /^month$/;
@timestamps = get_timestamp_last_week() if $ARGV[0] =~ /^week$/;

if ( ! $timestamps[0] ) {
  print "Argumento incorrecto.\n";
  exit 1;
}

@begin_tm = localtime($timestamps[0]);
@end_tm   = localtime($timestamps[1]);

# fecha de inicio del reporte
$year = $begin_tm[5]+1900;
$dates[0] = $year;
$begin_tm[4] += 1;
# ponemos el mes con dos digitos
if ( $begin_tm[4] =~ /^\d\d$/ ) {
  $month = $begin_tm[4];
}
else {
  $month = "0".$begin_tm[4];
}
$dates[0] = $dates[0].$month;

# ponemos el dia con dos digitos
if ( $begin_tm[3] =~ /^\d\d$/ ) {
  $dates[0] = $dates[0].$begin_tm[3];
}
else {
  $dates[0] = $dates[0]."0".$begin_tm[3];
}

# fecha de fin del reporte
$dates[1] = $end_tm[5]+1900;
$end_tm[4] += 1;
# ponemos el mes con dos digitos
if ( $end_tm[4] =~ /^\d\d$/ ) {
  $dates[1] = $dates[1].$end_tm[4];
}
else {
  $dates[1] = $dates[1]."0".$end_tm[4];
}
# ponemos el dia con dos digitos
if ( $begin_tm[3] =~ /^\d\d$/ ) {
  $dates[1] = $dates[1].$end_tm[3];
}
else {
  $dates[1] = $dates[1]."0".$end_tm[3];
}

# fichero del informe
$report_file = "disponibilidad_$dates[0]-$dates[1].csv";

# abrimos el fichero de log
open LOG, ">> $log_file";

%services = get_services($serverdb,$userdb,$passdb,$db);

if ( ! %services ) { # BEGIN if
  print LOG "$today - Error al obtener los servicios de los que generar el informe.\n";
  close LOG;
  exit 1;
} # END if

# clasificamos los servicios

%servicesES  = service_clasif(\%services, "ES");
%servicesPE  = service_clasif(\%services, "PE");
%servicesBR  = service_clasif(\%services, "BR");
%servicesMX  = service_clasif(\%services, "MX");
%servicesUY  = service_clasif(\%services, "UY");
%servicesCL  = service_clasif(\%services, "CL");
%servicesAR  = service_clasif(\%services, "AR");
%servicesPT  = service_clasif(\%services, "PT");
%servicesPR  = service_clasif(\%services, "PR");
%servicesNET = service_clasif(\%services, "NET");
%servicesCO  = service_clasif(\%services, "CO");
%servicesVE  = service_clasif(\%services, "VE");

$serv_generi{"PAGE_webmail_usuarios"} = '';

%servicesES  = put_data_into_hash(\%servicesES,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesPE  = put_data_into_hash(\%servicesPE,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesBR  = put_data_into_hash(\%servicesBR,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesMX  = put_data_into_hash(\%servicesMX,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesUY  = put_data_into_hash(\%servicesUY,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesCL  = put_data_into_hash(\%servicesCL,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesAR  = put_data_into_hash(\%servicesAR,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesPT  = put_data_into_hash(\%servicesPT,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesPR  = put_data_into_hash(\%servicesPR,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesNET = put_data_into_hash(\%servicesNET,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesCO  = put_data_into_hash(\%servicesCO,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesVE = put_data_into_hash(\%servicesVE,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);
%servicesGEN = put_data_into_hash(\%serv_generi,\%services,$timestamps[0],$timestamps[1],$base_url,$user,$password);

# generamos informes de todos los servicios unificados en un unico csv
open CSV, "> $report_path$report_file";

print CSV "Informe de disponibilidad de las aplicaciones\n";
print CSV strftime("%d/%B/%Y", localtime($timestamps[0]));
print CSV " y ";
print CSV strftime("%d/%B/%Y", localtime($timestamps[1]));
print CSV "\n\n";

print CSV "Aplicacion\t OK\t WARNING\t UNKNOWN\t CRITICAL\n";

if ( %servicesNET ) { # BEGIN if
  foreach ( keys %servicesNET ) { # BEGIN foreach
    my $stats = $servicesNET{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
} # END if
else { # BEGIN else
  print LOG "$today - No se pudieron obtener los datos de las aplicaciones NET.\n";
} # END else

if ( %servicesGEN ) { # BEGIN if
  foreach ( keys %servicesGEN ) { # BEGIN foreach
    my $stats = $servicesGEN{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos del web del correo de los paises.\n";
} # END else

if ( %servicesES ) { # BEGIN if
  foreach ( keys %servicesES ) { # BEGIN foreach
    my $stats = $servicesES{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones ES.\n";
} # END else

if ( %servicesPE ) { # BEGIN if
  foreach ( keys %servicesPE ) { # BEGIN foreach
    my $stats = $servicesPE{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones PE.\n";
} # END else

if ( %servicesBR ) { # BEGIN if
  foreach ( keys %servicesBR ) { # BEGIN foreach
    my $stats = $servicesBR{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones BR.\n";
} # END else

if ( %servicesMX ) { # BEGIN if
  foreach ( keys %servicesMX ) { # BEGIN foreach
    my $stats = $servicesMX{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones MX.\n";
} # END else

if ( %servicesUY ) { # BEGIN if
  foreach ( keys %servicesUY ) { # BEGIN foreach
    my $stats = $servicesUY{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones UY.\n";
} # END else

if ( %servicesCL ) { # BEGIN if
  foreach ( keys %servicesCL ) { # BEGIN foreach
    my $stats = $servicesCL{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # BEGIN if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones CL.\n";
} # END else

if ( %servicesAR ) { # BEGIN if
  foreach ( keys %servicesAR ) { # BEGIN foreach
    my $stats = $servicesAR{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones AR.\n";
} # END else

if ( %servicesPT ) { # BEGIN if
  foreach ( keys %servicesPT ) { # BEGIN foreach
    my $stats = $servicesPT{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones PT.\n";
} # END else

if ( %servicesPR ) { # BEGIN if
  foreach ( keys %servicesPR ) { # BEGIN foreach
    my $stats = $servicesPR{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones PR.\n";
} # END else

if ( %servicesCO ) { # BEGIN if
  foreach ( keys %servicesCO ) { # BEGIN foreach
    my $stats = $servicesCO{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones CO.\n";
} # END else

if ( %servicesVE ) { # BEGIN if
  foreach ( keys %servicesVE ) { # BEGIN foreach
    my $stats = $servicesVE{$_};
    $stats =~ s/\./,/g;
    print CSV "$_\t$stats\n";
  } # END foreach
  print CSV "\n";
} # END if
else { # BEGIN else
  print LOG "$today - No se puedieron obtener los datos de las aplicaciones VE.\n";
} # END else

close CSV;

# mandar por correo el informe mensual
if ( $ARGV[0] eq "month" ) { # BEGIN if
  my $result = send_report_by_email($report_path.$report_file, $months{$month}, $year, "month", $dates[0], $dates[1]);

  print LOG "$today - Error al enviar por correo ($result).\n" if defined $result;

} # END if

else { # BEGIN else
  my $result = send_report_by_email($report_path.$report_file, $months{$month}, $year, "week", $dates[0], $dates[1]);
  print LOG "$today - Error al enviar por correo ($result).\n" if defined $result;

} # END else

close LOG;

exit 0;

##############################################################
# FUNCION QUE PONE LOS DATOS DE LOS SERVICIOS DE UN PAIS EN  #
# UN HASH CON CLAVE EL SERVICIO VALOR UN STRING SEPARADO POR #
# ESPACIOS CON LOS VALORES OK WARNING UNKNOWN CRITICAL       #
##############################################################

sub put_data_into_hash { # BEGIN put_data_into_hash
  # $services_country -> servicios del pais
  # $services         -> servicios generales 
  # $t1               -> inicio
  # $t2               -> final
  # $base_url         -> url
  # $user             -> usuario
  # $pass             -> password

  my ($services_country,$services,$t1,$t2,$base_url,$user, $pass) = @_;
  my %tmp_services = %$services_country;

  foreach my $key ( keys %tmp_services ) { # BEGIN foreach
    my $availability_report = download_availability($$services{$key}, $key, $t1, $t2, $base_url, $user, $pass);

    return undef if !defined($availability_report);

    my @datos = get_data("$availability_report");

    # separamos los servicios con un tabulador para el csv
    foreach my $data ( @datos ) { # BEGIN foreach
      $tmp_services{$key} = $tmp_services{$key}.$data."\t";
    } # END foreach

    # borramos el informe
    system "rm -f $availability_report";
  } # END foreach

 return %tmp_services;

} # END put_data_into_hash

####################################
# FUNCION QUE CLASIFICA LOS PAISES #
####################################

sub service_clasif { # BEGIN service_clasif
  # $services -> hash con los servicios
  # $pattern  -> patron utilizado 

  my ($services, $pattern) = @_; 
  my %class = ();

  # todos los servicios de un pais terminan con sus iniciales
  foreach my $key ( keys %$services ) { # BEGIN foreach
    $class{$key} = '' if $key =~ /$pattern$/;
  } # END foreach

  return %class;
} # END service_clasif

#####################################################
# FUNCION QUE OBTIENE LOS SERVICIOS Y EL HOST EN EL #
# QUE ESTA PARA LA OBTENCION DE DATOS               #
#####################################################

sub get_services { # BEGIN get_services
  # $server -> servidor de BBDD 
  # $user   -> usuario
  # $pass   -> password
  # $db     -> BBDD

  my ($server, $user, $pass, $db) = @_;

  my %servicios = ();
  my %tbl_service = ();
  my %tbl_host = ();

  # abrimos conexion con la BBDD
  my $dsn   = "DBI:mysql:".$db.":".$server;
  my $dbh   = DBI->connect($dsn,$user,$pass);
  my $query = '';

  # fin en caso de no poder establecer conexion con la BBDD
  return undef if ! defined($dbh);

  # listado de servicios
  $query = $dbh->prepare(qq{SELECT id,service_description FROM tbl_service WHERE service_description LIKE "PAGE%"});
  $query->execute();

  while ( my $item = $query->fetchrow_hashref ) { # BEGIN while
    $tbl_service{$$item{'service_description'}} = $$item{'id'};
  } # END while

  # listado de hosts
  $query = $dbh->prepare(qq{SELECT id,alias FROM tbl_host});
  $query->execute();

  while ( my $item = $query->fetchrow_hashref ) { # BEGIN while
    $tbl_host{$$item{'alias'}} = $$item{'id'};
  } # END while

  # obtenemos el host asociado a cada servicio
  foreach my $key ( keys %tbl_service ) { # BEGIN foreach
    # obtenemos el id del host
    my $host_id = '';
    my $service_id = $tbl_service{$key};
    $query = $dbh->prepare(qq{SELECT tbl_B_id FROM tbl_relation WHERE tbl_A_id=$service_id AND tbl_A_field="host_name"});
    return undef if $query->execute() != 1;

    my @tmp =  $query->fetchrow_array;
    $host_id = $tmp[0];

    #obtenemos el nombre del host
    $query = $dbh->prepare(qq{SELECT alias FROM tbl_host WHERE id=$host_id});
    return undef if $query->execute() != 1;

    @tmp = $query->fetchrow_array;
    $servicios{$key} = lc($tmp[0]);

  } # END foreach

  return %servicios;
 
} # END get_services

#####################################################
# FUNCION QUE DEVUELVE EL TIME STAMP DEL ULTIMO MES #
#####################################################

sub get_timestamp_last_month { # BEGIN get_timestamp_last_month
  # $timestamps[0] -> comienzo de la semana
  # $timestamps[1] -> final de la semana
  my @timestamps = ();

  my @now_tm   = localtime(); # hora actual en formato tm_time 
  my @begin_tm;               # hora de comienzo del informe en formato tm_time

  my $seg_day  = 60*60*24;     # segundos que tiene un dia 
  my $seg_week = $seg_day * 7; # segundos que tiene una semana

  # Establecemos la hora 00:00:00 de hoy
  $now_tm[0] = 0;
  $now_tm[1] = 0;
  $now_tm[2] = 0;
  $now_tm[3] = 1; # primer dia del mes

  # calculamos los tiempos

  # dia final del mes
  $timestamps[1] = mktime(@now_tm);
  # primer dia del mes
  @begin_tm = localtime($timestamps[1]);
  $begin_tm[3] = 1;
  $begin_tm[4] -= 1;
  $timestamps[0] = mktime(@begin_tm);

  return @timestamps;

} # END get_timestamp_last_month 

##########################################################
# FUNCION QUE DEVUELVE EL TIME STAMP DE LA ULTIMA SEMANA #
# ENTRE LOS DOS ULTIMOS DOMINGOS                         #
##########################################################

sub get_timestamp_last_week { # BEGIN get_timestamp_last week

  # $timestamps[0] -> comienzo de la semana
  # $timestamps[0] -> final de la semana
  my @timestamps = ();

  my $seg_day  = 60*60*24;     # segundos que tiene un dia 
  my $seg_week = $seg_day * 7; # segundos que tiene una semana

  my @now_tm   = localtime(); # hora actual en formato tm_time 
  my @begin_tm;               # hora de comienzo del informe en formato tm_time
  my @end_tm;                 # hora de finalizacion del infore en formato tm_time

  # Establecemos la hora 00:00:00 de hoy
  $now_tm[0] = 0;
  $now_tm[1] = 0;
  $now_tm[2] = 0;

  # calculamos los tiempos
  $timestamps[1] = mktime(@now_tm) - ($now_tm[6] * $seg_day);
  $timestamps[0] = $timestamps[1] - $seg_week;
  @begin_tm = localtime($timestamps[0]);
  @end_tm   = localtime($timestamps[1]);

  return @timestamps;

} # END get_timestamp_last_week

#######################################################
# FUNCION QUE SE CONECTA AL SERVIDOR DE NAGIOS PARA   #
# DESCARGARSE EL INFORME DE DISPONIBILIDAD            #
#                                                     #
# ESTA FUNCION DEVUELVE LA RUTA AL FICHERO DESCARGADO #
# EN CASO DE QUE SE HAYA PODIDO DESCARGAR DE FORMA    #
# CORRECTA Y UNDEF EN CASO CONTRARIO                  #
#######################################################

sub download_availability { # BEGIN download_availability
  # $host    -> host en el que reside el servicio
  # $service -> servicio
  # $begin   -> fecha de inicio del informe
  # $end     -> fecha de fin del informe
  # $url     -> url de conexion para el servidor nagios
  # $user    -> usuario de nagios
  # $pass    -> password

  my ($host, $service, $begin, $end, $url, $user, $pass) = @_;

  
  my @orden = ("host", "service", "show_log_entries", "t1", "t2", "backtrack", "assumestateretention", "assumeinitialstates", "assumestatesduringnotrunning", "initialassumedhoststate", "initialassumedservicestate", "show_log_entries", "showscheduleddowntime");

  # variables que se le pasan a la url
  my %variables = (
                   "t1", $begin,
                   "t2", $end,
                   "host", $host,
                   "service", $service,
                   "assumeinitialstates", "yes",
                   "assumestateretention", "yes",
                   "assumestatesduringnotrunning", "yes",
                   "initialassumedservicestate", "0",
                   "initialassumedhoststate", "0",
                   "showscheduleddowntime", "yes",
                   "backtrack", "4",
                   "includesoftstates", "no"); 

  my $command = "";
  my $program = "wget";
  my $url_options = '';
  my $tmp_file = "/tmp/".$host."-".$service.".html";
  my $flags       = "--no-check-certificate --http-user=".$user." --http-passwd=".$pass." --output-document=".$tmp_file;
 
  # formamos la url del CGI
  $url = $url."/" if $url !~ /\/$/;
  $url = $url."nagios/cgi-bin/avail.cgi";

  # formamos los parametros que se le pasan a la url
  foreach my $key ( @orden ) { # BEGIN foreach

    if (exists($variables{$key})) { # BEGIN if
     $url_options = $url_options.$key."=".$variables{$key}."\&";
    }  # END if
    else { # BEGIN else
      $url_options = $url_options.$key."\&";  
    } # END else
    
  } # END foreach

  $url_options =~ s/&$/\"/g;

  # comando para descargar el fichero de disponibilidad
  $command = $program." ".$flags." "."\"".$url."?".$url_options." > /dev/null 2>&1";

  return $tmp_file if system("$command") == 0;
  return undef;

} # END download_availability

##################################################
# FUNCION QUE EXTRAE LOS DATOS DE DISPONIBILIDAD #
# DE UN SERVICIO                                 #
##################################################

sub get_data { # BEGIN get_data
  # $html_file -> fichero html a parsear con los datos

  my ($html_file) = @_;

  # $datos[0] = serviceOK
  # $datos[1] = serviceWARNING
  # $datos[2] = serviceUNKNOWN
  # $datos[3] = serviceCRITICAL
  my @datos        = ();
  my $undetermined = '';

  # abrimos el fichero
  open HTML, "< $html_file";
  my @tmpfile = <HTML>;
  close HTML;

  foreach my $line ( @tmpfile ) { # BEGIN foreach
    $html_file = $html_file.$line;
  } # END foreach

  # eliminamos los retornos de carro y dejamos solo la
  # tabla que nos interesa

  $html_file =~ s/\n//g;
  $html_file =~ s/.*(<TABLE.*CLASS='data'>.*<\/table>)<\/DIV><BR>.+/$1/g;

  # inicializamos 
  for(my $i=0;$i<4;$i++) { # BEGIN for
    $datos[$i] = $html_file;
  } # END for
  $undetermined = $html_file;

  # extraemos los datos que nos interesan
  $datos[0] =~ s/.*<td CLASS='serviceOK'>([\d\.]+)%<\/td><td CLASS=.+/$1/g;
  $datos[1] =~ s/.*<td CLASS='serviceWARNING'>([\d\.]+)%<\/td><td CLASS=.+/$1/g;
  $datos[2] =~ s/.*<td CLASS='serviceUNKNOWN'>([\d\.]+)%<\/td><td CLASS=.+/$1/g;
  $datos[3] =~ s/.*<td CLASS='serviceCRITICAL'>([\d\.]+)%<\/td><td CLASS=.+/$1/g;
  $undetermined =~ s/.*<tr CLASS='dataEven'><td CLASS='dataEven'>Total<\/td>.*<td CLASS='dataEven'>([\d\.]+)%<\/td><td CLASS=.+/$1/g;

  $datos[2] = $datos[2] + $undetermined;
  # ponemos la , como separador decimal
  foreach ( @datos ) { # BEGIN foreach
    $_ =~ s/\./,/g;
  } # END foreach

  return @datos;

} # END get_data


#########################################################################
# FUNCION QUE MANDA POR CORREO ELECTRONICO EL INFORME DE DISPONIBILIDAD #
#########################################################################

sub send_report_by_email { # BEGIN send_report_by_email

  my ($file, $month, $year, $type, $start, $end) = @_;

  my $from_address = 'mailfrom@domain';
  my $mail_host    = 'mailhost@domain';
  my $to_address   = 'user1@domain';
  my $cc_address   = 'user2@domain, user3@domain';
  my $smtp_host    = 'smtphost@domain';
  my $subject      = 'Informe de disponibilidad del mes de '.$month.' de '.$year;
  my $message_body = "Sistemas Linux les remite el informe de disponibilidad de aplicaciones de Example.com del mes de ".$month." de ".$year.".\n\n";
  my $filename     = "informe_disponibilidad_$month-$year.csv";

  if ( $type eq "week" ) { # BEGIN if
    $to_address   = 'user@domain';
    $cc_address   = 'otheruser@domain';
    $subject      = 'Informe de disponibilidad semanal del mes de '.$month.' de '.$year;
    $message_body = "Sistemas Linux les remite el informe de disponibilidad semanal de aplicaciones de Example.com del mes de ".$month." de ".$year.".\n\n";
    $filename     = "informe_disponibilidad_semanal_$start.$end-$year.csv";
  } # END if

  # creamos el contenedor
  my $msg = MIME::Lite->new (
    From => $from_address,
    To => $to_address,
    Cc => $cc_address,
    Subject => $subject,
    Type =>'multipart/mixed'
  ) or return $!;

  $msg->attach (
    Type => 'TEXT',
    Data => $message_body
  ) or return $!;

  $msg->attach (
     Type => 'text/csv',
     Path => $file,
     Filename => $filename,
     Disposition => 'attachment'
  ) or return $!;

  # enviamos el mensaje
  MIME::Lite->send('smtp', $smtp_host, Timeout=>60);
  $msg->send;

  return undef;

} # END send_report_by_email
