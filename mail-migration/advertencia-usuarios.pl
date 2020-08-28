#!/usr/bin/perl -w

# Jose Angel de Bustos Perez <jadebustos@gmail.com>

use strict;

use MIME::Lite;
use Net::SMTP;

my $from_address = 'user@domain';
my $mail_host    = 'mailhost.domain';
my $smtp_host    = 'smtphost.domain';
my $subject      = 'IMPORTANTE - MIGRACION DE CORREO ANTIGUO';
my $message_body = "bla bla bla bla bla bla .... bla bla bla NO HIJO NO";

my $datos_usuarios = "usuarios.overcuota.log.nuevos";

open USUARIOS,"< $datos_usuarios";

foreach my $user ( <USUARIOS> ) {

  # creamos el contenedor
  my $msg = MIME::Lite->new (
      From    => $from_address,
      To      => $user,
      Subject => $subject,
      Type    => 'TEXT',
      Data    => $message_body
    );

  # enviamos el mensaje
  MIME::Lite->send('smtp', $smtp_host, Timeout=>60);
  $msg->send;

}

close USUARIOS;
