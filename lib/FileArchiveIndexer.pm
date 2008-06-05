package FileArchiveIndexer;
use strict;
use warnings;
use Carp;
use base qw(
FileArchiveIndexer::Database 
FileArchiveIndexer::Indexing 
FileArchiveIndexer::Update 
FileArchiveIndexer::Status
FileArchiveIndexer::Logging

);
use FileArchiveIndexer::DEBUG;
our $VERSION = sprintf "%d.%02d", q$Revision: 1.29 $ =~ /(\d+)/g;



=pod

=head1 NAME

FileArchiveIndexer - system to index a large collection of pdf documents

=head1 DESCRIPTION

FileArchiveIndexer is a collection of modules and scripts to maintain detailed information about documents on disk.

The intended use of this system is in a buysiness or office enviroment.

The system allows for a large archive of files that will be regularly changing by the adding, moving, and removing
of files.

OCR software is used to index content of image files, hard copy paper documents saved as pdf files.

The initial indexing of a large archive can take weeks.

This document shows an overview of how it works, and why some decisions were made as to how it works.
For technical API documentation, please see FileArchiveIndexer.

=head2 PORTABILITY

This application relies heavily on posix. It is meant to run on linux.
Portability is not a goal of this package.

=head2 HOW IT WORKS

In maintaining a database indexing an archive of files, there are two things we want to know.
The first thing is we want to know where the files are, we refer to this as the Update Step.
The other thing we want to do is actually index the files. This is the Indexing Step.

We keep these two steps of maintaining the database very separate from each other.

=head2 The concept of file.

The concept of file, or a document- in our archive, can be many things. A first answer for many people, 
and an intuitive answer, is that a file is a location on disk. That '/home/myself/file.txt' is the file.

Using the ext3 filesystem, another interesting possibility is to see a file as an inode. This would make some sense.
Inodes are pre ordained. That is, when you format a partition, a preset space on that disk is allotted for all
the inodes that partition will ever use. 

If you create a blank file, and it is associated with inode 4, and you remove that file, inode 4 will not be
used again. 
Also, if you modify the file, the inode number does not change. If you move the file within that partition, still,
the inode does not change. If you rename the file, the inode does not change.
So, associating metadata with inode number is an interesting possibility to index files (see Metadata::ByInode).

For the purpose of our FileArchiveIndexer, a file is not a physical location on disk (a filename), nor an inode.
A file is an md5sum hex digest.

=head2 GOALS

=over 4

=item 

The system will deal with a B<large> archive of documents residing in a filesystem.

=item 

If a file is renamed, or moved, its contents should not be reindexed. If a file's data has not changed, there must be a way
to acknowledge and reflect that.

=item

Indexing of particular document types can be extremely time intensive, taking maybe minutes for example to read an image with ocr
and turn it into text.

=item

multiple indexing processes should be able to run, maybe even from different computers. They should not bump into each other.
basically, there is a Queue system managing indexing.

=back


=head2 HOW THIS PACKAGE IS DEVIDED

FileArchiveIndexer is complex. It is a collection of various code modules and scripts.
For organization, debugging, and development purposes- The application has been divided up.

=over 4

=item Code and Documentation

=over 8 

=item FileArchiveIndexer

Main package code and documentation.
This file.

=item L<FileArchiveIndexer::Database>

Setting up the database, some discussion about database layout, etc.

=item L<FileArchiveIndexer::Status>

Querying for indexing status, how many files are indexed, eta time estimate, etc.

=item L<FileArchiveIndexer::Search>

Performing a search.

=item L<FileArchiveIndexer::IndexingRun>

Implementation of an indexer, should suffice most needs.

=item L<FileArchiveIndexer::DEBUG>

Small debug module re-used throughout.

=back

=item Web User Interface

L<FileArchiveIndexer::WUI>

Simple CGI::Application web user interface to search for files.

=item Command Line Interface

=over 8

=item L<faiupdate>

Update step implementation, this refreshes the locations of the files on disk

=item L<faindex>

Actual indexing of files, can be used remotely, so many machines can index at one time.

=item L<faistatus>

Getting overall information on how many files are indexed, how many are pending, which are being indexed, etc.

=item L<faisearch>

Search the archive

=item faindex.conf 

Configuration example

=back

=back



=head1 MAIN API

=cut

sub new {
   my ($class,$self)=@_;
   $self ||={};
   if ($self->{abs_conf}){
      require YAML;
	   my $conf  = YAML::LoadFile($self->{abs_conf});
      for (keys %$conf){
         $self->{$_} = $conf->{$_};
      }
      
      print STDERR "loaded conf $$self{abs_conf}\n" if DEBUG;
      
   }
   $self->{handles} = {};
	
   bless $self, $class;	
	
   return $self;
}

=head2 new()

   my $i = new FileArchiveIndexer::Update({
      DBHOST => 'localhost'
      DBNAME => 'faindex',
      DBUSER => 'carl',
      DBPASSWORD => 'password',
      DOCUMENT_ROOT => '/var/docs',
      min_chars_to_index => 50,
   });

Or you may provide a database handle.

   my $i = new FileArchiveIndexer({
      DBH => $myhandle,
      DOCUMENT_ROOT => '/var/docs',
   });

Instead of providing arguments to constructor, you can instead set abs_conf argument, 
which should be an absolute path to a YAML conf file with the parameters.

	my $i = new FileArchiveIndexer({ abs_conf => '/etc/faindex.conf' });

This file would for example contain:

   ---
   DBHOST: localhols
   DBNAME: faindex
   DBUSER: faindexer
   DBPASSWORD: super
   DOCUMENT_ROOT: /home/myself/archive   

min_chars_to_index means how many characters must be in the text at least- to index, otherwise ignore
the file, default is 10.

=cut








=head2 MAINTENANCE METHODS

=cut

sub orphaned_records_cleanup {
   my $self = shift;

   # let's make it easy.
   my $records = $self->_orphan_records;
   unless( scalar @$records ){
      print STDERR "there were no orphaned records.\n" if DEBUG;
      return 0;
   }
   
   for(@$records){      
		$self->_delete_record_data($_);     
   }

   return scalar \@$records;
}

sub _orphaned_records {
   my $self = shift;
   my $orphans=[];
   
   for(@{$self->dbh->selectall_arrayref('SELECT id FROM md5sum WHERE NOT EXISTS ( SELECT * FROM files WHERE files.md5sum = md5sum.md5sum )')}){
      push @$orphans, $_->[0];
   } 
   
   return $orphans;
}

sub indexing_lock_cleanup {
   my($self,$seconds) = @_;
   $seconds ||= 86400;

   my $too_old = (time - $seconds);
   $self->dbh_sth('DELETE FROM indexing_lock WHERE timestamp < ?')->execute($too_old);

   return;   
}

=head3 orphaned_records_cleanup()

This will remove all data records according to get_orphaned_data()

This is not a procedure you need to call often. It's only to clean up database space.
If md5sum table adn data tables hold data but do not match with an entry in the files table,
this causes no harm. Searching should not return something that does not have a record in files table.

Returns count of removed records. Keep in mind a record is one (1) md5sum table entry and could be thousands of data table entries.

=head3 _orphaned_records()

This returns an array ref with md5sum.md5sum that no longer match an entry in files table.
Mostly for curiosity

=head3 indexing_lock_cleanup()

argument is seconds ammount
will remove indexing locks older then x seconds

This can happen if your indexer dies or the system shuts down while indexing, you have files
locked as being indexed, but it's not happening.
So you can remove all locks older then x seconds

Remove odler then 10 minutes:

   $i->indexing_lock_cleanup(600);

If no argument is provided, will remove locks older then 1 day, or 86400 seconds

TODO: if this releases lock, are files then marked as indexxed????
maybe if we release a lock by force, we should clear all data for that file?!
actually.. only when the file lock is released is the data committed..

=cut






=head2 RECORD DELETE METHODS

These could be used for example, if you are indexing and detect bad data- and do not want to either mark the file 
as indexed, or allow it to keep coming up when seeing what the next file pending indexing is.

=cut



sub delete_record {#TODO DEPRECATE
   my ($self,$id) = @_;
   
   $self->dbh_sth('DELETE FROM files WHERE id=?')->execute($id);
   $self->dbh_sth('DELETE FROM indexing_lock WHERE id=?')->execute($id);

   return 1;
}

sub files_table_delete {
   my($self, $md5sum) = @_;
   $md5sum or confess('missing argument to files_table_delete');

   $self->dbh_sth('DELETE FROM files WHERE md5sum=?')->execute($md5sum);
   $self->dbh_sth('DELETE FROM indexing_lock WHERE md5sum=?')->execute($md5sum);

   return 1;   
}


sub _delete_record_data {
	my ($self, $md5sumid) = (shift, shift);
   $md5sumid=~/^\d+$/ or croak("missing md5sum id arg or bad arg");
   
   $self->dbh_sth('DELETE FROM md5sum WHERE md5sum.id=?')->execute($md5sumid);
   $self->dbh_sth('DELETE FROM data WHERE id=?')->execute($md5sumid);
   
	return 1;
}

=head3 delete_record()

argument is file id
deletes all references to a file from the files table and the indexing_lock table
does not make a call to commit
This does NOT delete from the md5sum or the data table. For that, see _delete_record_data()

=head3 _delete_record_data()

Will delete entries from data and md5sum table
argument is md5sum table id 

should rarely be called. used by orphaned_records_cleanup()


=head3 files_table_delete()

argument is md5sum
deletes from files table and attempts to delete from indexing lock
this may be desired if in the process of indexing we encounter bad data
a corrupt pdf for example
and we dont want it to continue being brought up in indexing, etc
or course, when faiupdate is run, it will be stored again.
maybe there should be a way to mark a certain md5sum as being 'corrupt' or bad
but then, what if we just dont have a means of indexing that data at the moment
a subsequent implementation to an indexer might be able to do so.

anyhow, for now, this is made available.
does NOT delete entries from data or md5sum table, only from files and indexing_lock tables.

returns true

=cut








=head2 RECORD QUERY METHODS

These methods are useful to retrieve some information from the database. 
For example if you want to see all data indexed about a particular file.
These methods should not be used to mine data on multiple files- it would be slow.

=cut

sub get_md5sumid_by_path {
   my($self, $abs_path) = @_;
   $abs_path or carp("missing abs_path argument") and return;
   
   my $found = $self->dbh->selectall_arrayref("SELECT md5sum.id FROM md5sum,files WHERE files.md5sum = md5sum.md5sum AND files.abs_path = '$abs_path' LIMIT 1");
   scalar @$found or return;

   return $found->[0]->[0];  
}

sub file_pages_indexed {
   my ($self,$md5sumid) = @_;
   $md5sumid or carp("missing md5sumid argument") and return;

   my $r = $self->dbh->selectall_arrayref("SELECT DISTINCT page_number FROM data WHERE id = '$md5sumid' ORDER BY page_number DESC"); # had to use DESC or does not work 
   scalar @$r or return 0;

   return $r->[0]->[0];
}

sub file_is_indexed {
   my($self, $md5sumid) = @_;
   $md5sumid or carp("missing md5sumid argument") and return;

   my $r = $self->dbh->selectall_arrayref("SELECT COUNT(*) FROM data WHERE data.id = '$md5sumid' LIMIT 1");
   scalar @$r or return 0;
   return 1;
}

sub file_md5sum { 
   my($self, $abs_path) = @_;
   $abs_path or carp("missing abs_path argument") and return;
   
   my $found = $self->dbh->selectall_arrayref(qq{SELECT md5sum FROM files WHERE abs_path = "$abs_path" LIMIT 1});
   scalar @$found or return;

   my ($md5sum) = @{$found->[0]};
   return $md5sum; 
} 

sub file_data_entries {
   my($self, $md5sumid) = @_;
   $md5sumid or carp("missing md5sumid argument") and return;
   
   my $r = $self->dbh->selectall_arrayref("SELECT COUNT(*) FROM data WHERE data.id = '$md5sumid'");

   scalar @$r or return 0;
   return $r->[0]->[0]; # TODO maybe needs to be $r->[0]->[0]
}

sub get_indexed_text {
   my ($self, $md5sumid, $page, $line ) = @_;
   $md5sumid or carp("missing md5sumid as argument") and return;
   $page ||=0;
   $line||= 0;

	print STDERR "get_indexed_text() $md5sumid $page $line\n" if DEBUG;
   
   if ($page and $line){
		print STDERR " page $page adn line $line.. " if DEBUG;
   
      my $r = $self->dbh->selectall_arrayref("SELECT content FROM data WHERE id = '$md5sumid' AND page_number = '$page' AND line_number = '$line' LIMIT 1");
      
      scalar @$r or return;
      return $r->[0];
   
   }


   elsif ($page){
		print STDERR " just page $page.. " if DEBUG;
   
      my $r = $self->dbh->selectall_arrayref("SELECT content FROM data WHERE data.id = '$md5sumid' AND page_number = '$page' ORDER BY line_number"); # there should not be more ?
		printf STDERR "got %s results\n",scalar@$r if DEBUG
      scalar @$r or return;
      my $return;
      for (@$r){
         $return.=$_->[0]."\n";
      }
      return $return;
   
   }


   # else return everything
	print STDERR " all pages.. " if DEBUG;

      my $rows = $self->dbh->selectall_arrayref("SELECT content, page_number FROM data WHERE data.id = '$md5sumid' ORDER BY page_number, line_number");
		
      scalar @$rows or return;
		printf STDERR  "got %s results.. ", scalar @$rows if DEBUG;
   	my $text;

	   my $pn='start';
	
	   for (@$rows){
	   	my($content, $page_number) = @$_;
		
		   if($pn eq 'start'){
		   	$pn = $page_number;
		   }
		   else{
			   unless( $pn == $page_number ){
		   		$text.="\f"; 
			   #	print STDERR "inserted pagebreak $page_number\n";	
			   	$pn = $page_number;
			   }
		   }		
		   #print STDERR "pg $page_number, line $line_number\n";
		   $text.=$content."\n";		
	   }

      return $text;
}

sub get_md5sum_id {
   my ($self, $md5sum) = @_;

   $md5sum=~/^\w{32}$/ or warn("argument [$md5sum] is not 32 char md5 hex digest?") and return;
   

   my $gmi = $self->dbh_sth('SELECT id FROM md5sum WHERE md5sum = ? LIMIT 1');

   $gmi->execute($md5sum);

   return unless $gmi->rows ; # TODO this may fail for sqlite!

   my $id = @{ $gmi->fetchrow_array }[0];

   debug("md5sum $md5sum, id $id\n");

   return $id;
}

=head3 get_md5sum_id()

argument is md5sum hex(32chars) digest, returns id from md5sum table
returns undef if not present

carps and returns undef if argument is not 32 \w char

=head3 get_md5sumid_by_path()

argument is abs path normalized 
returns md5sum table id
returns undef if not in tables

=head3 file_data_entries()

argument is md5sum.id, returns count of entries in the data table
if none found returns 0

=head3 file_pages_indexed()

argument is ms5sum.id, returns pages indexed count
if none found, returns 0

=head3 file_is_indexed()

argument is md5sum.id, returns boolean

=head3 file_md5sum()

argument is abs_path, returns md5sum in files table
(maybe should be renamed to db_files_md5sum()? )

   my $md5sum = $self->file_md5sum('/path/to/file.pdf');

returns undef if not found

=head3 get_indexed_text()

argument is md5sumid
optional arguments are page number, and line number

will retrieve text
lines are joined by \n and pages by \f pagebreaks chars

This is really useful to get information about a file's status, or just to see what text your indexer
retrieved for that file.

=cut




=head2 DESTROY()

finishes active database handles etc, makes a commit to the database.
Note, this method is called automatically.

=cut

sub DESTROY {
   my $self = shift;
   
   print STDERR "DESTROY closing active handles:" if DEBUG;
   if ( defined $self->dbh->{ChildHandles} ){
      map { print STDERR ' [close]'; $_->finish; } grep { defined $_ and $_->{Active} } @{$self->dbh->{ChildHandles}};
   }   
   print STDERR " done.\n" if DEBUG;

   $self->dbh->commit;
   $self->dbh->disconnect;		
   
   return 1;
}





=head1 UPDATE STEP API

L<FileArchiveIndexer::Update>

=head1 INDEXING STEP API

L<FileArchiveIndexer::Indexing>

=head1 DATABASE API

L<FileArchiveIndexer::Database>

=head1 STATUS API

L<FileArchiveIndexer::Status>

=head1 LOGGING API

L<FileArchiveIndexer::Logging>


=head1 CONFIGURATION

this script by default looks in /etc/faindex.conf for a config file
if you want to change that, then provide the -c parameter and a path to the YAML file.

=head2 faindex.conf

   ---
   DBHOST: localhost
   DBNAME: faindex
   DBPASSWORD: 1325157
   DBUSER: robert
   DOCUMENT_ROOT: /var/www/dms/doc


=head1 SEE ALSO

L<FileArchiveIndexer::Search> - object abstracting a search procedure
L<FileArchiveIndexer::IndexingRun> - object abstracting an indexing run procedure
L<FileArchiveIndexer::WUI> - web user interface for searching and viewing indexing status

Scripts:

L<faindex>
L<faisearch>
L<faistatus>

=head1 CAVEATS

This project is under development. Please notify the AUTHOR if you would like to contribute or if you see any BUGS.
If you have suggestions, please also notify the AUTHOR.

=head1 AUTHOR

Leo Charre leocharre at cpan dot org

=head1 COPYRIGHT

Copyright (c) 2008 Leo Charre. All rights reserved.

=head1 LICENSE

This package is free software; you can redistribute it and/or modify it under the same terms as Perl itself, i.e., under the terms of the "Artistic License" or the "GNU General Public License".

=head1 DISCLAIMER

This package is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the "GNU General Public License" for more details.

=cut

1;
