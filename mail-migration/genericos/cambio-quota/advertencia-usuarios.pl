#!/usr/bin/perl -w

# Jose Angel de Bustos Perez <jadebustos@gmail.com>

use strict;

use MIME::Lite;
use Net::SMTP;

my $from_address = 'user@domain';
my $mail_host    = 'mailhost';
my $smtp_host    = 'smtphost';
my $subject      = 'IMPORTANTE - MIGRACION DE CORREO ANTIGUO';
my $message_body = "Estimado usuario,\n\nHa sido necesario aumentar su cuota de disco para poder realizar la migracion del correo antiguo. Debera liberar espacio y dejar su cuota de uso por debajo de 20 MB antes del 1 de Septiembre.\n\nEl 1 de Septiembre se restaurara su cuota original de 20 MB y en caso de no haber reducido el espacio de sus correos por debajo de 20 MB no podra recibir ni enviar correos. En ese caso tendra que ponerse en contacto con user@domain para que le solucionemos el problema.\n\nAtentamente el equipo de XXXX.";

my $datos_usuarios = "usuarios.overcuota.log";

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
