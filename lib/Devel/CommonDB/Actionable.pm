package Devel::CommonDB::Actionable;

use strict;
use warnings;

#use Digest::MD5 qw(md5);
use List::Util;
use Carp;

use Devel::CommonDB::SourceCache;

sub new {
    my $class = shift;

    my %params = __required([qw(file line code)], @_);

    my $self = \%params;
    bless $self, $class;
    $self->_insert();
    return $self;
}

sub __required {
    my $required_params = shift;
    my %params = @_;
    do { defined($params{$_}) || Carp::croak("$_ is a required param") }
        foreach @$required_params;
    return %params;
}

sub _canon_line {
    my($file, $line) = @_;
    my $cached = Devel::CommonDB::SourceCache->get($file);
    return $cached ? $cached->canon_line($line) : $line;
}

sub _debugger_line {
    my($file, $line) = @_;
    my $cached = Devel::CommonDB::SourceCache->get($file);
    return $cached ? $cached->debugger_line($line) : $line;
}

sub get {
    my $class = shift;
    return $class if (ref $class);

    my %params = __required([qw(file)], @_);

    our %dbline;
    local(*dbline) = $main::{'_<' . $params{file}};
    return unless %dbline;

    my @candidates;

    my $type = $class->type;
    if (!$params{line}) {
        @candidates =
              map { $_->{$type} ? @{$_->{$type}} : () } # only lines with the type we're looking for
              grep { $_ }      # only lines with something
              values %dbline;  # All action/breakpoint data for this file
    } else {
        my $line = _debugger_line($params{file}, $params{line});

        @candidates = ($dbline{$line} && $dbline{$line}->{$type})
                    ? @{ $dbline{$line}->{$type}}
                    : ();
    }
            
    if ($params{code}) {
        @candidates = grep { $_->{code} eq $params{code} }
                        @candidates;
    }

    return @candidates;
}

sub _insert {
    my $self = shift;

print "Inserting $self at line ",$self->line,"\n";
    my $line = _debugger_line($self->file, $self->line);
print "  line corrected to $line\n";

    # Setting items in the breakpoint hash only gets
    # its magical DB-stopping abilities if you're in
    # pacakge DB.  Otherwise, you can alter the breakpoint
    # data, other users will see them, but the debugger
    # won't stop
#    my $bp_info;
#    {package DB;
#    local(*dbline) = $main::{'_<' . $self->file};
#    our %dbline;
#
#    #my $bp_info = $dbline{$line} ||= {};
#    $bp_info = $dbline{$line} ||= {};
#}
    package DB;
    local(*dbline) = $main::{'_<' . $self->file};
    our %dbline;
    $dbline{$line} = 1;

#    my $type = $self->type;
#    push @{$bp_info->{$type}}, $self;

    #my $actionable = $bp_info->{$type} ||= [];
    #push @$actionable, $self;
}

#sub _id {
#    my $self = shift;
#    md5(join('', @$self{'file', 'line', 'code'}, $self->type));
#}

sub delete {
    my $self = shift;

    my($file, $line, $code, $type, $self_ref);
    if (ref $self) {
        ($file, $line, $code) = map { $self->$_ } qw(file line code);
        $type = $self->type;
        $self_ref = $self . '';
    } else {
        my %params = __required([qw(file line code type)], @_);
        ($file, $line, $code, $type) = @params{'file','line','code','type'};
    }

    $line = _debugger_line($file, $line);

    our %dbline;
    local(*dbline) = $main::{'_<' . $file};
    my $bp_info = $dbline{$line};
    return unless ($bp_info && $bp_info->{$type});

    my $bp_list = $bp_info->{$type};
    for (my $i = 0; $i < @$bp_list; $i++) {
        my($its_file, $its_line, $its_code) = map { $bp_list->[$i]->$_ } qw(file line code);
        if ($file eq $its_file
            and
            $line == $its_line
            and
            $code eq $its_code
            and
            ( defined($self_ref) ? $self_ref eq $bp_list->[$i] : 1 )
        ) {
            splice(@$bp_list, $i, 1);
            last;
        }
    }

    if (! @$bp_list) {
        # last breakpoint/action removed for this line
        delete $bp_info->{$type};
    }

    if (! %$bp_info) {
        # No breakpoints or actions left on this line
        $dbline{$line} = undef;
    }
    return $self;
}

 
sub file    { return shift->{file} }
sub line    { return shift->{line} }
sub code    { return shift->{code} }
sub once    { return shift->{once} }
sub type    { my $class = shift;  $class = ref($class) || $class; die "$class didn't implement method type" }

sub inactive {
    my $self = shift;
    if (@_) {
        $self->{inactive} = shift;
    }
    return $self->{inactive};
}

package Devel::CommonDB::Breakpoint;

use base 'Devel::CommonDB::Actionable';

sub type() { 'condition' };

package Devel::CommonDB::Action;

use base 'Devel::CommonDB::Actionable';

sub type() { 'action' };

1;


