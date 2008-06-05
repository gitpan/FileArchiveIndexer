#!/usr/bin/perl
use strict;
use File::Find::Rule;
use Digest::MD5::File 'file_md5_hex';
use warnings;
use constant verbose => 0;

my $start = time();


my $maxfiles = 200;
my $abs_in = '/var/www';


my $rule = File::Find::Rule->new;
$rule->file;
$rule->name( qr/[^\/]+\.pdf$/i );

my @files = $rule->in($abs_in);

my $total_found = scalar @files or die('no files found, cant proceed');



my $x =0;
for(@files){
	

	my $sum = file_md5_hex($_) or warn("cant get sum for $_") and next;
	printf STDERR "$_ $sum [%s]\n",length($sum) if verbose;

	$x++;
	last if $x == $maxfiles;
}

print STDERR "We had found $total_found files, stoped at $x files, the maximum was set at $maxfiles.\n";


my $end = time();
my $seconds_elapsed = ($end - $start);


my $each = ( $seconds_elapsed / $x );

print STDERR "Seconds elapsed: $seconds_elapsed, each took approx [$each] seconds.\n";

my $seconds_for_all = ($total_found * $each );

my $minutes_for_all = int ( $seconds_for_all / 60 );

print STDERR "If we do $total_found files, it would take approx $seconds_for_all seconds, or approx $minutes_for_all minutes\n";



