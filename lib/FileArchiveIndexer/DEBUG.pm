package FileArchiveIndexer::DEBUG;
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT=qw(&DEBUG $DEBUG &debug);

our $DEBUG = 0;
sub DEBUG : lvalue { $DEBUG }

$DEBUG::_last_had_newline=1;

sub debug {
   my $msg = shift;
   DEBUG or return 1;
   my $sub = (caller(1))[3];   $sub=~s/^.*:://;

   if( $DEBUG::_last_had_newline ){
      print STDERR " $sub(),";      
   } 
 
   print STDERR " $msg";   

   $DEBUG::_last_had_newline = ( $msg=~/\n$/ ? 1 : 0  );
   
   return 1;   
}

1;

=pod

=head1 NAME

FileArchiveIndexer::DEBUG - debug subs for FileArchiveIndexer

=head1 SYNOPSIS

In A.pm

   package A;
   use FileArchiveIndexer::DEBUG;
   use strict;


   sub new {
      my $class = shift;
      my $self ={};
      bless $self, $class;
      return $self;   
   }

   sub test {
      my $self = shift;
      DEBUG or return 0;
      return 1;
   }

In script.t

   use Test::Simple 'no_plan';
   use strict;
   use A;

   my $o = new A;

   $A::DEBUG = 1;
   ok( $o->test );

   $A::DEBUG = 0;
   ok( !($o->test) );


=head1 DEBUG()

returns boolean

   print STDERR "oops" if DEBUG;

=head1 debug()

argument is message, will only print to STDERR if  DEBUG is on.

   debug('only show this if DEBUG is on');

If your message argument does not end in a newline, next message will not be prepended with
the subroutine name.

   sub dostuff {
      debug("This is..");

      # ...

      debug("done.\n");

      debug("ok?");      
   }

Would print

   dostuff(), This is.. done.
   dostuff(), ok?
