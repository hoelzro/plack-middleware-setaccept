## no critic (RequireUseStrict)
package Plack::Middleware::SetAccept;

## use critic (RequireUseStrict)
use strict;
use warnings;
use parent 'Plack::Middleware';

use Carp;

sub prepare_app {
    my ( $self ) = @_;

    my ( $from, $mapping, $param ) = @{$self}{qw/from mapping param/};

    unless($from) {
        croak "'from' parameter is required";
    }
    unless($mapping) {
        croak "'mapping' parameter is required";
    }
    $from  = [ $from ] unless ref($from);
    if(grep { $_ ne 'suffix' && $_ ne 'param' } @$from) {
        croak "'$from->[0]' is not a valid value for the 'from' parameter";
    }
    if(grep { $_ eq 'param' } @$from) {
        unless($param) {
            croak "'param' parameter is required when using 'param' for from";
        }
    }

    unless(ref($mapping) eq 'HASH') {
        croak "'mapping' parameter must be a hash reference";
    }
}

sub extract_format {
    my ( $self, $env ) = @_;

    my $format;
    my $from = $self->{'from'};

    $from = [ $from ] unless ref $from;

    foreach (@$from) {
        last if defined $format;

        if($_ eq 'suffix') {
            my $path = $env->{'PATH_INFO'};
            if($path =~ /\.(.+)$/) {
                $format = $1;
                $env->{'PATH_INFO'} = $`;
            }
        } elsif($_ eq 'param') {
            ...
        } else {
            ...
        }
    }
    return $format;
}

sub acceptable {
    my ( $self, $accept ) = @_;
    ## simple, stupid implementation
    return grep { $_ eq $accept } values %{ $self->{'mapping'} };
}

sub unacceptable {
    my ( $self, $env ) = @_;

    my $host;
    unless($host = $env->{'HTTP_HOST'}) {
        $host = $env->{'SERVER_NAME'};
        unless($env->{'SERVER_PORT'} == 80) {
            $host .= ':' . $env->{'SERVER_PORT'};
        }
    }
    my $path = $env->{'PATH_INFO'};

    my $links = '<ul>';
    foreach my $format (sort keys %{$self->{'mapping'}}) {
        my $type = $self->{'mapping'}{$format};
        $links .= "<li><a href='http://$host$path.$format'>$type</a></li>";
    }
    $links .= '</ul>';
    return [
        406,
        ['Content-Type' => 'text/html'],
        [$links],
    ];
}

sub call {
    my ( $self, $env ) = @_;

    my $format = $self->extract_format($env);

    if(defined $format) {
        my $mapping = $self->{'mapping'}{$format};
        if(defined $mapping) {
            my @accept = split /\s*,\s*/, $env->{'HTTP_ACCEPT'} || '';
            push @accept, $mapping;
            $env->{'HTTP_ACCEPT'} = join(', ', @accept);
        } else {
            return $self->unacceptable($env);
        }
    } else {
        if(exists $env->{'HTTP_ACCEPT'}) {
            my $accept = $env->{'HTTP_ACCEPT'};
            unless($self->acceptable($accept)) {
                return $self->unacceptable($env);
            }
        } else {
            $env->{'HTTP_ACCEPT'} = '*/*'
        }
    }
    return $self->app->($env);
}

1;

__END__

# ABSTRACT: Sets the Accept header based on the suffix or query params of a request

=head1 SYNOPSIS

  use Plack::Builder;

  my %map = (
    json => 'application/json',
    xml  => 'application/xml',
  );

  builder {
    enable 'SetAccept', from => 'suffix', mapping => \%map;
    $app;
  };

  # or

  builder {
    enable 'SetAccept', from => 'suffix', mapping => \&mapper;
  };

  # or

  builder {
    enable 'SetAccept', from => 'param', param => 'format', mapping => \%map;
  };

=head1 DESCRIPTION

=head1 FUNCTIONS

=head1 SEE ALSO

=cut
