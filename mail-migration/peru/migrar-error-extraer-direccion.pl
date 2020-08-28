#!/usr/bin/perl -w

use strict;
use PersonalPerlLibrary::FS;
use PersonalPerlLibrary::Mail;

my $mysql_server = 'ip';
my $mysql_user   = 'postfix';
my $mysql_pass   = 'password';
my $mysql_db     = 'postfixdb';

my $imapServer="localhost";
my $port=1430;
my $password="prueba";

my $error_file = 'error-extraer-direccion.log';

my $email  = '';
my $folder = '';
my $msg    = '';

my @dirs = ();

open FILE,"< $error_file";

foreach (<FILE>) {
  chop $_;
  push @dirs,(split / /,$_)[13];
}

close FILE;

foreach my $dir (@dirs) {
  my @files = get_files_from_directory($dir);

  foreach my $file (@files) {
    my @folders = ("INBOX.Trash", "INBOX.Spam", "INBOX.Enviados", "INBOX.Borradores");
    my @tmp = split /\//,$file;
    my $msg_flags = '';
    # Eliminamos los que no empiezan con numero o tienen tamanyo cero
    next if $tmp[$#tmp] !~ /^\d+/ || ! -s $file;
    $folder = get_folder_from_filename($file);

    if ( $folder eq ".Enviados" || $folder eq ".Borrador" ) {
    
      open SMTPFILE,"< $file";
      foreach my $line (<SMTPFILE>) {
        if ( $line =~ /^From:/ ) {
          $email=$line;
          $email =~ s/^From:[\t ]*//;
          $email =~ s/[\t\n ]*$//;
          last;
        }
      }
      close SMTPFILE;

    }
    else {
      $email = get_email_from_file($file);
    }

  $folder =~ s/^(\..+)/INBOX$1/g;
  $folder =~ s/^(INBOX.Borrador)/$1es/g;
  $folder =~ s/^INBOX.Papelera$/INBOX.Trash/g;

  # conectamos con el servidor IMAP
  my $imapcon = connect_imap($imapServer, $port, $email, $password);
  # Creamos las carpetas 
  push @folders,$folder if $folder !~ /INBOX\.[Enviados|Borradores|Trash|Spam]/; 
  create_imap_folders(\@folders, $imapcon);
  # suscribimos a las folders
  foreach my $folder (@folders) {
    next if $folder eq "INBOX";
    $imapcon->subscribe($folder);
  }

  # almacenamos el mensaje de correo en $msg
  open MSG, "< $file";
  foreach my $line (<MSG>) {
    # Eliminamos los final de linea tipo DOS
    $line =~ s/\r/\n/g;
    $msg = $msg.$line;
  }
  close MSG;
  # Almacenamos el mensaje para que quede el transformado
  # como mensaje original
  open MSG, "+> $file";
  print MSG "$msg";
  close MSG;

  $msg_flags =~ s/D/\\Draft / if $folder =~ /Borrador/;

  # almacenamos el mensaje
  my $uid = $imapcon->append_string($folder, $msg, $msg_flags);
  if ( !defined($uid) ) {
    print "ERROR - $file\n";
  }

  $imapcon->close;
  }

}
