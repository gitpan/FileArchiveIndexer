#!/usr/bin/perl -w
use Test::Simple 'no_plan';
use lib './lib';
use base 'LEOCHARRE::CLI';
use LEOCHARRE::PMUsed qw(modules_used_scan_tree module_is_installed);
use Cwd;
use strict;


print "install checklist\n=======\n
This script will check your system for dependencies that shoul be present to make full use of FileArchiveIndexer\n
This script makes no modifications to your system.\n";

print "
========
 PART 1
========\n
";



for (keys %{modules_used_scan_tree(cwd())}){
   ok( module_is_installed($_), "module [$_] is installed") or exit;
}





print "
========
 PART 2
========\n
";

# temp dir 

unless( -d '/tmp/PDF-OCR-Thorough-Cached' ){
   mkdir '/tmp/PDF-OCR-Thorough-Cached';
   print "mkdir /tmp/PDF-OCR-Thorough-Cached";
   ok( -d '/tmp/PDF-OCR-Thorough-Cached', " dir '/tmp/PDF-OCR-Thorough-Cached' exists") or die;
}



# conf

unless( ok(-f '/etc/faindex.conf','have /etc/faindex.conf file') ){
   print "missing /etc/faindex.conf file, this is a YAML format file and should be such as:
   ---
   DBHOST: localhost
   DBNAME: faindex
   DBPASSWORD: dbpasswerd
   DBUSER: faindexer
   SCP_HOST: wingnut
   SCP_USER: root
   DOCUMENT_ROOT: /var/www/dms/doc/Clients

SCP_HOST and SCP_USER are only needed to run as remote indexer.\n";
   exit;  

}

my $cnf = config('/etc/faindex.conf');
for (qw(DBHOST DBUSER DBPASSWORD DOCUMENT_ROOT)){
   ok( defined $cnf->{$_},"'/etc/faindex.conf' has $_") or die;
}

print "/etc/faindex.conf ok\n";


# database

print "will test database params.. ";

require FileArchiveIndexer;

my $fai = new FileArchiveIndexer($cnf);

ok($fai, 'FileArchiveIndexer instanced') or die;

ok($fai->dbh, "can connect to database") or die;




# non perls

require File::Which;

for (qw(pdftk tesseract pdfimages)){
   ok( File::Which::which($_), " found path to executable $_") or die; 
}







