use Test::Simple 'no_plan';
use strict;
use lib './lib';
use FileArchiveIndexer;
use DBI;
use Cwd;
#use Smart::Comments '###';
use File::Find::Rule;
use File::Slurp;
$FileArchiveIndexer::DEBUG=1;

unlink cwd().'/t/tmp.db';



my $absdb = cwd().'/t/tmp.db';
my $dbh = DBI->connect( "dbi:SQLite:".$absdb,'','',{ RaiseError=>0, AutoCommit=>0, PrintError=>0} ); 

my $ix = new FileArchiveIndexer({ DBH => $dbh });
ok($ix, 'object instanciated');

ok($ix->dbh_is_sqlite,'dbh is sqlite') or die("DBH SHOULD BE SQLITE");


ok($ix->dbsetup_reset,'setupdb again') or die();

$ix->DOCUMENT_ROOT(cwd().'/t/archive');

$ix->finder->name( qr/\.txt$/i );

my $found = $ix->repopulate_files_table;



ok($found, "repopulate_files_table() returns $found") or die();

ok($ix->dbh->commit,'committed db') or die();

#my $all = $ix->dbh->selectall_arrayref('SELECT * FROM files');
## $all




# most returned from index pending..


my $original_allpendingcount;

ok($original_allpendingcount = $ix->total_files_pending_nocache, 'total_files_pending_nocache') or die('cant get count here');
print STDERR " all pending count is $original_allpendingcount \n";

### $original_allpendingcount















# so.. if we lock 1, we should have equal to count-1

#my $minus = 2;

my ($abs_path,$md5sum) =$ix->get_next_indexpending or die('should get pending');

ok($ix->indexing_lock($md5sum),"indexing_lock($md5sum)"); 


# index it
my $text = File::Slurp::slurp($abs_path);

ok($ix->insert_record($md5sum,$text), "insert_record($md5sum)") or die();

ok($ix->indexing_lock_release($md5sum),"indexing_lock_release($md5sum)");
   

### now it should say it is indexed..
ok($ix->md5sum_is_indexed($md5sum),"md5sum_is_indexed($md5sum)") or die;


## cant lock again


ok( !($ix->indexing_lock($md5sum)), "trying to lock md5sum [$md5sum] after already indexing, returns false" ) or die();


# if we get the whole list again, it should be minus 1..



my $countnow = $ix->total_files_pending_nocache;

### $countnow






ok( ($original_allpendingcount - $countnow) == 1,
   "now get all pending [$countnow] is minus one, original pending count was [$original_allpendingcount]" ) or die('get pending should return what i want');





print STDERR "  =before $original_allpendingcount, now $countnow=\n";

#ok( $countnow == $original_allpendingcount, 
#	"after releasing.. it should be back to original value because we did not index it $countnow == $original_allpendingcount") or die();




ok(1,'done');














