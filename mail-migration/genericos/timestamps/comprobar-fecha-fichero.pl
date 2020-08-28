#!/usr/bin/perl -w

use strict;
use Time::Local;

my $file = $ARGV[0];

my $day       = '';
my $month     = '';
my $year      = '';
my $file_date = '';
my $hour      = '';
my $min       = '';
my $sec       = '';

my $unix_time      = '';
my $file_unix_time = '';

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

   my @file_parts = split /\//,$file;
   next if $file_parts[$#file_parts] !~ /^\d/;
   open FILE,"< $file";
   foreach (<FILE>) {
     if ( $_ =~ /^D[a|A][t|T][e|E]:/ ) {
       $_ =~ s/[A-Z][a-z][a-z],//g;
       ($day,$month,$year,$file_date) = (split /[ ]+/,$_)[1,2,3,4];
       ($hour,$min,$sec) = (split /:/,$file_date)[0,1,2];
       last;
     }
   }

   $month = $months{$month};
   $unix_time = timelocal($sec,$min,$hour,$day,$month-1,$year);
   $file_unix_time = $file_parts[$#file_parts];
   $file_unix_time =~ s/^(\d+)\..+/$1/g;

print "$day/$month/$year $hour:$min:$sec ($file_date)\n";
print "Timestamp original: $unix_time\n";
print "Timestamp modificado: $file_unix_time\n";
