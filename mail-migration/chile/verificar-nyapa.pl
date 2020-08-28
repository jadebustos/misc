#!/usr/bin/perl -w

use strict;
use DBI;

use PersonalPerlLibrary::FS;
use PersonalPerlLibrary::Mail;

my $mysql_server = 'ip';
my $mysql_user   = 'postfix';
my $mysql_db     = 'password';
my $mysql_pass   = 'jakarta';

my $base_dir = '/var/spool/mailbox/';

foreach my $domain (@ARGV) {

  my %users_dir = ();
  my %users_name = ();

  my @vacios = ();

  # conexion con la BBDD
  my $dsn = "DBI:mysql:".$mysql_db.":".$mysql_server;
  my $dbh = DBI->connect($dsn,$mysql_user,$mysql_pass);

  my $sth = $dbh->prepare(qq{SELECT username,maildir,name FROM mailbox WHERE domain="$domain"});
  $sth->execute();
 
  while ( my $item = $sth->fetchrow_hashref() ) {
    $users_dir{$$item{'username'}} = $base_dir.$$item{'maildir'};
    $users_name{$$item{'username'}} = $$item{'name'};
  }
  $sth->finish(); # terminamos la consulta
  $dbh->disconnect;

  foreach my $user ( keys %users_dir) {
    my @userfiles = ();
    my @userlog = ();

    next if ! -d $users_dir{$user};
    @userfiles = get_mail_msgs_from_dir($users_dir{$user});

    foreach my $mailmsg ( @userfiles ) {

      my $delivered_to = "";
      my $msg_folder = get_folder_from_filename($mailmsg);

      if ( $msg_folder =~ /^\.Enviados$/ || $msg_folder =~ /^.Borradores$/ ) {
        my @file = ();
        open MAILMSG,"< $mailmsg";
        @file = <MAILMSG>;
        close MAILMSG;

        foreach my $line ( @file ) {
          if ( $line =~ /^From:/ ) {
            $delivered_to=$line;
            $delivered_to =~ s/^From:[\t ]*//;
            $delivered_to =~ s/.*<(.*)>.*/$1/g;
            last;
          }
          elsif ( $line =~ /^Delivered-To:/ ) {
            $delivered_to=$line;
            $delivered_to =~ s/^Delivered-To:[\t ]*//;
            $delivered_to =~ s/.*<(.*)>.*/$1/g;
            last;
          }
        }
 
      }
      else {
        $delivered_to = get_email_from_file($mailmsg);
      }

$delivered_to =~ s/\n//g;

      push @userlog,$delivered_to." - ".$mailmsg if lc($delivered_to) ne lc($user) && $delivered_to ne '';
      push @vacios,$delivered_to if $delivered_to eq '';

    }

    if ( $#userlog > 0 ) {
      open USERLOG,"> $user";
      $, = "\n";
      print USERLOG @userlog;
      close USERLOG;
    }

    $#userfiles = -1;
    $#userlog = -1;
  }

  open VACIOSLOG,"> $domain-vacios.log";
  $, = "\n";
  print @vacios;
  close VACIOSLOG;

}
