package FileArchiveIndexer::WUI;
use strict;
use warnings;
use base 'CGI::Application';
use CGI::Application::Plugin::AutoRunmode;
use CGI::Application::Plugin::TmplInnerOuter;
use FileArchiveIndexer::WUI::Base;

use HTML::Entities;
use LEOCHARRE::DEBUG;
our $VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)/g;



sub setup {
   my $self = shift;
   $self->start_mode('fai_status');
   $self->mode_param('rm');
   $self->header_props( -no_cache => 1 );
}

sub fai_status : Runmode {
   my $self = shift;

   $self->_set_tmpl_default(_tmpl_default_fai_status());   
   $self->_set_vars_fai_status;       
   return $self->tmpl_output;
}

sub fai_search : Runmode {
   my $self = shift;

   $self->_set_tmpl_default(_tmpl_default_fai_search());   
   return $self->tmpl_output;   
}


sub fai_search_results : Runmode {
   my $self = shift;

	$self->_set_tmpl_default(_tmpl_default_fai_search_results());   

   
   my $search_text = $self->_fai_search_results_text or die('missing user text to search');
   
   
   $self->fai->execute($search_text);

   $self->_set_vars( 
         FAI_SEARCH_RESULTS_COUNT => $self->fai->results_count,
         FAI_SEARCH_RESULTS_TEXT => encode_entities($search_text),
   );
   

   if ($self->fai->results_count){
      
      my @loop;

      for ( @{$self->fai->results_files} ){      
         my $abs_path = $_;
         my $result_hits_loop = $self->_get_result_hits_loop($abs_path);   
         
         push @loop, {
            PATH              => $abs_path,
            RESULT_HITS_LOOP  => $result_hits_loop,
         };
      }

      $self->_set_vars( 
         FAI_SEARCH_RESULTS_LOOP => \@loop 
      );   
   }


   return $self->tmpl_output;
}


# end runmodes


no warnings 'redefine';
sub tmpl_output {
   my $self = shift;

   $self->_set_tmpl_default(q{
   <html>
   <head>
   <title>File ArchiveIndexer</title>
   </head>
   <body>
   
   <h5>File Archive Indexer <TMPL_VAR API_VERSION></h5>
	<p><a href="?rm=fai_status">status</a> : <a href="?rm=fai_search">search</a></p>

   <div>   
   <TMPL_VAR BODY>
   </div>   

	<p>Refreshed every 10 minutes.</p>	
	</body>
	</html>},'main.html');

   # set any vars?
   $self->_set_vars( API_VERSION => $VERSION );
   
   $self->_feed_vars_all;
   $self->_feed_merge;
   return $self->tmpl_main->output;
}






1;

__END__

=pod


=head1 NAME

FileArchiveIndexer::WUI - web user interface for searching the archive

=head1 DESCRIPTION

The module uses CGI::Application to provide screens (runmodes) so a user agent can be used to
search indexed data, see status of indexing, etc.

This module is only an interface. Please see L<FileArchiveIndexer> for more information.

=head1 SEE ALSO

L<FileArchiveIndexer::WUI::Base>

L<FileArchiveIndexer>
L<CGI::Application>

=head1 AUTHOR

Leo Charre leocharre at cpan dot org

=cut




