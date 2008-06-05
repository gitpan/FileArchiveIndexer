use Test::Simple 'no_plan';
use strict;
use lib './lib';

use FileArchiveIndexer::WUI;

$FileArchiveIndexer::WUI::DEBUG = 1;

$ENV{CGI_APP_RETURN_ONLY} = 1; # otherwise prints to screen and test fails

my $w;

ok( $w  = new FileArchiveIndexer::WUI, "instance FileArchiveIndexer::WUI") or die('fatal test failure');

ok( $w->run,'invoking run() on instance');


