use Test::Simple 'no_plan';
use strict;
use lib './lib';
use FileArchiveIndexer::Search;
use DBI;
use Cwd;
use File::Find::Rule;
use File::Slurp;

$FileArchiveIndexer::Search::DEBUG = 1;


my $absdb = cwd().'/t/tmp.db';
my $dbh = DBI->connect( "dbi:SQLite:".$absdb,'','',{RaiseError=>0, AutoCommit=>0} ); 

my $s = new FileArchiveIndexer::Search({ DBH => $dbh });






ok( $s->execute('Virginia'));


my $bypath = $s->results_by_path;
ok($bypath);

my $files = $s->results_files;
ok($files, 'results_files()');


for (@$files){
   print STDERR "file $_\n";
   my $result = $s->result($_);
   ### $result
}



ok($s->results_count, 'results_count');


