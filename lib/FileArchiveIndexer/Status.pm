package FileArchiveIndexer::Status;
use strict;
use warnings;
use Carp;
use FileArchiveIndexer::DEBUG;

=pod

=head1 NAME 

FileArchiveIndexer::Status - reporting indexing status

=head1 DESCRIPTION

This is to report on status of indexing and the database.
This module is not to be used standalone- the methods in this module are inherited by FileArchiveIndexer.

=head1 METHODS

=cut


sub total_files {
	my $self = shift;

   unless( defined $self->{__ttf_} ){

      $self->{__ttf_} = $self->dbh_count('SELECT COUNT(DISTINCT md5sum) FROM files');      
      $self->{__ttf_} or warn("no files, may be updating files table");
   }  
	return $self->{__ttf_};
}

sub total_files_indexed {
	my $self = shift;  

   unless( defined $self->{_tfi} ){      
      
      $self->{_tfi} = $self->dbh_count('SELECT COUNT(id) FROM md5sum');
      
   }    
	return $self->{_tfi};
}

sub total_files_pending {
	my $self = shift;

   unless( defined $self->{_totalfilespending} ){
      $self->{_totalfilespending} = $self->total_files_pending_nocache;
   }
   return $self->{_totalfilespending};   
}

sub total_files_pending_nocache {
   my $self = shift;

   my $count = $self->dbh_count(
      'SELECT count(distinct md5sum) FROM files WHERE NOT EXISTS' .
      '(SELECT id FROM md5sum WHERE md5sum = files.md5sum LIMIT 1)'
   );
   return $count;
}

sub percentage_indexed {
	my $self = shift;
   debug(" .. ");
   $self->total_files_indexed or return 0.00;
   $self->total_files or return 0.00;
	my $percentage = sprintf '%0.2f', (($self->total_files_indexed * 100) / $self->total_files);
   debug("$percentage\n");
   
   return $percentage;	
}

sub files_locked {
	my $self = shift;
   
   debug('..');   
	my $r = $self->dbh->selectall_arrayref('SELECT files.abs_path, indexing_lock.timestamp, indexing_lock.hostname FROM files, indexing_lock WHERE files.md5sum = indexing_lock.md5sum ORDER BY indexing_lock.hostname, indexing_lock.timestamp');
   debug("$r\n");
   
   return $r;	
}

sub status_log_enter {
   my $self = shift;

   my $enter = $self->dbh_sth('INSERT INTO status_log (timestamp,total_files_indexed) values(?,?)');

   $enter->execute( time(), $self->total_files_indexed );

   $enter->finish;
   
   $self->dbh->commit;
   debug("done.\n");

   return 1;   
}

sub status_log_can_report {
   my $self = shift;
   my $log = $self->_status_log or return 0;
   return 1;
}

sub _status_log {
   my $self = shift;

   unless( defined $self->{_status_log_entries} ){      
   
      my $entries = $self->dbh->selectall_arrayref('SELECT timestamp,total_files_indexed FROM status_log ORDER BY timestamp');

      unless ( scalar @$entries > 1 ){
         warn('not enough entries');
         $self->{_status_log_entries} = 0;
         return 0;
      }
         
      $self->{_status_log_entries} = {
         start_indexed => $entries->[0]->[1],
         start_time    => $entries->[0]->[0],
         end_indexed   => $entries->[-1]->[1],
         end_time      => $entries->[-1]->[0],      
      };     
   
   }

   #   my $entries = $self->{_status_log_entries};
   #  ## $entries
   
   return $self->{_status_log_entries};
}

sub status_log_seconds {
   my $self = shift;
   my $log = $self->_status_log or return;

   my $secs = ( $log->{end_time} - $log->{start_time}  );
   return $secs;
}

sub status_log_count {
   my $self = shift;
   my $log = $self->_status_log or return;

   my $secs = ( $log->{end_indexed} - $log->{start_indexed}  );
   return $secs;
}

sub status_log_average {
   my $self = shift;
   $self->status_log_can_report or return;

   my $average = ( $self->status_log_seconds / $self->status_log_count );
   #printf STDERR " %s / %s = %s \n",$self->status_log_seconds, $self->status_log_count, $average;
   return $average;
}

sub status_log_remainder {
   my $self = shift;
   $self->status_log_can_report or return;

   my $remaining_seconds = (( $self->status_log_seconds * $self->total_files_pending ) / $self->status_log_count );
   return $remaining_seconds;  

}

=head2 status_log_remainder()

estimate of remaining seconds before all is indexed (assuming rate of indexing continues).
returns number

=head2 status_log_can_report()

returns boolean
if we have at least 2 entries, we can report.

=head2 status_log_seconds()

between first and last log entries, how many seconds appart
returns number

=head2 status_log_count()

between first and last log entries, how many were indexed
returns number

=head2 status_log_average()

average seconds each file took to index

=head2 status_log_remainder()

guess of how many more seconds until all files indexed
this is assuming indexing rate continues as has been bettween first interval and last interval.

=head2 status_log_enter()

will record timestamp and count of files indexed in the archive.

=head2 files_locked()

returns array ref of files locked for indexing
each element is an array ref with abs path, timestamp, and hostname of the lock
hostname may be undef(?) TODO

=head2 percentage_indexed()

returns percent of files indexed.

=head2 total_files_pending()

returns number of files awaiting indexing, not cached in object
this is a rough number for statistical purposes only
it really returns the total files minuss the total indexed.

please note that 3 files in different locations in the files table who share the same md5sum (copies) are counted as 1 file

=head2 total_files_pending_nocache()

same as total_files_pending, but not cached in object
if you want to get count of files pending, then index, and count again in same object instance, 
call total_files_indexed_nocache() instead.

The multiple options may seem redundant, but because of the nature of the cpu usage, both are useful.

=head2 total_files_indexed()

counts entries in the md5sum table

cached in object

=head2 total_files()

returns the count of files in the files table

cached in object

=head1 SEE ALSO

LFileArchiveIndexer>

=head1 AUTHOR

Leo Charre

=cut


1;
