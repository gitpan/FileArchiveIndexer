use Test::Simple 'no_plan';
use strict;
use lib './lib';
use FileArchiveIndexer;
use DBI;
use Cwd;
use Smart::Comments '###';
$FileArchiveIndexer::DEBUG=1;


my $absdb = cwd().'/t/tmp.db';
my $dbh = DBI->connect( "dbi:SQLite:".$absdb,'','',{ RaiseError=>0, AutoCommit=>0, PrintError=>0} ); 

my $i = new FileArchiveIndexer({ DBH => $dbh });
ok($i, 'object instanciated');
$i->DOCUMENT_ROOT(cwd().'/t/archive');





ok(1);

# make sure all are indexed?


#while (my ($abs_path, $md5sum) = $i->get_next_indexpending ){
   
#   my $text   = File::Slurp::slurp($abs_path);  
   

#}

