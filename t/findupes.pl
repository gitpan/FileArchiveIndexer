#!/usr/bin/perl -w
use lib './lib';
use strict;
use FileArchiveIndexer;
use Smart::Comments '###';

my $f = new FileArchiveIndexer({abs_conf => '/etc/faindex.conf'});


### meant to address the problem of dupes

### limiting by 50

# first find the perpetrators

# how about eat the entire table.. hahahahah

#my $all = $f->dbh->selectall_hashref('SELECT * from 


my $dupeskilled=0;



my $q1 = 'SELECT md5sum FROM md5sum group by md5sum HAVING count(*) > 1';



print STDERR "preparing.. ";
my $q2 = $f->dbh->prepare('SELECT id FROM md5sum WHERE md5sum = ?');

my $q3 = $f->dbh->prepare('SELECT count(*) FROM data WHERE id = ? ');
print STDERR "ok.\n";


print STDERR "getting dupes in md5sum table, limit 100.. ";
my $results = $f->dbh->selectall_arrayref($q1);
printf STDERR "ok. got %s\n",scalar @$results;

for (@$results){
   my ($md5sum) = @$_;


   print STDERR "selecting all id from md5sum table for '$md5sum'.. ";   
   $q2->execute($md5sum);
   print STDERR "ok.\n";

   my $skipped=0;

   ITEM : while( my($id) = $q2->fetchrow ){
      print STDERR " id $id.. ";

      # skip one
      if($skipped++){
         print STDERR "deleting record data.. ";
         $f->_delete_record_data($id);
         print STDERR "killed.\n";
         $dupeskilled++;
         next ITEM;
      
      }
      
      #print STDERR "getting entry count in data.. ";
      #$q3->execute($id);
      #print STDERR ".. ";

      #my $entries = $q3->rows;
      #$q3->finish;
      print STDERR "ignore.\n";
   
      #print " $id, $entries\n",;
   }
   $q2->finish;
   print "\n";
   
}

print STDERR "DONE. $dupeskilled dupes killed.\n\n";




print STDERR "entries in  md5sum not in files..\n";

#my $notin = $f->dbh->selectall_arrayref('SELECT md5sum FROM md5sum WHERE NOT EXISTS ( SELECT files.md5sum FROM files WHERE files.md5sum = md5sum.md5sum LIMIT 1 )');

for (@{$f->orphaned_records}){
   print STDERR "$_\n";
}









# this selects any entries in md5sum table that have nothing in data table
# this can be caused by interrupting an indexing session

#my $qm =  'select id from md5sum where not exists(select id from data where data.id = md5sum.id)';




