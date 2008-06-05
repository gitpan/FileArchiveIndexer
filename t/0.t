use Test::Simple 'no_plan';
use strict;
use lib './lib';
use FileArchiveIndexer;
use DBI;
use Cwd;
# for testing use a diff db
$FileArchiveIndexer::DEBUG=1;



my $absdb = cwd().'/t/tmp.db';

my $dbh = DBI->connect( "dbi:SQLite:".$absdb,'','',{RaiseError=>0, AutoCommit=>0} ); 

ok($dbh,'database handle');

my $i = new FileArchiveIndexer({DBH => $dbh });

ok($i->dbh,'database handle from object');

ok($i, 'object instanciated');

ok( $i->dbsetup_reset, 'dbsetup_reset()');







### **********
### PART 2 ***
### **********


# make sure getting next pending as far as can go is same count as pending


$i->DOCUMENT_ROOT(cwd().'/t/archive');
ok($i->repopulate_files_table);

my $pending_count = $i->total_files_pending_nocache;


# get all
my $get_count =0;
while( my ($abs_path,$md5sum) = $i->get_next_indexpending ){

   $i->indexing_lock($md5sum) or die;
   $i->insert_record($md5sum,'text');
   $i->indexing_lock_release($md5sum);

   $get_count++;
}   

ok($get_count == $pending_count, "get count [$get_count] == pending_count [$pending_count]");









### ***************
### recommendations
### ***************

unless( eval 'require PDF::OCR::Thorough::Cached' ){
   print STDERR "$0, the package PDF::OCR::Though::Cached is not installed.\nIt is strongly recommended that you have the PDF::OCR package installed from CPAN.\nIt allows turning of images and hard copy scans into PDF documents to be read with ocr. All open source. Check it out on cpan.";

}









