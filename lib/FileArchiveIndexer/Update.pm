package FileArchiveIndexer::Update;
use strict;
use warnings;
use FileArchiveIndexer::DEBUG;
use Digest::MD5::File 'file_md5_hex';
our $VERSION = sprintf "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)/g;


=pod

=head1 NAME

FileArchiveIndexer::Update

=head1 DESCRIPTION

This module should not be used directly. It is inherited by FileArchiveIndexer.
The code and documentation are placed herein for organization purposes only.

=head1 UPDATE

This is the step that will be running regularly on your system.
What is does, is collect current filesystem information, about what the files of interest are, and what they md5sums are.

This information is kept in the 'files table'. 
Everytime you udpate, the entire files table is dropped, reset, dumped, killed, and rebuilt. Entirely. This data should
be kept current. The only things we want in this part of the index are the location of the file on disk, so we may 
physically find it- and the md5sum hex digest of the file, so we may later associate metadata, indexed data about the files,
with an actual file on disk.

This process takes about 30 minutes on a Intel Xeon 2.40GHz machine for a record of 60k files occupying 30 gigs. 
This is not a memory intensive procedure.

Why are the Location and Indexing steps kept sepparate?

Indexing a file can take a long time. Indexing does not mean simply

=cut



#TODO this deletes locks - it should detect indexers running and not run if indexers are running, otherwise the indexers will unlock wrong ids
sub repopulate_files_table {
   my $self = shift;
   my $files = shift;
   $files ||= $self->_find_all_files;   

	debug( sprintf "will repopulate %s files..\n", scalar @$files);
	
   # rebuild files and indexing_lock tables
   $self->dbsetup_reset_files;
	
	
	#require Digest::MD5; # using Digest::MD5::File was taking TWICE AS LONG.. because it was getting the actual md5sum, 

   my $count = 0;

   my $freshfile = $self->dbh_sth('INSERT INTO files (abs_path,md5sum) values (?,?)');

	my @inserts;
	for (@{$files}){
		#my $mtime = (stat $_)[9] or next;
		my $md5sum = file_md5_hex($_) or next;
#		debug("$_ $md5sum\n");
		push @inserts, [ $_, $md5sum ];		
	}

	for (@inserts){
      $freshfile->execute(@$_) or die($self->dbh->errstr);
		$count++;
	}

	debug("inserted $count files.\n");

	return $count;
}

=head2 repopulate_files_table()

This is what you do to update. It completely rebuilds the files table.
But leaves the data table untouched.
This operation does not commit, you must call commit afterwards

return value is count of files found on disk

   $i->repopulate_files_table;
   $i->dbh->commit;

Using Digest::MD5::File:
Takes an hour for 700 clients, approx 60k pdf documents.

Using Digest::MD5
700 clients, 60k docs... 30 secs

=cut






sub finder {

   my $self = shift;
   unless(defined $self->{finder}){
		require File::Find::Rule;
      $self->{finder} = File::Find::Rule->new();
      $self->{finder}->file;   
   }
   return $self->{finder};
}

sub min_chars_to_index {
   my $self = shift;
   my $arg = shift;   
   if ($arg){
      $self->{mincti} = $arg;
   }
   $self->{mincti} ||= 10;
   return $self->{mincti};
}

sub DOCUMENT_ROOT {
   my $self = shift;
   my $arg = shift;
   $arg||=0;
   if ($arg){
      $self->{DOCUMENT_ROOT} = $arg;
   }

   defined $self->{DOCUMENT_ROOT} or warn("DOCUMENT_ROOT not set") and return;
   return $self->{DOCUMENT_ROOT};
}

sub _find_all_files {
   my $self = shift;
   
   debug('...');
   $self->DOCUMENT_ROOT or return;
   
   my @files = $self->finder->in($self->DOCUMENT_ROOT);
   my $files = \@files;
   return \@files;
}

=head2 _find_all_files()


=head2 DOCUMENT_ROOT()

set or get the document root for your indexer.

   $i->DOCUMENT_ROOT('/home/myself');

=head2 finder()

returns File::Find::Rule Object. 

This is called if you want to make changes to what files we want the index to hold or scan.
If you know that perhaps some file with the filename "june" has changed.. you could do a quick update
this way:

   $i->finder->name( qr/june.+\.pdf/i );
   $i->scan_for_new_and_enqueue;

scan_for_new() will seek inside DOCUMENT_ROOT if it is set or warn.
Please see L<File::Find::Rule> for more.

The only default set on the finder object is file(), so that it only matches files.

=head2 min_chars_to_index()

=head1 SEE ALSO

L<FileArchiveIndexer>

=head1 AUTHOR

Leo Charre leocharre at cpan dot org

=head1 LICENSE

This package is free software; you can redistribute it and/or modify it under the same terms as Perl itself, i.e., under the terms of the "Artistic License" or the "GNU General Public License".

=head1 DISCLAIMER

This package is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the "GNU General Public License" for more details.

=cut







1;
