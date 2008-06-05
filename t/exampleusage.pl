#!/usr/bin/perl -w
use lib './lib';
use strict;
use FileArchiveIndexer;
use Cwd;
use PDF::OCR::Thorough;
use File::Find::Rule;

my $args = {
   DBHOST => 'localhost',
   DBPASSWORD => 'r4e3w2q1', # setup something here
   DBUSER => 'faindexer',
   DBNAME => 'faindex',
};

my $ix = new FileArchiveIndexer($args);





# 1)  insert new into queue

# determine what we want

my $finder = File::Find::Rule->new();
$finder->file;
$finder->name( qr/\.pdf$/i );

my @files = $finder->in(cwd().'/t/archive');

my $newfiles = $ix->scan_for_new(\@files);



for (@$newfiles){
   $ix->set_indexpending($_);
   $ix->dbh->commit;
} 







# 2).. get first 2 to index.. 

my $pending = $ix->get_indexpending(2);

for(@$pending){
   my($id, $abs_path) = @$_;
   
   $ix->indexing_lock($id) or next; # or some other process is dealing with it
   $ix->dbh->commit; #Q to record the lock
   
   my $f;
   unless( $f = new File::PathInfo::Ext($abs_path) ){
      $ix->delete_record($id)
      $ix->dbh->commit;
      next;
   } 

   # make sure it's not just a rename, a file abs path change
   if( $ix->update_abs_path( $f->abs_path, $f->mtime, $f->md5_hex) ) {
      $ix->delete_record($id); # would have been a duplicate record, this deletes the lock also
      $ix->dbh->commit;
      next;
   }

   #ok, then we INDEX!!! :-)

   # 1) get the content
   
   my $o = new PDF::OCR::Thorough($f->abs_path);

   my $alltext = $o->get_text; # can be TIMELY
   
   # 2) prepare the entries

   my @data;

   my $page_number = 0;
   my @pages = split( /\f/, $alltext);

   for (@pages){
      my $page = $_;
      $page_number++;
      my @lines = split( /\n/, $page);
      my $line_number=0;
      for (@lines){
         my $content = $_;
         $line_number++;
         
         
         
         push @data, [$id,$page_number,$line_number,$content];
      }   
   }
   

   # 3) insert the data

   for (@data){
      $ix->insert_data(@$_);
   }

   # 4) record the data so we know it's indexed and release from the lock queue
   $ix->indexing_lock_release($id, $f->abs_path, $f->mtime, $f->md5_hex);
   $ix->dbh->commit;   
}





