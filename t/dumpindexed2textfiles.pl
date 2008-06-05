#!/usr/bin/perl
use strict;
use FileArchiveIndexer;
use base 'Dyer::CLI';
use strict;
use File::Path;
use Smart::Comments '###';

my $conf = config('/etc/faindexer.conf');
my $pconf = config('/etc/pdf2ocr.conf');


my $abs_cache = $pconf->{abs_cache};
-d $abs_cache or mkdir $abs_cache or die("cant mkdir $abs_cache");



# select all indexed files


my $i= new FileArchiveIndexer($conf);

my $allindexed = $i->dbh->selectall_arrayref(
	'SELECT files.abs_path, md5sum.id FROM files,md5sum WHERE files.md5sum = md5sum.md5sum AND NOT EXISTS 
		(SELECT * FROM indexing_lock WHERE files.id = indexing_lock.id)');

printf STDERR " all indexed were %s\n", scalar @$allindexed;




my $tq = $i->dbh->prepare('SELECT content,page_number,line_number FROM data WHERE id = ? ORDER BY page_number, line_number');



for(@$allindexed){ ### Saving <%===      >
	my ($abs_path, $md5sumid) = @$_;
	
	$tq->execute($md5sumid);
	
#	printf STDERR "id $md5sumid, $abs_path ";
	
	my $text;

	my $pn='start';
	
	while (my @row = $tq->fetchrow_array){
		my($content, $page_number, $line_number) = @row;
		
		if($pn eq 'start'){
			$pn = $page_number;
		}
		else{
			unless( $pn == $page_number ){
				$text.="\f"; 
			#	print STDERR "inserted pagebreak $page_number\n";	
				$pn = $page_number;
			}
		}
		
		#print STDERR "pg $page_number, line $line_number\n";
		$text.=$content."\n";		
	}
	
	my $loc = "$abs_cache/$abs_path";
	$loc=~s/\/+[^\/]+$//;
	File::Path::mkpath($loc);

	## $text

	open(FILE,'>'."$abs_cache/$abs_path.txt");
	print FILE $text;
	close FILE;

	#print STDERR "'$abs_cache/$abs_path.txt' \n\n";	

}


