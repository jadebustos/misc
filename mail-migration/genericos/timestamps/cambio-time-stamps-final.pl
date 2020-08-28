#!/usr/bin/perl

use strict;
use Time::Local;
use DBI;

use PersonalPerlLibrary::FS;
use PersonalPerlLibrary::Mail;

my $year  = ''; 
my $month = '';
my $day   = ''; 
my $sec   = '';
my $min   = '';
my $hour  = '';

my $unix_time      = '';
my $file_unix_time = '';
my $touch_time     = '';

my $new_name = '';

my $domain = $ARGV[0];

my $mysql_server = "localhost";
my $mysql_user   = "postfix";
my $mysql_pass   = "password";
my $mysql_db     = "postfixdb";

my %users = ();

my $base_dir = "/var/spool/mailbox/";

my %months = ( "Jan" , "01",
               "Feb" , "02",
               "Mar" , "03",
               "Apr" , "04",
               "May" , "05",
               "Jun" , "06",
               "Jul" , "07",
               "Aug" , "08",
               "Sep" , "09",
               "Oct" , "10",
               "Nov" , "11",
               "Dec" , "12");

my %dias = ( "1" , "01",
              "2" , "02",
              "3" , "03",
              "4" , "04",
              "5" , "05",
              "6" , "06",
              "7" , "07",
              "8" , "08",
              "9" , "09");

# conexion con la BBDD
my $dsn = "DBI:mysql:".$mysql_db.":".$mysql_server;
my $dbh = DBI->connect($dsn,$mysql_user,$mysql_pass);

my $sth = $dbh->prepare(qq{SELECT username,maildir FROM mailbox WHERE domain=\"$domain\" AND name LIKE \"s%\"});
$sth->execute(); 

while ( my $item = $sth->fetchrow_hashref() ) {
  $users{$$item{'username'}} = $base_dir.$$item{'maildir'};
}

foreach my $user ( keys %users ) {
  my @files =  get_files_from_directory($users{$user});

  foreach my $file ( @files ) {
   my @file_parts = split /\//,$file;
   next if $file_parts[$#file_parts] !~ /^\d/;
   my $file_date = '';
   open FILE,"< $file";
   foreach (<FILE>) {
     if ( $_ =~ /^D[a|A][t|T][e|E]:/ ) {
       $_ =~ s/[A-Z][a-z][a-z],//g;
       ($day,$month,$year,$file_date) = (split /[ ]+/,$_)[1,2,3,4];
       ($hour,$min,$sec) = (split /:/,$file_date)[0,1,2];
       last;
     }
   }
   close FILE;  

   next if !-s $file;
   
   $month = $months{$month};
   next if $month-1 < 0;
   $unix_time = timelocal($sec,$min,$hour,$day,$month-1,$year);
   $file_unix_time = $file_parts[$#file_parts];
   $file_unix_time =~ s/^(\d+)\..+/\1/g;
   if ( $unix_time ne $file_unix_time ) {
     $day =~ s/0(.)/\1/g;
     $day = $dias{$day} if $day <= 9;
     $touch_time = $year.$month.$day.$hour.$min;
     $new_name = $file;
     $new_name =~ s/$file_unix_time/$unix_time/g;
     system "mv $file $new_name";
     system "touch -t $touch_time $new_name";
   }
  }

}
