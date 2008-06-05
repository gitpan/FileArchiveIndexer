#!/usr/bin/perl -w
use strict;
use base 'Dyer::CLI';
use lib './lib';
use PDF::OCR::Thorough::Cached;
use FileArchiveIndexer;
use File::Find::Rule;


my $c1 = config('/etc/faindexer.conf');
my $c2 = config('/etc/pdf2ocr.conf');

my $fix = new FileArchiveIndexer($c1);




$fix->finder->exec(
   sub { 
      my $fullpath = +shift;
      $fullpath=~/\/incoming\//i  or return 1;
      return 0;
   }
);

$fix->finder->name( qr/\.pdf$/i );


my @files = $fix->finder->in('/var/www/dms/doc/Clients');

my $x = 0;
for (@files){	
	my $p = new PDF::OCR::Thorough::Cached($_) or next;
	$x++;
	$p->set_abs_cache($c2->{abs_cache});
	$p->is_cached and next; 
	$p->get_text;
	print STDERR ++$x." done\n\n";
}





