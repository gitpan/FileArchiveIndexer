#!/usr/bin/perl -w
use strict;
use FileArchiveIndexer;
use warnings;

$FileArchiveIndexer::DEBUG = 1;

my $fai = new FileArchiveIndexer({ abs_conf => '/etc/faindex.conf' });



#select some that dont have page # 1
print STDERR "getting list of wrongs .. ";
my $wrongs = $fai->dbh->selectall_arrayref(
   'SELECT DISTINCT id FROM data AS data2 WHERE NOT EXISTS '
      .'( SELECT * FROM data WHERE data.page_number = 1 AND data2.id = data.id LIMIT 1 )');
      
printf STDERR "done. got %s\n", scalar @$wrongs;


my $fix = $fai->dbh->prepare('UPDATE data SET page_number=page_number-1 WHERE id = ?');

for (@$wrongs){
   print STDERR $_->[0]."\n";
   $fix->execute($_->[0]);
   last;
}


print STDERR "finishing..";
$fix->finish;



=for

PDF::OCR::Thorough had a problem counting pages

some documents indexed record page 1 as page 2 instead.

so.. any docs that don't have a page 1, all their page nums should be changed.

this is that fix.


=cut
