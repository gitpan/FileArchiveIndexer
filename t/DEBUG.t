use Test::Simple 'no_plan';
use strict;
use lib './t';
use inherit_debug;

my $o = new inherit_debug;

$inherit_debug::DEBUG = 1;

ok( $o->test );


$inherit_debug::DEBUG=0;

ok( !($o->test) );


