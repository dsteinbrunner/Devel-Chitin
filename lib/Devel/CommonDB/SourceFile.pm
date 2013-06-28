package Devel::CommonDB::SourceFile;

use strict;
use warnings;

use IO::File;
use Cwd;


# If a program's shebang line includes something like
# /usr/bin/perl -d:SomeDebugger, perl inserts a "fake" line 1 that
# looks like:
# use Devel::SomeDebugger
# ;
# Notice that the fake line has a newline in it.  If the debugger is
# started using -d:SomeDebugger on perl's command line, then the
# fake line is line 0 (which never occurs in any real program).
#
# One issue is that starting with perl 5.12, and in the shebang case,
# it also inserts another fake line 2 containing undef.  We want to hide
# this difference, and so the cached source code won't contain this empty
# fake line and we'll have to adjust + or - one line when interacting
# with the user
my($line_adjustment, $adjustment_file);

# This is also initialized in the BEGIN block
my $original_cwd;

sub FAKE_LINE_NUMBER { 2 }
BEGIN {
    $adjustment_file = '';

    if ($main::{'_<'.$0}) {
        use vars '@dbline';
        local *dbline = $main::{'_<'.$0};
        if (($^V gt v5.10.1)
            &&
            ! defined($dbline[FAKE_LINE_NUMBER])
            &&
            $dbline[1] =~ m/use Devel::.*\n;/
        ) {
            $line_adjustment = 1;
            $adjustment_file = $0;
        }
    }
    $original_cwd = Cwd::getcwd();
}

sub new {
    my($class, $file) = @_;

    my $self = {
                file => $file,
                adj  => $adjustment_file eq $file ? $line_adjustment : 0,
            };
    bless $self, $class;
    $self->_load;
    return $self;
}

sub typeglob {
    my $self = shift;
    return $main::{'_<' . $self->file};
}

sub linebreaks {
    my $glob = shift->typeglob;
    return unless $glob;
    return *{$glob}{HASH};
}

sub linestrings {
    my $glob = shift->typeglob;
    return unless $glob;
    return *{$glob}{ARRAY};
}

sub _load {
    my $self = shift;

    my @lines;
    if (my $lines = $self->linestrings) {
        @lines = @{$lines};
        if ( $self->_adjustment ) {
            splice(@lines, FAKE_LINE_NUMBER, 1);  # Remove the 'fake' undef line
        }
    } else {
        # Wasn't loaded when debug flags were on - load it ourselves
        my $fh = IO::File->new($self->file, 'r');
        if (! $fh and substr($self->file, 0, 1) ne '/') {
            # didn't open here and it was as relative pathname.  Try again by
            # prepending the original current working directory
            $fh = IO::File->new($original_cwd . $self->file, 'r');
        }
        return unless $fh;

        for ( my $i = 1; my $line = $fh->getline; $i++) {
            $lines[$i] = $line;
        }
    }
    $self->{lines} = \@lines;

    return $#lines || '0 but true';
}

sub lines {
    return @{ shift->{lines} };
}

sub breakable_lines {
    my $self = shift;

    my $linestrings = $self->linestrings;
    return  map { $self->canon_line($_) }
            grep { $linestrings->[$_] != 0 }
            ( 1 .. $#$linestrings )
}

sub line_count {
    return scalar shift->lines;
}

sub line {
    my($self, $line) = @_;
    return $self->{lines}->[$line];
}

sub file {
    return shift->{file};
}

sub _adjustment {
    return shift->{adj};
}

sub canon_line {
    my($self, $line) = @_;
    return $line - $self->_adjustment;
}

sub debugger_line {
    my($self, $line) = @_;
    return $line + $self->_adjustment;

}

sub data {
    my $self = shift;
    my $key = shift;
    return unless defined($key);

    if (@_) {
        $self->{datA}->{$key} = shift;
    }
    return $self->{data}->{$key};
}

1;

__END__

=pod

=head1 NAME

Devel::CommonDB::SourceFile - Methods for manipulating Perl source in the debugged program

=head1 SYMOPSIS

  my $file = Devel::CommonDB::SourceCache->get('/path/to/file.pl');

  print "name is ",     $file->name, "\n";
  print "line 4 is ",   $file->line(4), "\n";
  print "There are ",   $file->line_count, " lines\n";

=head1 DESCRIPTION

=head1 AUTHOR

Anthony Brummett <brummett@cpan.org>

=head1 COPYRIGHT

Copyright 2013, Anthony Brummett.  This module is free software. It may
be used, redistributed and/or modified under the same terms as Perl itself.

