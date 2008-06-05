#!/usr/bin/perl -w
use strict;
use lib './lib';
use FileArchiveIndexer;
use Digest::MD5::File 'file_md5_hex';
use Digest::MD5 'md5_hex';
use YAML;
use warnings;
use Smart::Comments '###';

=for


i was getting md5sums for the abs path string, NOT the file contents.. great

now I gotta fix em

=cut


# first get all abs paths in files table


my $conf = YAML::LoadFile('/etc/faindexer.conf');
my $i = new FileArchiveIndexer($conf);




my $all = $i->dbh->selectall_arrayref(
	'SELECT abs_path FROM files LIMIT 1'
	) or die($i->dbh->stderr);


printf STDERR "all: %s\n", scalar @$all;

my $fix = $i->dbh->prepare('UPDATE md5sum SET md5sum=? WHERE md5sum=?') or die($i->dbh->stderr);


my $fixes = [];

# get the wrong md5sums, the right md5sums
for (@$all){ 
	my ($abs_path, $wrongmd5sum, $rightmd5sum) =($_->[0], undef, undef);
	-f $abs_path or warn("!-f $abs_path") and next;
	$wrongmd5sum = md5_hex($abs_path);
	$rightmd5sum = file_md5_hex($abs_path);
	if ($wrongmd5sum eq $rightmd5sum){ warn("right and wrong for $abs_path same, skipping"); next; }
	push @$fixes,[$rightmd5sum,$wrongmd5sum];
	print STDERR"$abs_path\nright: $rightmd5sum\nwrong: $wrongmd5sum\n\n";


}
print STDERR "got md5sums.. updating..\n";

## $fixes

for(@$fixes){ 
	$fix->execute(@$_);	
	
}

printf STDERR "fixes %s\n", scalar @$fixes;

$i->dbh->commit;



exit;




