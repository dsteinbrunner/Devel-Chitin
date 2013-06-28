package Devel::CommonDB::SourceCache;

use strict;
use warnings;

use Devel::CommonDB::SourceFile;

{
    my %cache;
    sub get {
        my $self = shift;
        my $file = shift;
        unless (exists $cache{$file}) {
            my $file_class = $self->cached_file_class;
            $cache{$file} = $file_class->new($file);
        }
        return $cache{$file};
    }
}

sub cached_file_class { 'Devel::CommonDB::SourceFile' }

1;
