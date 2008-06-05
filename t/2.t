use Test::Simple 'no_plan';
use strict;
use lib './lib';
use FileArchiveIndexer;
use DBI;
use Cwd;
use Smart::Comments '###';
use File::Slurp;
use Data::Dumper;

my $absdb = cwd().'/t/tmp.db';

my $ix = new FileArchiveIndexer({
   DBH => 
      DBI->connect( "dbi:SQLite:".$absdb,'','',{RaiseError=>0, AutoCommit=>0} ) 
      });

#if ( $ix->dbh_is_sqlite ){ $ix->dbh->{RaiseError} = 0 and $ix->dbh->{PrintError} = 0 }

$FileArchiveIndexer::DEBUG = 0;

### index test



my ($abs_path,$md5sum) = $ix->get_next_indexpending;
  
ok($ix->indexing_lock($md5sum),"locked $md5sum");

my $text = File::Slurp::slurp($abs_path);

$ix->insert_record($md5sum,$text);

ok($ix->indexing_lock_release($md5sum),'indexing lock release');



print STDERR "dump.. ".Data::Dumper::Dumper($ix);

### status

ok($ix->total_files,'total_files()');

ok($ix->total_files_indexed,'total_files_indexed()'.$ix->total_files_indexed );
ok($ix->total_files_pending,'total_files_pending()'.$ix->total_files_pending);




 # THIS HAS TO BE RUN AFTER test 1













