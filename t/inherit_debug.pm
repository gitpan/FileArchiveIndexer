package inherit_debug;
use lib './lib';
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




1;
