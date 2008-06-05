#!/usr/bin/perl -w
use base 'LEOCHARRE::CLI';

use strict;
use File::Copy;
use Time::Format 'time_format';
use Cwd;

my $o = gopts('D:');


$o->{D} or die("missing -D dir to get text files from");


my $absd = Cwd::abs_path($o->{D}) or die("cant resolve $$o{D}");





my @found = split (/\n/, `find ~/ -type f -name "*txt"`);
my $time = time_format('hh_mm_ss_',time);
my $x=0;
for (@found){
   my $from = $_;
   my $to =  cwd()."/t/archive/$time$x.txt";
   
   print STDERR " $from > $to\n" if DEBUG;
   File::Copy::cp($from, $to);
   
   
   # make them unique
   open(FILE, '>>',$to) or die($!);
   print FILE "\n$time$x\n" or die($!);
   close FILE or die($!);
   
   $x++;
}

=pod

=head1 DESCRIPTION

this is to aid putting some text files inside the t/archive directory

argument is a directory to recursively find .txt files in

   ./create_txtfiles.pl -D /path/to/textxs/


=head1 PARAMETERS

 -D directory to find text files in

=cut
