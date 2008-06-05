package FileArchiveIndexer::Logging;
use strict;
use warnings;
use FileArchiveIndexer::DEBUG;
use Time::Format 'time_format';

sub _log {
   my $self = shift;
   my $errormsg = shift;
   
   my $log = $self->abs_log or return; 
   
   open(LOG, ">>$log") or warn("cant open log $log") and return;
   print LOG time_format('[yyyy_mm_dd hh:mm]',time) ." $errormsg\n";
   close LOG;
   return;   
}

sub abs_log {
   my $self = shift;
   defined $self->{abs_log} and $self->{abs_log} or return;
   return $self->{abs_log};
}   

sub _log_run_summary {
   my $self = shift;
   
   $self->abs_log or return; 

   my $log = sprintf "
   running as remote indexer: %s
   started: %s
   ended: %s
   run_max: %s
   run_count: %s
   
   ", 
   $self->_running_as_remote_indexer,
   time_format('yyyy/mm/dd hh:mm',$self->{start_time}),
   time_format('yyyy/mm/dd hh:mm',time()),
   $self->run_max,
   $self->run_count;

   print STDERR $log if DEBUG;

   $self->_log($log);

   return 1;
}

=head2 _log()

argument is error message
puts time in automatically

if we defined via constructor 'abs_log' will attempt to write errors there
warns if we cant write to that
to change the default log
specify as argument 'abs_log' to constructor


=head2 abs_log()

=head2 _log_run_summary()

=cut

1;
