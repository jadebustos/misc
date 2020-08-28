#!/usr/bin/perl -w

use strict;
use DBI;

my @domains = ();

$, = "\n";

my $mysql_server_prod = 'ip';
my $mysql_user_prod   = 'postfix';
my $mysql_pass_prod   = 'password';
my $mysql_target_db   = 'postfixdb'; # BBDD en la que se almacenaran los datos     

# conexion con la BBDD de produccion
my $dsn    = "DBI:mysql:".$mysql_target_db.":".$mysql_server_prod;
my $dbh    = DBI->connect($dsn,$mysql_user_prod,$mysql_pass_prod);
my $query  = '';
my $query2 = '';

# Recuperamos la informacion de los dominios
$query = $dbh->prepare("SELECT domain FROM domain");
$query->execute();
while ( my $item = $query->fetchrow_array ) {
  push @domains,$item;
}

# procesamos cada dominio para ver si hay las mismas entradas en
# la tabla mailbox que en la alias

foreach my $domain (@domains) {

  my $logfile = $domain.".log";

  my @mailbox = ();
  my %alias   = ();

  my %lookup       = ();
  my @mailbox_only = ();
  my @alias_only   = ();

  my $entradas_mailbox = 1;
  my $entradas_alias   = 1;

  print "Procesando el dominio $domain ...\n";

  # obtenemos usuarios de la tabla mailbox
  $query = $dbh->prepare("SELECT username FROM mailbox WHERE domain=\"$domain\"");
  $query->execute();
  while ( my $item = $query->fetchrow_array ) {
    push @mailbox,$item;
  }
  $entradas_mailbox = $entradas_mailbox + $#mailbox;

  # obtenemos usuarios de la tabla alias
  $query = $dbh->prepare("SELECT address,goto FROM alias WHERE domain=\"$domain\"");
  $query->execute();
  while ( my $item = $query->fetchrow_hashref ) {
    $alias{$$item{'address'}} = $$item{'goto'};
  }
  $entradas_alias = keys %alias;

  next if $entradas_mailbox == $entradas_alias;

  # abrimos fichero para logs
  open LOG,"> $logfile";

  print LOG "Entradas en la tabla mailbox: $entradas_mailbox\n";
  print LOG "Entradas en la tabla alias:   $entradas_alias\n";

  # elementos que estan en mailbox y no en alias
  if ( $entradas_alias == 0 ) {
    @mailbox_only = @mailbox;
  }
  else {
    @lookup{keys %alias} = ();

    foreach my $item (@mailbox) {
      push(@mailbox_only, $item) unless exists $lookup{$item};
    }
  }

  # inicializamos a cero elementos lookup
  %lookup = ();

  # elementos que estan en alias y no en mailbox
  if ( $entradas_mailbox == 0 ) {
    @alias_only = keys %alias;
  }
  else {
    @lookup{@mailbox} = ();

    foreach my $item (keys %alias) {
      push(@alias_only, $item) unless exists $lookup{$item};
    }
  }

  if ( $#mailbox_only != -1 ) {
    print LOG "\nElementos que estan en mailbox pero no en alias:\n\n";
    foreach ( @mailbox_only ) {
      print LOG "$_\n";
    }
    print LOG "\n";
  }


  if ( $#alias_only != -1 ) {
    print LOG "\nElementos que estan en alias pero no en mailbox:\n\n";
    foreach ( @alias_only ) {
      print LOG "$_ -> $alias{$_}\n";
    }
  }

  # cerramos fichero de logs
  close LOG;
  `gzip -f $logfile`
}

# cerramos la conexion con la BBDD
$dbh->disconnect;
