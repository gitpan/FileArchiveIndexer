package FileArchiveIndexer::Search;
use strict;
use Carp;
use base 'FileArchiveIndexer';
$FileArchiveIndexer::Search::DEBUG = 0;
sub DEBUG : lvalue { $FileArchiveIndexer::Search::DEBUG }

=pod

=head1 NAME

FileArchiveIndexer::Search

=head1 DESCRIPTION

=cut

sub search {
   my $self = shift;
   

}

sub execute {
	my $self = shift;
	my $term = shift; $term=~/\w{3,}/ or warn("argument to execute negigible") and return;
	my $in = shift; $in ||=[];

	
	
	my $query = qq{SELECT id, page_number, line_number, content FROM data WHERE MATCH (content) AGAINST ('$term') LIMIT 1000};

   if ($self->dbh_is_sqlite){
	   $query = qq{SELECT id, page_number, line_number, content FROM data 
      WHERE content LIKE '\%$term%' LIMIT 1000};
   }
   
	my $all = $self->dbh->selectall_hashref($query,'id');

	## $all
	
	if (DEBUG){
		printf STDERR " query executed, got \n", scalar keys %$all;
	}	

	my $results =[];
	
	REFILTER : for (keys %$all){
		my $id = $_;		
		my $r = $all->{$id};
		
		my $abs_path;
      
      unless( $abs_path = $self->_abs_path_by_md5id($id) ){
		   warn("md5sum id $id does not fetch abs path") if DEBUG;
         next;		
      }


		if (scalar @$in){
			_inok($abs_path,$in) or next REFILTER;		
		}
		
		push @$results , [ $abs_path, $r->{page_number}, $r->{line_number}, $r->{content} ];	
	}
	
	$self->{results} = $results;
	
	$self->_format_results($results);
	
	return scalar @$results;

	sub _inok {
		my ($abs, $in)  = @_;
		for (@$in){
			my $ok = $_;		
			$abs=~/^$ok/ or next;
			return 1;
		}
		return 0;
	}
	
}



sub _format_results {

	my $self = shift;
	my $results = shift;

	print STDERR "formatting results.. " if DEBUG;
	
	for (@{$results}){
		my ($abs_path,$page_number,$line_number,$content) = @$_;
         print STDERR " result = $page_number $line_number $abs_path\n" if DEBUG;		
		push @{$self->{results_by_path}->{$abs_path}}, [$page_number,$line_number,$content];			
		$self->{hits}->{$abs_path}++;					
	}
	
	@{$self->{results_files}} = keys %{$self->{results_by_path}};	

	print STDERR "done.\n" if DEBUG;

	return 1;
}






sub _abs_path_by_md5id {
	my ($self, $md5sumid) = @_; defined $md5sumid or warn('missing md5sum id arg') and return;

	$self->{handles}->{apbmi} ||= $self->dbh->prepare('SELECT files.abs_path FROM files,md5sum WHERE files.md5sum = md5sum.md5sum AND md5sum.id = ? LIMIT 1');
	$self->{handles}->{apbmi}->execute($md5sumid);
	
	my @row = $self->{handles}->{apbmi}->fetchrow_array;

	unless( scalar @row ){
      warn("md5sum id $md5sumid none found") if DEBUG;
      return;
   }

	my $abs_path = $row[0];
	return $abs_path;
}

sub results_by_path {
	my $self = shift;
	return $self->{results_by_path};
}

=head2 results_by_path()

returns hash ref, each key is an abs path to a file, each value is an array ref with results

=cut

sub results_files {
	my $self = shift;	
	return $self->{results_files};
}

=head2 results_files()

returns array ref to files foumd

=cut

sub result {
	my ($self, $abs_path) = @_;
	return $self->results_by_path->{$abs_path};
}

=head2 result()

argument is abs path of the match
returns array ref with matches inside that file

	my($page,$line,$content) = @{$s->result($abs_hit)};

=cut

sub raw_results {
	my $self = shift;
	$self->{results} ||=[];
	return $self->{results};
}

sub results_count {
	my $self= shift;
	$self->{results_count} ||= scalar @{$self->raw_results};
	return $self->{results_count};	
}

=head2 raw_results()

=head2 results_count()

=head2 dbh()

returns database handle


=head2 execute()

perform the search

	$i->execute('looking for this text');

Optional argument is array ref of paths to prune in, only inside those paths.



=head1 SYNOPSIS

   my $fai = new FileArchiveIndexer({ abs_conf => '/etc/faindexer.conf' });
   
   
   my $results = $fai->search('my text');
	
	my $files = $results->results_files;

	for (@$files){
		my $matches = $results->result($_);

		print "file $_\n"

		for (@$matches){
			my($page, $line, $content) = @$_;
			print "page $page, line $line, content [$content]\n";
		}
	}

=head1 SEE ALSO

L<FileArchievIndexer>

=head1 AUTHOR

Leo Charre leocharre at cpan dot org

=cut

1;



