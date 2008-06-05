package FileArchiveIndexer::Database;
use strict;
use warnings;
use Carp;
use DBI;
use FileArchiveIndexer::DEBUG;
our $VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)/g;

=pod

=head1 NAME

FileArchiveIndexer::Database

=head1 DESCRIPTION

This module should not be used directly. It is inherited by FileArchiveIndexer.
The code and documentation are placed herein for organization purposes only.

=head1 THE DATABASE

=head2 THE DATABASE LAYOUT EXPLAINED

In this document we assume that your database is called faindex, thus faindex.files refers to the table
"files" in the database "faindex".

=head3 faindex.files table

This table stores information about where the files are on disk. The actual physical location of the data.
This stores absolute path on disk, and the md5sum of this file. There may be multiple m5sums present, because
the same file may have copies.

=head3 faindex.indexing_lock table

This stores a timestamp of when the file was locked for indexing, and the md5sum as the file's identification.
There is no sense in normalizing the md5sum string here. Because that md5sum may appear two  or more
times in the files table. 


=head3 faindex.md5sum, and faindex.data tables

The faindex.md5sum table, keeps an id and a md5sum string. We recognize the authority of "file" to be its md5sum hex digest. 
So all data / metadata indexed, is recorded with an id, which is the faindex.md5sum.id entry.

The faindex.data table is where we look up text. The matching rows resolve to an id- which 
match faindex.md5sum.id.
This way we can see that the search for string "casual" is present in any file whose md5sum is x.
Then we can look inside faindex.files.md5sum and see if that file is on disk, and where.
 

=head3 Why is the md5sum field not normalized?

If you view the UPDATE PROCESS, you can see that we want the files table to be able to update quickly. We
may be updating the files table every hour. 
The age of your files table rebuild defines how accurate your data is in regards to location of the files.

Think about an archive with 80k files. 
First, we have to get the md5sum for those 80k files, on a 2.4GHz Xeon machine, this can take 30 minutes. Depending
on the size of the archive- of course.
Then, we have to make those 80k inserts. 
This process, the UPDATE PROCESS, can take anything from 20 minutes to an hour. 

In an ideal world, I would like the machines to be fast enough to normalize the md5sum string. But that would require
that for each insert into the files table, we look up its md5sum string the faindex.md5sum table first, get that id, then
come back and insert- Of course if the md5sum string is not in the faindex.md5sum table, we have to insert that as well.
Doing this for tens of thousands of entries slows the whole thing down exponentially. MySQL is not so good at inserts when
you compare it to SQLite, but the select queries are faster. Those are more important because we need the system to be
responsive to user search requests.

The downside is that all the varchar(32) column is present in large quantities two times in the database. Once in 
faindex.md5sum.md5sum and once in faindex.files.md5sum. The entry in faindex.indexing_lock.md5sum is negligible, 
because the maximum should match the number of indexers running.


=head2 DATABASE RELATED METHODS

=cut


sub dbh {
   my $self = shift;
   unless( $self->{DBH} ){
  
   	my $dbname		= $self->{DBNAME} or croak('missing DBNAME argument to constructor');
		my $host			= $self->{DBHOST} or croak('missing DBHOST argument to constructor');
		my $user			= $self->{DBUSER} or croak('missing DBUSER argument to constructor');
		my $password	= $self->{DBPASSWORD} or croak('missing DBPASSWORD argument to constructor');

		$self->{DBH} = DBI->connect(
         "DBI:mysql:database=$dbname;host=$host",
         $user,
         $password,
         { RaiseError=>1, AutoCommit => 0 })
		      or die("$DBI::errstrr, make sure mysqld is running");   
   }
   return $self->{DBH};
}

sub dbh_is_sqlite {
	my $self = shift;
	$self->dbh_driver=~/sqlite/i or return 0;
	return 1;
}

sub dbh_is_mysql {
	my $self = shift;
	$self->dbh_driver=~/mysql/i or return 0;
	return 1;
}

sub dbh_driver {
	my $self = shift;
	my $n = $self->dbh->{Driver}->{Name};
	$n||=undef;
	return $n;
}

sub dbsetup_reset {
   my $self = shift;
   
 #  $self->dbsetup_reset_files;

   $self->dbsetup_reset_data;

   $self->dbsetup_reset_status_log;

   $self->dbsetup_reset_indexing_lock;
  
   $self->dbh->commit;

   return 1;
}

sub dbsetup_reset_indexing_lock {
   my $self = shift;

   $self->dbh->do('DROP TABLE IF EXISTS indexing_lock');
   
   $self->dbh->do('CREATE TABLE indexing_lock (  
   md5sum varchar(32) NOT NULL UNIQUE,
   timestamp int(10) NOT NULL,
   hostname varchar(32)
   )');

   return 1;
}

sub dbsetup_reset_status_log {
   my $self = shift;

   $self->dbh->do('DROP TABLE IF EXISTS status_log');
   
   $self->dbh->do('CREATE TABLE status_log (  
      timestamp int(10) NOT NULL,
      total_files_indexed int(20) NOT NULL
      )');

   return 1;
}


sub dbsetup_reset_files {
   my $self = shift;

   $self->dbh->do('DROP TABLE IF EXISTS files');   
  
  # not sure about mtime anymore, not using it.
	my $table = 'CREATE TABLE files (
   id INTEGER AUTO_INCREMENT PRIMARY KEY,
   abs_path varchar(300) NOT NULL, 
   md5sum varchar(32) NOT NULL);'; 

   #TODO add index to md5sum column
   #TODO how to set unique on abs_path without error in mysql
   
	if ($self->dbh_is_sqlite){
      print STDERR "sqlite table.. " if DEBUG;
		$table = 'CREATE TABLE files (
		id INTEGER PRIMARY KEY,
		abs_path varchar(300) NOT NULL, 
		md5sum varchar(32) NOT NULL);';	
	}
  
   $self->dbh->do($table);

   return 1;
}


sub dbsetup_reset_data {
   my $self = shift;

   $self->dbh->do('DROP TABLE IF EXISTS md5sum');
	my $table = 'CREATE TABLE md5sum (
   id INTEGER AUTO_INCREMENT PRIMARY KEY,
   md5sum varchar(32) UNIQUE NOT NULL);';
#   CREATE INDEX ';
	if ($self->dbh_is_sqlite){
      print STDERR "sqlite table 2.. " if DEBUG;
		$table = 'CREATE TABLE md5sum (
		id INTEGER PRIMARY KEY,
		md5sum varchar(32) UNIQUE NOT NULL);';
      
		#md5sum varchar(32) NOT NULL);';# THIS was creating DUPLICATES!!!!!!!!!
      
	}
   # TODO ad index to md5sum column!!!!!!!
      # to alter.. in mysql -p ...
   # alter table files add index (md5sum);
   $self->dbh->do($table);
	

   $self->dbh->do('DROP TABLE IF EXISTS data');  
	my $data_table = 'CREATE TABLE data (
   id int(10) NOT NULL,
   page_number int(10) NOT NULL,
   line_number int(10) NOT NULL,
   content text NOT NULL,
   PRIMARY KEY (id, page_number, line_number),
	FULLTEXT (content)
	);';	
	if ($self->dbh_is_sqlite){		
		$data_table = 'CREATE TABLE data (
		id int(10) NOT NULL,
		page_number int(10) NOT NULL,
		line_number int(10) NOT NULL,
		content text NOT NULL,
		PRIMARY KEY (id, page_number, line_number)
		);'; #fulltext crashes sqlite
	}
   $self->dbh->do($data_table); 


   $self->dbh->do('DROP TABLE IF EXISTS meta');     
	my $meta_table = 'CREATE TABLE meta (
   id int(10) NOT NULL,
   metakey varchar(200) NOT NULL,
   metaval text NOT NULL
	);';
   $self->dbh->do($meta_table); 

   return 1;
}


sub dbh_count {
   my ($self,$statement) = @_;

   debug($statement);
   
   $statement=~/count\s*\(/i or confess("statement to dbh_count() must contain COUNT()");
   my $c = $self->dbh->prepare($statement) or confess($self->dbh->errstr);
   $c->execute;
   my $r = $c->fetchrow_arrayref;

   debug("done\n");

   my $count = $r->[0];
   $count ||= 0;
   return $count;
}



sub dbh_sth {
   my ($self, $statement) = @_;
   $statement or confess("missing statement argument");

   unless ($self->{_handles}->{$statement}){
      debug("Statment [$statement] was not in object cache.. preparing..\n");
      $self->{_handles}->{$statement} = 
         $self->dbh->prepare($statement) 
            or die("statment [$statement] failed to prepare, ".$self->dbh->errstr );
   
   }

   return $self->{_handles}->{$statement};   

}

=head3 dbh_count()

argument is statement
returns count number
you MUST have a COUNT(*) in the select statement

   my $matches = $self->dbh_count('select count(*) from files');


=head3 dbh_sth()

argument is a statment, returns handle
it will cache in the object, subsequent calls are not re-prepared

   my $delete = $self->dbh_sth('DELETE FROM files WHERE id = ?');
   $delete->execute(4);
   
   # or..
   for (@ids){
      $self->dbh_sth('DELETE FROM files WHERE id = ?')->execute($_);
   } 

If the prepare fails, confess is called.

There is a dbh prepare_cached() statement also

=head3 dbh()

returns database handle

=head3 dbh_is_mysql()

returns boolean

=head3 dbh_is_sqlite()

returns boolean

=head3 dbh_driver()

returns name of DBI Driver, sqlite, mysql, etc.
Currently mysql is used, sqlite is used for testing. For testing the package, you don't need to have
mysqld running.

=head3 dbsetup_reset_files()

will drop the files table if already exists.
will recreate the table
   
   CREATE TABLE files (
      id INTEGER AUTO_INCREMENT PRIMARY KEY,
      abs_path varchar(300) NOT NULL, 
      md5sum varchar(32) NOT NULL
   );

returns true.

=head3 dbsetup_reset_indexing_lock()

=head3 dbsetup_reset_data()

Will drop the data table and rebuild it.
It will also drop the md5 table and rebuild it.
CAREFUL- this deletes ALL your indexed data!
Only call this is you really dont want your indexed data or are starting a fresh setup.

There's almost no reason to call this, ever. Unless you've changed the way you want to store the text,
for example, clean or change it. 

=head3 dbsetup_reset_files()

Will drop and recreate files table.
This is called when reindexing the whole archive.
It leaves the data alone.

=head3 dbsetup_reset()

set up the database
This cleans out entire database!

=head2 IMPORTANT NOTE AUTOCOMMIT

Autocommit is set to 0 by default.
That means you should commit after indexing_lock(), indexing_lock_release(), delete_record()

DESTROY will finish and commit if there are open handles created by the object

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
