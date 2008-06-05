use Test::Simple 'no_plan';
use strict;
use lib './lib';
use FileArchiveIndexer::Search;

use DBI;
use Cwd;
use Smart::Comments '###';
use File::Find::Rule;
use File::Slurp;

$FileArchiveIndexer::Search::DEBUG = 1;
my $absdb = cwd().'/t/tmp.db';
my $dbh = DBI->connect( "dbi:SQLite:".$absdb,'','',{RaiseError=>0, AutoCommit=>0} ); 

my $s = new FileArchiveIndexer::Search({ DBH => $dbh });


ok( $s->execute('Virginia'),'execute virginia');

my $files = $s->results_files;
ok($files, 'results_files()');

for (@$files){
   my $abs = $_;

   my $mid = $s->get_md5sumid_by_path($abs);
   $mid||=0;
   ok($mid,"get_md5sumid_by_path $mid");

   my $ind = $s->file_is_indexed($mid);
   my $pgs = $s->file_pages_indexed($mid);
   my $ent = $s->file_data_entries($mid);
   $ind||=0;
   $pgs||=0;
   $ent||=0;

   ok($ind,"is indexed $ind");
   ok($pgs,"pages $pgs");
   ok($ent,"entries $ent");
   



}


ok($s->status_log_enter,'status_log_enter');
# insert bogus entry
my $ent = $s->dbh_sth('INSERT INTO status_log (timestamp,total_files_indexed) values(?,?)');
$ent->execute( ( time()+600 ), $s->total_files);   # would make it 100% ??



ok($s->files_locked,'files_locked');
ok($s->percentage_indexed,'percentage_indexed');
ok($s->status_log_average,'status_log_average');
ok($s->status_log_count,'status_log_count');
ok($s->status_log_remainder,'status_log_remainder');
ok($s->status_log_seconds,'status_log_seconds');








### OTHER METHODS TO TEST..

my $count1 = $s->dbh_count('SELECT count(*) from files');
ok( $count1, "got count [$count1]");

ok( $s->dbh_driver,'dbh driver');

ok( $s->dbh_sth('SELECT * FROM indexing_lock'),'dbh_sth');






## indexing run

require FileArchiveIndexer::IndexingRun;

my $ir = new FileArchiveIndexer::IndexingRun({ DBH => $dbh });

ok($ir, 'IndexingRun instanced');
