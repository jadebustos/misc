#!/usr/bin/perl -w

use strict;

use PersonalPerlLibrary::Mail;

# procesa los log de usuario para intentar almacenar los mensajes de correo

my @logfile = ();
my @error_msgs = ();

my $imapServer = 'localhost';
my $port       = 143;

my $email    = '';
my $password = '';
my $folder   = '';

my $imapcon = '';

foreach my $file (@ARGV) {

  # descomprimimos el fichero de estarlo
  if ( $file =~ /\.gz$/ ) {
    `gunzip -f $file`;
    $file =~ s/\.gz$//g;
  }

  open FILE,"< $file";
  @logfile = <FILE>;
  close FILE;

  # obtenemos el login y password del usuario
  ($email,$password) = (split /\//,(split /-/,$logfile[0])[1])[0,1];
  # eliminamos caracteres en blanco
  $email =~ s/[\t\n ]*//g;
  $password =~ s/[\t\n ]*//g;

  # extraemos los ficheros en los que hubo errores y no se migraron
  foreach my $line (@logfile) {
    next if $line !~ /^ERROR/;
    my $tmp_msg = (split /-/,$line)[1];
    $tmp_msg =~ s/[\n ]*//g;
    push @error_msgs,$tmp_msg; 
  }

  next if $#logfile == -1;

  open LOG, "> proc-error-$email.log";
  print LOG "OK - $email/$password\n";

  foreach my $msg (@error_msgs) {
    $folder = "INBOX".get_folder_from_filename($msg);
    my $msg_txt   = '';
    my $msg_flags = '';

    # abrimos conexion con el servidor
    $imapcon = connect_imap($imapServer, $port, $email, $password);
    if ( !defined($imapcon)) {
      print LOG "ERROR - No se pudo abrir conexion con el servidor imap.\n";
    }
    else {
      # obtenemos el mensaje
      open MSG,"< $msg";
      foreach (<MSG>) {
        $msg_txt = $msg_txt.$_;
      }
      close MSG;

      # obtenemos los flags

      my @tmp = split /,S=\d*:\d,/,$msg;
      if ( $#tmp > 0 ) {
        $msg_flags = $tmp[$#tmp];
      }

      # se soportan los siguients flags de rfc2060
      # S -> \Seen
      # R -> \Answered
      # D -> \Draft
      $msg_flags =~ s/S/\\Seen /;
      $msg_flags =~ s/R/\\Answered /;
      $msg_flags =~ s/D/\\Draft /;

    #  my $res = $imapcon->append_string($folder,$msg_txt,$msg_flags);
    }
    # cerramos la conexion imap
    $imapcon->disconnect;

  }

  # comprimimos el fichero de no estarlo
  if ( $file !~ /\.gz$/ ) {
    `gzip -f $file`;
  }

  $#error_msgs = -1;

  close LOG;

}
