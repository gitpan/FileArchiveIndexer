use Test::Simple 'no_plan';
use strict;
use lib './lib';
use FileArchiveIndexer;
use DBI;
use Cwd;
#use Smart::Comments '###';
use File::Find::Rule;

$FileArchiveIndexer::DEBUG=1;



my $absdb = cwd().'/t/tmp.db';
my $dbh = DBI->connect( "dbi:SQLite:".$absdb,'','',{ RaiseError=>0, AutoCommit=>0, PrintError=>0} ); 

my $i = new FileArchiveIndexer({ DBH => $dbh });


my $sth = $i->dbh->prepare('INSERT INTO data (id,page_number,line_number,content) values (?,?,?,?)') or die($i->dbh->errstr);

ok($sth);

my $data = [
   [qw(9 8 1 content1)],
   [qw(9 8 2 content2)],
   [qw(9 8 3 content3)],
];

my $data2 = [
   [qw(9 9 1 content1)],
   [qw(9 9 2 content2)],
   [qw(9 9 3 content3)],
];

for (@$data){
   $sth->execute(@$_);
   $sth->finish;
}



### break

for (@$data2){
   $sth->execute(@$_);
   $sth->finish;
}


ok(1);

# i was trying to find out if you call finish, does it kill the handle.. no it does not


