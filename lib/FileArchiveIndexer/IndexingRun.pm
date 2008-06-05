package FileArchiveIndexer::IndexingRun;
use strict;
use base 'FileArchiveIndexer';
use warnings;
use Carp;
use Time::Format 'time_format';
use File::Slurp;
use File::Path;
use FileArchiveIndexer::DEBUG;

our $VERSION = sprintf "%d.%02d", q$Revision: 1.9 $ =~ /(\d+)/g;




=pod

=head1 NAME

FileArchiveIndexer::IndexingRun - abstraction of an indexing run

=head1 SYNOPSIS

   use FileArchiveIndexer::IndexingRun;

   my $i = new FileArchiveIndexer::IndexingRun({
      DBNAME => $dbname,
      DBPASSWORD => $dbpassword,
      DBHOST => $dbhost,
      SCP_USER => $scpuser,
      SCP_HOST => $scphost,
      use_ocr => 1,   
   });
   
   $i->run();
   
   exit;


=head1 DESCRIPTION

this module is an abstraction to an indexer run
this module uses FileArchiveIndexer as base, all its methods are present.

=cut

=head1 new()

   my $i = new FileArchiveIndexer::IndexingRun({
      DBNAME => $dbname,
      DBPASSWORD => $dbpassword,
      DBHOST => $dbhost,
      SCP_USER => $scpuser,
      SCP_HOST => $scphost,
      use_ocr => 1,
      run_max => 100,
      abs_log => '/var/log/faindex.log',
      running_as_remote_indexer => 0,   
   });

=head2 Arguments

=over 4

=item abs_conf

If you have a YAML config file..

   my $i = FileArchiveIndexer::IndexingRun({ abs_conf => '/etc/faindex.conf' });

=item run_max

When you call run() the maximum number of files indexed is run_max, see also run_max().

=item use_ocr

This module was designed to index pdf files with ocr, by default this is disabled, see use_ocr().

=item running_as_remote_indexer, SCP_USER, SCP_HOST

By default we expect that the indexer is running locally on the server which hosts the database and the
files. If this is not the case, running_as_remote_indexer sould be set to 1, the files are retrieved
via scp, so SCP_USER and SCP_HOST need to be set- see L<RUNNING AS REMOTE INDEXER>.

=item abs_log

Certain errors can be logged. For example, if we are running as remote indexer, and the file is not properly
retrieved, then we can log that. Also if we are using ocr and the file does not check ok for pdf standards, 
we can log that too. To enable logging you must set the parameter 'abs_log'.

Also a summary is logged at the end of each run.

=back

=cut




sub run {
   my $self = shift;
   debug("started\n");

   if ($self->use_ocr){
      debug("use_ocr set to one, requiring PDF::OCR::Thorough::Cached\n");
      require PDF::OCR::Thorough::Cached;   
   }


   my $loopcount=0;
   
   INDEXFILE : while ( $self->_run_should_continue ) {
   
      my ( $abs_path, $md5sum, $abs_local );

      debug( sprintf " - STEP STARTS, loopcount %s\n", ++$loopcount );
      
      ($abs_path, $md5sum) = $self->get_next_indexpending or last INDEXFILE;


=for should never happen, get_next_indexpending should ALWAYS return both vals or undef
      do { 
         no warnings;
         unless( $md5sum and $abs_path ){
            warn("no md5sum[$md5sum] or abs path [$abs_path]");
            
            $self->_log("no md5sum [$md5sum] or abs path [$abs_path]");
            
            debug(" - STEP ENDS, missing abs path or md5sum for indexing\n\n");
            
            next INDEXFILE;         
         } 
      };
=cut   

      # try locking
      unless( $self->indexing_lock($md5sum) ){
         debug( sprintf " - STEP ENDS, cannot lock for indexing\n\n");
         next INDEXFILE;
      }

     
      # THIS IS A HACK HERE

     
      if ($self->_running_as_remote_indexer){
         
        	unless( $abs_local = $self->get_file($abs_path) ){
            warn("cannot get [$abs_path] from remote, md5 mismatch? wrong scp credentials?");
            $self->_log("cannot get [$abs_path] from remote, md5 mismatch? wrong scp credentials?");
	         $self->indexing_lock_release( $md5sum ) or die("cant lock release [$md5sum], why.");  
            debug(" - STEP ENDS, cannot fetch file over ssh\n\n");
            
            next INDEXFILE; # get file takes care of md5sum check
         }   
      }

      else {      
         $abs_local = $abs_path; # this hack is added in case we are remote indexing
         # because in that case.. the abs path on the server will not be the same as local script indexing,
         # instead the file is saved to a temp location
      }


      # we should double tripple check the file is still there (got info from files table, from last faiupdate, might be gone.

      unless( -f $abs_local ){
         debug( sprintf "file [$abs_local] is not on disk will remove from files table and indexing_lock table\n");
         
         $self->files_table_delete($md5sum);# also unlocks
         $self->dbh->commit;
         debug(" - STEP ENDS, not on disk\n\n");
         
         next INDEXFILE;
      }


      
      
      my $FILETEXT;
   

      # PDF
      if ($abs_local=~/\.pdf$/i and $self->use_ocr){
         debug("is pdf, and use_ocr is on, getting pdf text..");
         
         
         if ( my $to = new PDF::OCR::Thorough::Cached($abs_local)){ # we still use it if it's all text or we want just the text (and the text IS in there)
            # PDF::OCR::Thorough::Cached looks for normal pdf text first, and does not try to read images unless there is no text
            # or we force ocr
         
         
            $FILETEXT = $to->get_text; # can be TIMELY   
            debug("ok, got text.\n");
            
         }

		
         else {
            # data is bad?
            debug("PDF::OCR::Thorough::Cached cannot instance for $abs_local, deleting record and going to next run step\n");
   #        $self->_log("PDF::OCR::Thorough::Cached cannot instance [$abs_path]");
            $self->files_table_delete($md5sum); # do we want to delete records like this?
			
            $self->dbh->commit;
            debug(" - STEP ENDS, bad pdf?\n\n");			
			   next INDEXFILE;
         }

      }



      # TXT FILE
      elsif( -T $abs_local ){ # was set abs path
         # slurp it?
         $FILETEXT = File::Slurp::slurp($abs_local);              
      }
     

     
      # UNKNOWN TYPE
      else {
         
         debug( sprintf "is [$abs_path] -T ? %s\n", ( -T $abs_path) );
         debug("we don't know how to get text out of [$abs_path], skipping.\n");
         
         # TODO not sure i want to delete the record
         $self->files_table_delete($md5sum); 
         # sometimes the implementation         
         # to extract text from a file may not be there yet (?)
         # but then in that case.. the UPDATE STEP can refresh that file again into the files table
         
         $self->dbh->commit;
            
         debug(" - STEP ENDS, unknown type\n\n");
         
         next INDEXFILE;     
      }
   
   


      

	   # create entries and insert them from the text we have
	   unless( $self->insert_record($md5sum,$FILETEXT) ){
          debug(" - STEP ENDS, no content??\n\n");
          $self->files_table_delete($md5sum);
          #die if DEBUG;
          next INDEXFILE;
      }

      debug("ok.. releasing indexing lock..\n");


	   # unlock
	   $self->indexing_lock_release( $md5sum );	#	$fix->dbh->commit; actually, indexing_lock_release() commits :-)

      $self->_run_count_increment; # record that we are +1 on the count
      
      debug( sprintf " + STEP ENDS, success # %s\n\n", $self->_run_count);
   
   
   }
   


   # ended
   $self->_log_run_summary;

   debug("ended\n");

   return 1;
}


sub run_max {
   my $self = shift;
   my $val = shift;
   if ( defined $val ){
      $self->{run_max} = $val;
   }   
   $self->{run_max} ||=100;
   return $self->{run_max};
}

sub _run_count {
   my $self = shift;
   $self->{run_count} ||=0;
   return $self->{run_count};
}

sub _run_count_increment {
   my $self = shift;
   $self->{run_count}++;
   return;
}

sub _run_should_continue {
   my $self = shift;

   if($self->_run_count >= $self->run_max){
      print STDERR " = run should stop, we have met run_max() criteria\n" if DEBUG;
      return 0;
   }  

   # are there no more pending?
   if($self->no_pending_files_left){
      print STDERR " = run should stop, no pending files left\n" if DEBUG;
      return 0;         
   }


   
   # then continue.

   return 1;
}






sub no_pending_files_left { # TODO  DEPRECATE .. ? should be able to call get_next_pending instead ??? 
   my $self = shift;
   $self->{no_pending} ||= 0;
   return $self->{no_pending};
}

sub use_ocr {
   my $self = shift;
   my $val = shift;
   if (defined $val){
      $self->{use_ocr} = $val;
   }
   defined $self->{use_ocr} or $self->{use_ocr} = 0;
   return $self->{use_ocr};   
}



1;


=head1 run()

this initiates the actual indexing run
it will keep running until the run_count() matches run_max() or no more files are in pending.
returns true after the run.

You can make your own indexer if you like. You do not have to use run().


=head2 run_count()

returns number
how many we have indexed so far
this does not include files skipped
files may be skipped because we can't lock or for errors
the count is only the count of successfully indexed files

=head2 run_max()

maximum files to index in this run
argument is max number of files to index to set
or you can also set via argument to constructor via 'run_max'
default is 100

   # set to 45
   
   $self->run_max(45);
   
   $self->run;


=head2 no_pending_files_left()

returns boolean
if no files are pending
only returns true if get_pending_next() has already been called and get_indexpending returned no more files


=head2 use_ocr()

argument is 1/0
returns boolean

if you want to use ocr for paper documents stored as scans
you will require PDF::OCR package installed and all its dependencies.
set to 0 by default
see L<PDF::OCR::Thorough::Cached>

can also be passed as argument 'use_ocr' to constructor










=head1 RUNNING AS REMOTE INDEXER

One of the crucial goals of FileArchiveIndexer is to be able to index a vast ammount of documents, possibly in a 
very time consumming manner. For example, using PDF::OCR::Thorough, we can turn pdf scans of documents into text
for the indexer.

The process is to cpu intensive that it can take one computer many weeks to index a large archive.
Thus, the option run multiple indexing machines for one archive and one database is a wonderful option to have.

Running as remote indexer, Digest::MD5::File is required.









=head2 HOW IT WORKS

The local indexer, being remote to the file archive, asks the database for a list of pending files.
For each file, we download the file, and ask what it's md5sum is supposed to be.
After downloading, we get an md5sum and check it against what the file archive server thinks it should be, if it is the
same then we index 


=head2 REQUIREMENTS

You must configure the file archive machine's mysql server to accept connections from the remote machines.
You will need to add a user and host to the mysql server to be able to make changes to it remotely.

On the server hosting your file archive and database :

mysql -p

GRANT ALL PRIVILIGES ON *.* TO '$DBUSER'@'$USERHOSTIP' IDENTIFIED BY '$password' WITH GRANT OPTION;

for example to grant on the network

GRANT ALL PRIVILIGES ON *.* TO '$DBUSER'@'192.168.0.%' IDENTIFIED BY '$password' WITH GRANT OPTION;


=head2 ADDITIONAL ARGUMENTS TO CONSTRUCTOR

In addition to all the normal arguments to constructor,
you must also provide these parameters:

=cut


sub get_file {
   my ($self, $abs_remote) = @_; $abs_remote or warn('missing arg to get_file') and return;

   require Digest::MD5::File;
   
   debug($abs_remote);


   my $abs_local = $self->_get_file_scp($abs_remote) or return;


   my $md5sum_remote = $self->file_md5sum($abs_remote)   
      or warn("cant get files.md5sum for abs remote $abs_remote") 
      and return;
	debug("md5sum remote = $md5sum_remote\n");
   

   my $md5sum_local = Digest::MD5::File::file_md5_hex($abs_local)
      or warn("cant get md5sum digest for abs local $abs_local")
      and return;
	debug("md5sum local = $md5sum_local\n");


	$md5sum_local eq $md5sum_remote or warn("BAD MD5 MATCH remote md5sum = $md5sum_remote, local is $md5sum_local, should be the same") and return;
		
	return $abs_local;
}

=head2 get_file()

argument is abs_path of remote file
returns abs_path of local file
will test for md5sum local being same as remote
if fails warns and returns undef

This is ONLY used for a remote indexer
that is, if the indexer is running on a different machine then the server holding the files and database

uses scp

=cut

sub _get_file_scp {
   my ($self,$abs_remote)= @_; $abs_remote or confess('missing abs_remote argument');
   
   $abs_remote!~/'/ or warn('cant scp files with single quote \' char in path for '.$abs_remote) and return;


   unless($self->{_gcheckvars__}){

      for ( qw(SCP_USER SCP_HOST) ){
         $self->{$_} or confess("missing [$_] argument to constructor");         
      }
   
      unless( $self->{SCP_TMP} ){
         $self->{SCP_TMP} = '/tmp/fai_tmp_'.time_format('yyyy_mm_dd',time());
         debug("tmp dir will be $$self{SCP_TMP}\n");
         -d $self->{SCP_TMP} or mkdir $self->{SCP_TMP} or confess("cant create $$self{SCP_TMP}");
      }
       
      -d $self->{SCP_TMP} or die($self->{SCP_TMP}." is not a dir");
   
      $self->{_gcheckvars__} = 1;
      debug("scp vars check ok.\n");
   }   


   
   my $abs_local = $self->{SCP_TMP}.'/'.$abs_remote;
   if (-e $abs_local){
      warn(__PACKAGE__."_get_file_scp() $abs_local already existed... returning that. if it screws up, clear this file?");
      return $abs_local;
   }
   
   
	my $abs_loc_local = $abs_local;	$abs_loc_local=~s/\/+[^\/]+$//;
	-d $abs_loc_local or File::Path::mkpath($abs_loc_local) or warn("cannot mkpath $abs_loc_local") and return;
		
     
	my @args = ('scp', $self->{SCP_USER}.'@'.$self->{SCP_HOST}.":'$abs_remote'" , $abs_local );
	debug("system [@args]..");
	system(@args) == 0 
		or warn("cannot [@args], $?") and return;

   return $abs_local;
}



sub _hostinfo {
   my $self = shift;

   
   
}


sub _running_as_remote_indexer {
   my $self = shift;
   my $val = shift;
   if (defined $val){
      $self->{running_as_remote_indexer} = $val;      
   }
   
   
   $self->{running_as_remote_indexer} ||= 0;

   if ($self->{running_as_remote_indexer}){
      $self->{SCP_USER} and $self->{SCP_HOST} or croak("missing SCP_USER SCP_HOST arguments to constructor");
   }

   #debug(" $ENV{HOST}\n $$self{SCP_HOST}\n");

   debug($self->{running_as_remote_indexer}."\n");
   
   return $self->{running_as_remote_indexer};   
}







=head2 _running_as_remote_indexer()

argument is 0/1
returns boolean
if set, then it will use get_file() to retrieve
also, additional arguments to constructor must be provided, 
see L<RUNNING AS REMOTE INDEXER>.
It is suggested not to use this method, instead to set it via the constructor.

=cut


=head2 EXAMPLE 1

Running as remote indexer with the default run() method

   use FileArchiveIndexer::IndexingRun;
   
   my $f = new FileArchiveIndexer::IndexingRun({ 
      DBNAME => $dbname,
      DBPASSWORD => $dbpassword,
      DBHOST => $dbhost,
      SCP_USER => $scpuser,
      SCP_HOST => $scphost,
      running_as_remote_indexer => 1,         
      use_ocr => 1,
      run_max => 200,
      abs_log => '/var/log/faindex.log'
   });
   
   $f->run;
   
   exit;

=head2 EXAMPLE 2

Running as remote indexer with your own indexer

   use FileArchiveIndexer::IndexingRun;
   
   my $f = new FileArchiveIndexer::IndexingRun({ 
      DBNAME => $dbname,
      DBPASSWORD => $dbpassword,
      DBHOST => $dbhost,
      SCP_USER => $scpuser,
      SCP_HOST => $scphost,
      runing_as_remote_indexer => 1,         
   });
   
   my $pending = $f->get_indexpending(20); # do 20
   
   for (@$pending) {
      my ($filesid, $abs_remote) = @$_;
   
      my $abs_local = $f->get_file($abs_remote) or next;
   
      my $md5sumid = $f->indexing_lock($abs_remote);
   
      my $text = your_method_for_getting_text_out_of($abs_local) or next;
      
      $f->insert_record($md5sumid,$text);
   
      $f->indexing_lock_release($filesid);
   
   }

=head1 DEBUG FLAG

   $FileArchiveIndexer::IndexingRun::DEBUG = 1;

This is an lvalue sub.

=head1 SEE ALSO

L<FileArchiveIndexer>
L<PDF::OCR::Thorough::Cached>

=head1 AUTHOR

Leo Charre leocharre at cpan dot org

=cut



