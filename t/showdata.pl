#!/usr/bin/perl
use strict;
use lib './lib';
use DBI;
use Cwd;
use Smart::Comments '###';
use FileArchiveIndexer;
use YAML;
my $showfrom_mysql = 0;

my $dbh;

my $f;


if ($showfrom_mysql){

   $f = new FileArchiveIndexer({abs_conf => '/etc/faindex.conf'});   
   $dbh = $f->dbh;   
}
else {

   my $absdb = cwd().'/t/tmp.db';
   $dbh = DBI->connect( "dbi:SQLite:".$absdb,'','',{RaiseError=>0, AutoCommit=>0} ); 

}   

my $datatable = $dbh->selectall_arrayref('SELECT * FROM data');
### $datatable


my $md5table = $dbh->selectall_arrayref('SELECT * FROM md5sum');
### $md5table


my $locktable = $dbh->selectall_arrayref('SELECT * FROM indexing_lock');
### $locktable


my $filestable = $dbh->selectall_arrayref('SELECT * FROM files');
### $filestable


=pod

=head1 NAME

showdata.pl

=head1 DESCRIPTION

show table data in faindex database, this is for testing
This is a HUGE mysql dump to the screen. This script should only be used if you are having problems setting up.

=cut




