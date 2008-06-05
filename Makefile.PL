use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'FileArchiveIndexer',
    VERSION_FROM      => 'lib/FileArchiveIndexer.pm', # finds $VERSION
    PREREQ_PM         => {
      'LEOCHARRE::CLI' => '1.01',
      'LEOCHARRE::DEBUG' => '1.02',
      'PDF::OCR::Thorough' => 0,
      'Smart::Comments' => 0,
      'File::Find::Rule' => 0,
      'File::PathInfo::Ext' => '1.14',
      'DBI' => 0,# 
      'DBD::SQLite' => 0, # for testing
      'DBD::mysql' => 0,
      'File::Path' => 0,
      'Carp' => 0,
      'Digest::MD5' => 0,
      'Benchmark::Timer' => 0,
      'Digest::MD5::File' => 0,
      'LEOCHARRE::PMUsed' => 0,
      'CGI::Application' => 0,
      'CGI::Application::Plugin::TmplInnerOuter' => 0,
      'CGI::Application::Plugin::AutoRunmode' => 0,
      'HTML::Template::Default' => 0,
	 },
    EXE_FILES               => [qw(bin/faiupdate bin/faindex bin/faisearch bin/faistatus)],
);
