package FileArchiveIndexer::WUI::Base;
use FileArchiveIndexer::Search;
use Time::Format 'time_format';
use Carp;
use Exporter;
use strict;
use warnings;
use vars qw(@ISA @EXPORT %EXPORT_TAGS @EXPORT_OK $VERSION);
@ISA = qw/Exporter/;
my @subs = qw(_tmpl_default_fai_search _tmpl_default_fai_search_results _tmpl_default_fai_status);
my @methods = qw(_set_vars_fai_search_results _set_vars_fai_status _data_fai_status fai _fai_search_results_text _get_result_hits_loop);
@EXPORT_OK =( @subs, @methods );
@EXPORT = @EXPORT_OK; # at present
%EXPORT_TAGS = (
   subs => \@subs,
   methods => \@methods,
   all => \@EXPORT_OK,
);
use LEOCHARRE::DEBUG;
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)/g;


sub _tmpl_default_fai_search {
   
   my $default = q{
   <h1>Search</h1>
   
   <form>
   <p>Search for what text inside the archive: <input type="text" name="search_text"></p>
   <p><input type="submit" value="search"></p>
   <input type="hidden" name="rm" value="fai_search_results">
   </form>
   
   </body>
   </html>};
   return $default;
}

sub _tmpl_default_fai_search_results {
   
   my $default = q{
   <h1>Search Results</h1>
	<p>Searched for <code><TMPL_VAR FAI_SEARCH_RESULTS_TEXT></code></p>
	<p>Found <TMPL_VAR FAI_SEARCH_RESULTS_COUNT> hits.</p>
	
	<TMPL_IF FAI_SEARCH_RESULTS_COUNT>
	
	   <ul>
	   <TMPL_LOOP FAI_SEARCH_RESULTS_LOOP>
	    <li>
	      <b><TMPL_VAR PATH></b>
	      <ul><TMPL_LOOP RESULT_HITS_LOOP><li><small>page <TMPL_VAR PAGE_NUMBER>, line <TMPL_VAR LINE_NUMBER>, content </small><br><code><TMPL_VAR CONTENT></code></li></TMPL_LOOP></ul>
	    </li>
	   </TMPL_LOOP>
	   </ul>	
	
	</TMPL_IF>};
   return $default;
}

sub _tmpl_default_fai_status {

   my $default = q{
  	<h1>Status</h1>
	
	<ul>
	<li>Total files: <TMPL_VAR FAI_TOTAL_FILES></li>
	<li>Total files indexed: <TMPL_VAR FAI_TOTAL_FILES_INDEXED></li>
	<li>Total files pending: <TMPL_VAR FAI_TOTAL_FILES_PENDING></li>
	<li>Percent indexed: <TMPL_VAR FAI_PERCENT_INDEXED></li>
	
	<TMPL_IF FAI_LOCKED_SHOW>
	<li>Presently locked for indexing:
	   <ul>
	   <TMPL_LOOP FAI_LOCKED>
	      <li><TMPL_VAR TIME> <TMPL_VAR PATH></li>
	   </TMPL_LOOP>
	   </ul>
	</li>
	</TMPL_IF>
	
	</ul>};
   return $default;
}




# OO METHODS 

sub _set_vars_fai_status {
   my $self = shift;
   

   my $status = $self->_data_fai_status;

   $self->_set_vars(
      FAI_TOTAL_FILES => $status->{total},
      FAI_TOTAL_FILES_INDEXED => $status->{indexed},
      FAI_TOTAL_FILES_PENDING => $status->{pending},
      FAI_PERCENT_INDEXED => $status->{percent},
   );

   if (scalar @{$status->{locked}}){

      my $loop;
      
      for ( @{$status->{locked}} ){
         push @$loop, {
               TIME => time_format('yy/dd/mm hh:mm',$_->[1]), 
               PATH => $_->[0],
         };
      }
   
      $self->_set_vars(
         FAI_LOCKED => $loop,
         FAI_LOCKED_SHOW => 1,
      );
   }
   return 1;
}

sub _data_fai_status {
   my $self = shift;

   #my $status = $self->cache->thaw('status');

  # unless($status){
   
      my $_status = {
         total => $self->fai->total_files,
         indexed => $self->fai->total_files_indexed,
         pending => $self->fai->total_files_pending,
         percent => $self->fai->percentage_indexed,
         locked => $self->fai->files_locked,      
      };
     # $self->cache->freeze('status',$_status);
   #   $status = $_status;
   #}

   return $_status;
}

sub fai {
   my $self = shift;
   $self->{fai} ||= new FileArchiveIndexer::Search({abs_conf=>'/etc/faindex.conf'});
   return $self->{fai};
}

sub _fai_search_results_text {
   my $self = shift;
   my $paramname = shift;
   $paramname ||= 'search_text';

   my $search_text = $self->query->param($paramname);
   (defined $search_text and $search_text=~/\w/) or warn("no search text provided in param '$paramname'") and return;
   return $search_text;
} 

sub _get_result_hits_loop {
   my ($self,$abs) = @_; 
   defined $abs or confess('missing abs result arg');
   
   require HTML::Entities;

   my @result_hits_loop;

   my $matches = $self->fai->result($abs);
   
   for (@$matches){
      my($page,$line,$content) = @$_;
      push @result_hits_loop,{
               PAGE_NUMBER => $page,
               LINE_NUMBER => $line,
               CONTENT => HTML::Entities::encode_entities($content),
      };
   }

   return \@result_hits_loop;
}

sub _set_vars_fai_search_results {
   my $self = shift;
   
   my $search_text = $self->_get_fai_search_text or warn('no text to search requested?') and return 0;

   $self->_set_vars( 
      FAI_SEARCH_RESULTS_COUNT => $self->fai->results_count,
      FAI_SEARCH_RESULTS_TEXT => encode_entities($search_text),
   );

   return 1;
}


1;


__END__


=head1 SYNOPSIS

   use FileArchiveIndexer::WUI::Base;

=cut



=head1 NOT METHODS

=head2 _tmpl_default_fai_status()

returns default template code

=head2 _tmpl_default_fai_search()

=head2 _tmpl_default_fai_search_results()

=cut








=head1 METHODS

=head2 _set_vars_fai_status()

set variables to later inject
See CGI::Application::Plugin::TmplInnerOuter

=head2 fai()

returns FileArchiveIndexer api object

=head2 _fai_search_results_text()

optional argument is param name to look inside
default param name is 'search_text'
returns undef if none. 

See L<Building A Search Results Runmode>



=head2 Building A Search Results Runmode


   sub fai_search_results : Runmode {
      my $self = shift; 
      
      $self->_fai_search_results_text('search_text') or die('user did not enter search text'); # search_text is the default
      # or
      $self->_fai_search_results_text() or die('user did not enter search text');

      $self->fai->execute($search_text);

      $self->fai->results_count;

      $self->fai->results_files;

      foreach my $abs_found ( $self->fai->results_files ){
         
         my $matches = $self->fai->result($abs_found);

         # "You found $abs_found";
         # "inside that file are the following matches to your search for $search_text;
         
         for (@$matches){
            my($page_number, $line_number, $content_matched ) = @$_;
            # "page num : $page_number, line num : $line_number, content: $content_matched"
         }
   
      }

=head2 _get_result_hits_loop()

argument is abs path of the file found, returns array ref suitable as an HTML::Template loop.


   my @RESULTS;
   
   foreach my $abs_found ( $self->fai->results_files ){
      
      my resultloop = $self->_get_result_hits_loop( $abs_found );

      push @RESULTS, {
         RESULT_ABS_FOUND => $abs_found,
         RESULT_HITS => $resultloop,
      };      
   }

   $tmpl->param( RESULTS => \@RESULTS );

This would be suitable for:

      <ul>
	   <TMPL_LOOP RESULTS>
	    <li>
	       <b><TMPL_VAR  RESULT_ABS_FOUND></b>
	      <ul>
             <TMPL_LOOP RESULT_HITS><li><small>page <TMPL_VAR PAGE_NUMBER>, line <TMPL_VAR LINE_NUMBER>, content </small><br><code><TMPL_VAR CONTENT></code></li></TMPL_LOOP>
         </ul>
	    </li>
	   </TMPL_LOOP>
	   </ul>	

=head2 _set_vars_fai_search_results()

sets vars :

   FAI_SEARCH_RESULTS_COUNT
   FAI_SEARCH_RESULTS_TEXT
   
=cut



