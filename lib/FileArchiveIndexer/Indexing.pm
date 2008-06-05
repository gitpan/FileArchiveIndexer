package FileArchiveIndexer::Indexing;
use strict;
use warnings;
use Carp;
use FileArchiveIndexer::DEBUG;
our $VERSION = sprintf "%d.%02d", q$Revision: 1.26 $ =~ /(\d+)/g;

=pod

=head1 NAME

FileArchiveIndexer::Indexing

=head1 DESCRIPTION

This module should not be used directly. It is inherited by FileArchiveIndexer.
The code and documentation are placed herein for organization purposes only.

=head1 INDEXING

Indexing a file can take a long time. Indexing does not always mean simply tell me how many pages are in this document- 
or, what is the last modification time for this file? FileArchiveIndexer allows for more intesive procedures. Primarily in
mind was using OCR software to turn hard copy paper scans into text. If you have to do this to 30 gigabytes of pdf data,
this will take weeks.
During this time, the files can be moved, renamed, copied! Do you want to re-index a file just because the file's name 
changed, because it was moved, or because now there is a duplicate of the file? That would be incredibly wasteful, and you
would never be able to keep your data current, with a large file archive- especially in a multi-user environment.

This is why we do two odd things in FileArchiveIndexer.
One is that the authority about what a file is, is the md5sum hex digest of the file. The other thing is that we keep
the procedure files location update step, and the indexing step, totally separate.

This means if a file with the md5sum 'qwerty', once indexed, *is* indexed. And remains so. If the file is copied, moved,
even erased- we still keep the data we indexed. Thus the precious indexed data we collected- is valid across filesystems 
and user 'usage'.

Of course, if the file is modified in any way whatsoever, if a character is added, taken away, anything modified inside the
file's data itself- the indexing of that file will be repeated.

=head2 SYNOPSIS

	use FileArchiveIndexer;

	my $i = new FileArchiveIndexer({
		DBHOST => $dbhost,
		DBNAME => $dbname,
		DBUSER => $dbuser,
		DBPASSWORD => $dbpassword,		
	});   
	
	while( my($abs_path, $md5sum) = get_next_indexpending ){
   
		$i->indexing_lock( $md5sum ) or next; # is already indexed or locked for indexing by another process

		my $text = your_method_of_getting_text_out_of( $abs_path );

		$i->insert_record( $md5sum, $text );

		$i->indexing_lock_release( $md5sum );

	}

=head2 INDEXING STEP






How we index, brief overview:

=over 4

=item 1 - Ask the queue for the next file pending indexing.

An entry in the files table that does not match an entry in the md5sum table is a file not inedexed, thus, pending indexing.
To index a file, we receive the file's location and the file's md5sum.

=item 2 - Attempt to lock the file for indexing

We attempt to lock the file for indexing by identifying the file with the md5sum string.

=item 3 - Secure the file data.

If the indexing process running is remote to the archive's physical location, a copy of the file is stored to a temporary location.
Then the temporary file's md5sum is checked against what it should be according to the files table. This is to assure 
a) the file did not change, b) the file was not corrupted in transition accross the network.

=item 3 - Turn the file in question into simple text.

Your method of turning said file into text. 
You may separate pages with pagebreak characters.
A full method using tesseract ocr is provided within this package.

=item 4 - Insert the data

The text is inserted into the data table.

=item 6 - Release the indexing lock

The file is released from indexing.

=back

=head2 ABOUT MD5SUM

The md5sum is the most important thing for the data. We do not care about the file's absolute path much. 
Everytime we L<faiupdate>, we rebuild the entire files table. This makes sure that the paths to the data is current.

What is most important and interesting to us, the gold, the value of the database, is the data and md5sum table.

We can have multiple files with the same md5sum, in different computers, accross networks.. etc.

What we build with indexing is the matching of md5sum to text content.

This is why when we start indexing, we "lock" the file (in case other processes are also indexing parallel to us) and acquire
the id to the md5sum table entry. This is what we record data against.

So, we let's get one of the files pending indexing..

	my $pending = $self->get_indexpending(1);

	my( $files_id, $files_abs_path ) = $pending->[0];
	
	my $md5sum_id = $self->indexing_lock( $files_id );

This creates the entry in the md5sum table. This file yet will not be returned in a search result, because it is locked.

Now let's get the content of the file.. Let's imagine it is a text file. We slurp the content and give it to insert_record()

	require File::Slurp;

	my $text = File::Slurp::slurp($abs_path);

	# maybe we want to clean the text of sensitive data?

	$text=~s/sensitive data/ /sig;

	$self->insert_record($md5sum_id, $text);

now we release the file

	$self->indexing_lock_release( $files_id );

and save what we've done...

	$self->dbh->commit;

This is also done automatically by DESTROY.

What is so fabulous about the authority of the data being md5sum instead of a path on disk or an inode number, is that 
the file may dissappear, and the data still resides- the file may be in a different computer.. etc.. It doesn't matter.
The Authority is the md5sum.

=head2 ABOUT FILE LOCATIONS

Of course, the md5sum and the data itself is useless if it cannot point us in the direction of where a file can be found.

The files table holds this information.. it holds the location of where the file resides, and what the file's md5sum is.

When we search the text, the results point  not to a file on disk.. but to a unique md5sum! 
If we can then match the md5sum value to a location in the files table, we consider it a result.

=head3 WHY

Indexing html, text files, is relatively simple.
It's just text.
But in the real world, people scan in hard copy documents as pdfs. In my particular office we have about 60k such documents
and the list is growing every day. The files can only be found by filename and location. But what if someone misnames the files!
Or if they misplace it!!! We could lose valuable data!!

The FileArchiveIndexer is made with ocr in mind. 

Resetting the files table (to detect filename changes, moves, and files that no longer exist) takes 22 seconds for 60k files.
But re-indexing the entire archive is not a realistic procedure.
First of all, to index all of the content in the first place would take about 2 weeks. This is a procedure you want to do ONE time
and hopefully never again. And you really don't need to! Because we index on MD5SUM and not location or inode number.


=head2 INDEXING METHODS

=cut

# keeps a list fed in object
sub get_next_indexpending {
   my $self= shift;

   unless( defined $self->{pending_queue} and scalar @{$self->{pending_queue}} ){
      # this operation can be expensive. SO, i get 50 at a time, and cache it in the object
      # as the API, it seems like you just keep asking for the next one
      # we do not actually query the db for the next one, because that would be EXCRUCIATINGLY SLOW
      # even asking for many more, could be slow
      # i've fiddled around with maybe 3 or 4 ways of doing this operation, this works well
      # it's been debugged a lot, there have been MANY bugs doing this, so DONT FUCK WITH IT :-)
      # multiple indexers *can* have the same list- that's ok, because only one will lock
      # the funny thing is if you select 50 at a time, and you have 51 indexers.. then what???? 

      # I THINK THERE IS A RACE CONDITION HERE
      # I think there should be a formula for :
      #        ( how many indexers are running * NUMBER ) = LIMIT

      my $LIMIT = 50;
      
      # we could be querying a LOT ? It seems that would be wasteful to all hell.
      # maybe the select can be random or ordered in different ways, alternating ????

   
      debug("pending queue is empty.. ");

      #make sure it's defined
      $self->{pending_queue}=[];
      


      if (defined $self->{gpd_stopflag} and $self->{gpd_stopflag} ){
         debug("stopflag was raised, no more in pending. Will prepare and execute..");
         return; # so we return undef.
      }
      
      debug("will refeed next $LIMIT");
      
      # this is a hack replacement since i cant prepare with passing offset
      my $gpd = $self->dbh_sth( # can not figure out how to pass offset to a prepped query
               'SELECT abs_path, md5sum FROM files WHERE NOT EXISTS'.
               '(SELECT id FROM md5sum WHERE md5sum.md5sum = files.md5sum LIMIT 1)'.
               "GROUP BY md5sum LIMIT $LIMIT" 
      ); 
      # i realized getting first 50 or first whatever.. IS ALWAYS VALID
      # Because if it is already been indexed by another indexer.. that operation is committed
      # and subsequent selects to next pending list.. will no longer return that file as a result
      # SO, dont use an incrementing offset. seems like it made sense.. but NO.

                     
      $gpd->execute;     
      
      debug("ok.\nWill iterate through results..");
      
      while (my @row = $gpd->fetchrow_array){ # WAS USING for!!! 
        # debug("into queue [@row])");
         push @{$self->{pending_queue}}, \@row;
      }
     
      debug(sprintf "got [%s]\n", scalar @{$self->{pending_queue}});
           

      # how about.. if count is less then 50, turn on a stop flag so we dont keep requesting pending.. ???

      if (scalar @{$self->{pending_queue}} < 50 ){
         $self->{gpd_stopflag} = 1;
         debug( sprintf "got less then 50 (got %s), turning on stop flag\n", scalar @{$self->{pending_queue}});
      }
      

      scalar @{$self->{pending_queue}} or warn("no more pending files found");   
      
   }

   my $a = shift @{$self->{pending_queue}};
   defined $a or return;

   my ($abs_path,$md5sum) = @$a;
   debug("returning abs path, $md5sum\n");

   $abs_path or die("missing abs path");
   $md5sum or die("missing md5sum");

   return ($abs_path,$md5sum);
}

=head3 get_next_indexpending()

no argument
returns abs_path, md5sum string for next file in queue
you should attempt to lock afterwards
beacuse of the nature of indexing, it can take a long time, and we may be running multiple indexers, so attempting to lock is needed

if none in pending, returns undef

everytime you call get_next_indexpending, it returns a different file

   while( my ($abs_path,$md5sum) = $self->get_next_indexpending ){
      # lock or next
   }   

The md5sum string is the md5 hex sum for the file data at the time the files table was updated
you should check it again on disk so you know it has not changed in the meantime, and also, if you are remote indexing
to make sure the data was not corrupted in transit

This sub DOES return either those two values OR undef.

=cut

sub indexing_lock {
   my($self, $md5sum) = @_; defined $md5sum or croak("missing files id argument");

	debug($md5sum);


	# double check that this file has not been indexed already ?
   if( $self->md5sum_is_indexed($md5sum) ){
      debug("is already indexed\n");
      return 0;
   }


   # can we insert lock? if not.. it was already locked by some other indexer	
   # mark as being indexed   
   
   my $indexing_lock = $self->dbh_sth('INSERT INTO indexing_lock (md5sum,timestamp,hostname) values (?,?,?)');
   $ENV{HOSTNAME}||='';
	{   
		# seems like this DIES if it cant do- until i set RaiseError to nothing here:   
		local $indexing_lock->{RaiseError};
		local $indexing_lock->{PrintError};
	   
      debug("executing lock..");
		unless( $indexing_lock->execute($md5sum,time,$ENV{HOSTNAME}) ){
         debug("could not lock [$md5sum], must be already getting indexed.\n");
         return 0;      
      }
	   $indexing_lock->finish;
      
      debug("ok, and committing..");
      $self->dbh->commit;
	}
    

    #TODO is this necessary ?
    $self->{entrysession} = $md5sum; # this is later.. if we release lock without inserrting, then we clear the thing.. 
   
	debug("locked ok.\n");
  
   return 1;
}

=head3 indexing_lock()

argument is md5sum that you are going to start indexing
returns boolean

if it is already locked, returns false
otherwise locks (inserts md5sum and timestamp in indexing_lock table
and returns true   

   while( my($abs_path,$md5sum) = $self->get_next_indexpending ){
      $self->indexing_lock($md5sum) or next;

      # ... index....      
   }

This will make a call to commit the database, so that subsequent requests to lock return false

=cut

sub indexing_lock_release {
   my($self, $md5sum) = @_; $md5sum or die('missing argument');
   
	debug("$md5sum..");
   unless ( $self->{entrysession} ){
      debug("did not already call indexing_lock()?\n");
      return 0;
   }
      
   # take out of the queue for indexing pending   
   my $lock_release = $self->dbh_sth('DELETE FROM indexing_lock WHERE md5sum=?');
   $lock_release->execute($md5sum);
   $lock_release->finish;
   # DONT CHECK IF WE DID DELETE SOMETHING??

   # if we did not index anything.. then.. clear the md5 ?
  # unless( defined $self->{entries}->{$self->{entrysession}} and $self->{entries}->{$self->{entrysession}} ){ # see Indexing.pm
  #    debug(" $$self{entrysession} had no entries.. will remove from md5sum [$$self{entrysession}], ");
  #    $self->{handles}->{indexing_lock_release_non} ||= 
#			$self->dbh->prepare('DELETE FROM md5sum WHERE md5sum.id =?') or die($self->dbh->errstr);
#      $self->{handles}->{indexing_lock_release_non}->execute($self->{entrysession});  
#   }   
   
	$self->dbh->commit;
	debug("released.\n");
	
   return 1;   
}

=head3 indexing_lock_release()

argument is md5sum you just finished indexing.

   $self->indexing_lock_release($md5sum);

This is called when you complete indexing of a file.
It makes a commit call to the database.
returns boolean

=cut

sub indexing_lock_by_path {
	my ($self, $abs_path) = @_;
	
	# is the path in the files table?

	my $sth = $self->dbh_sth('SELECT files.md5sum FROM files WHERE files.abs_path=?')->execute($abs_path);

	my ($md5sum) = $sth->fetchrow_array;

	unless(defined $md5sum){
		warn("428 cant lock by path $abs_path, not in files table");
		return;
	}   
	
	# do normal lock now
	$self->indexing_lock($md5sum) or return;
   
	return $md5sum;
}

=head3 indexing_lock_by_path()

argument is abs path to file to index. 
must be a file.
If the file is not already in the files table, returns undef.
(because this whole thing is meant to index millions, not a few files, and you want to make sure the process
that selects what those files are, is repeated automatically).

same as indexing_lock(), but here you provide abs_path, returns md5sum
if cannot lock, returns undef

This is for calling via cli.
returns files.id and md5sum.id for indexing

	my ($md5sum) = indexing_lock_by_path('/home/myself/file.pdf') or die('cant lock to index');

=cut

#TODO this method needs testing
sub md5sum_is_indexed {
   my ($self,$md5sum) =@_;
   $md5sum or confess("md5sum_is_indexed() missing argument");

   debug("[$md5sum].. ");
   my $sth = $self->dbh_sth('SELECT count(*) FROM md5sum WHERE md5sum = ? LIMIT 1');
   $sth->execute($md5sum);
      # could check if there's something in data   
   
   if ( ($sth->fetchrow_array)[0] ){ #TODO might not work for sqlite
      debug("yes, found rows\n");
      return 1;
   }

   debug("no, no rows\n");

   return 0;   
}

=head3 md5sum_is_indexed()

argument is md5sum, will return boolean

returns true if md5sum digest string is in md5sum table
no md5sum digest should be in md5sum table unless this was indexed.

=cut




sub insert_record {
	my($self, $md5sum,$text) =@_; defined $md5sum or croak('missing md5sum id arg');
	defined $text or $text ='';

	$text=~/\w/ or warn("inser_record() text argument is negligible, skipped.") and return 0;





   # ---------------------------------------------------------------
   
   # 1) prepare the entries
   
   my $data = $self->_text_to_entries($text);  


   # ---------------------------------------------------------------

   
   # 2) optionally test the entries

	debug( sprintf "insert_record() with %s entries.. ", scalar @$data );

	scalar(@$data) or warn("turning text to entries returns nothing.. negligible. skipping.") and return 0;
   
   
   # ---------------------------------------------------------------   

   # 3) enter md5sum into md5sum table and get the id

   my $md5sumid = $self->_register_md5sum($md5sum) or return 0;
   
      
   # ---------------------------------------------------------------   

   # 4 ) INSERT THE DATA  
   
   for (@$data){      
      $self->_insert_data($md5sumid, @$_);
   }
   
   
   # ---------------------------------------------------------------

   
	debug("inserted data, done.\n");

	return 1;	
}


# this turns a flat glob of text into formatted for entries
# _text_to_entries()
# argument is data id and chunk of text to turn into entries.
# returns entries as array ref
#   _text_to_entries($text);
sub _text_to_entries {
   my ($self, $alltext) =@_;

   debug("_text_to_entries().. ");

	$alltext or return [];

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
         
         push @data, [$page_number,$line_number,$content];
      }
		
   }
	debug("done.\n");
   return \@data;
}

# before we can insert data, we need to insert mx5sum string into md5 table and get the last insert id
sub _register_md5sum {
   my ($self,$md5sum)= @_; $md5sum or confess("missing argument");
   
   # make entry into md5sum table and get the id
   # replace into? NO, we dont want to re-index md5sum unless specifially asked to
  
  
   my $sth = $self->dbh_sth('INSERT INTO md5sum (md5sum) values(?)'); # could freak out
   
   my $md5insert_ok;
   {
  	   local $sth->{RaiseError};
	   local $sth->{PrintError};
      debug("will place md5sum in md5sum table.. ");

      $md5insert_ok =  $sth->execute($md5sum);

   };
      
   if ($md5insert_ok ){   
      
         # feed last insert id
         my $id = $self->dbh->last_insert_id(undef,undef,'md5sum',undef);
         
         $id or confess("cant get last insert id for md5sum table insert [$md5sum]");  
            
         $sth->finish;
         
         debug("md5sum table last insert id is $id.\n");
         
         return $id;
   }      
      
   #else { # could not insert, already there, etc      
   warn("cannot insert_record for md5sum [$md5sum] because it is already in md5 sum table(?)");
   $sth->finish; # TODO make sure that later, getting last insert id does not return from a previous succesful insert!
   # actually for mysql driver, the last_insert_id is only available right after the insert
   return;
}



# _insert_data()
# arguments are md5sum.id, page number, line number, and content.
# Inserts a record into the database for a document
# Returns boolean
#   $i->_insert_data(1,1,1,'This is the First Line.');
# this is here so it can be overridden, content could be stripped of funny chars, whatever
sub _insert_data {
   my($self,$md5sumid,$page_number,$line_number,$content) = @_;
   
   unless( defined $md5sumid and defined $page_number and defined $line_number and defined $content ){
      no warnings;
      $self->log("[$md5sumid, $page_number, $line_number, $content] ?");
      confess('missing params');
   }
   
   $self->{entries}->{$md5sumid}++;
   
   my $sth = $self->dbh_sth('INSERT INTO data (id,page_number,line_number,content) values (?,?,?,?)');
   
   unless( $sth->execute($md5sumid, $page_number, $line_number, $content) ){
      $self->log($self->dbh->errstr);
      confess($self->dbh->errstr);   
   }
   
   return 1;
}

=head3 insert_record()

argument is md5sum and text scalar.

The text should be formatted with pagebreaks \f and linebreaks \n
insert record does NOT commit,
when you call indexing_lock_release() then it is committed.
So if the process dies or is interrupted, the file doesnt have halfway indexed data, etc.

argument is md5sum hex digest and text scalar
The text should be simple text with page break \f and line feed \n characters.

will check if the md5sum is already in md5sum table, will overrite it.

You may want to check if the md5sum is indexed already by calling md5sum_is_indexed()

For example, (this is not good usage, this is only to demonstrate example):

   my ($abs_path,$md5sum) = $self->get_next_indexpending;
   
   my $text = File::Slurp::slurp($abs_path);

   $self->insert_record($md5sum,$text);

Remember that the UPDATE STEP will automatically keep track of paths and md5sums
as a separate step, so abs path does not need be recorded. 

return value is boolean

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
