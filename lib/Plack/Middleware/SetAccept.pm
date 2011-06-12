## no critic (RequireUseStrict)
package Plack::Middleware::SetAccept;

## use critic (RequireUseStrict)
use strict;
use warnings;
use parent 'Plack::Middleware';

use Carp;
use URI;
use URI::QueryParam;

sub prepare_app {
    my ( $self ) = @_;

    my ( $from, $mapping, $param ) = @{$self}{qw/from mapping param/};

    unless($from) {
        croak "'from' parameter is required";
    }
    unless($mapping) {
        croak "'mapping' parameter is required";
    }
    $from = [ $from ] unless ref($from);
    unless(@$from) {
        croak "'from' parameter cannot be an empty array reference";
    }
    if(my ( $bad ) = grep { $_ ne 'suffix' && $_ ne 'param' } @$from) {
        croak "'$bad' is not a valid value for the 'from' parameter";
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

sub get_uri {
    my ( $self, $env ) = @_;

    my $host;
    unless($host = $env->{'HTTP_HOST'}) {
        $host = $env->{'SERVER_NAME'};
        unless($env->{'SERVER_PORT'} == 80) {
            $host .= ':' . $env->{'SERVER_PORT'};
        }
    }

    return URI->new(
        $env->{'psgi.url_scheme'} . '://' .
        $host .
        $env->{'REQUEST_URI'}
    );
}

sub extract_format {
    my ( $self, $env ) = @_;

    my @format;
    my $from = $self->{'from'};

    $from = [ $from ] unless ref $from;

    my @reasons;

    my $uri = $self->get_uri($env);
    foreach (@$from) {
        if($_ eq 'suffix') {
            my $path = $uri->path;

            if($path =~ /\.([^.]+)$/) {
                push @format, $1;
                $path = $`;
                $uri->path($path);
                push @reasons, 'suffix';
            }
        } elsif($_ eq 'param') {
            my @values = $uri->query_param_delete($self->{'param'});
            if(@values) {
                push @format, @values;
                push @reasons, 'param';
            }
        }
    }
    if(@reasons) { # if there has been any modification
        $env->{'PATH_INFO'}    = $uri->path;
        $env->{'REQUEST_URI'}  = $uri->path_query;
        $env->{'QUERY_STRING'} = $uri->query;
    }
    return ( \@format, \@reasons );
}

sub acceptable {
    my ( $self, $accept ) = @_;
    ## simple, stupid implementation
    return grep { $_ eq $accept } values %{ $self->{'mapping'} };
}

sub unacceptable {
    my ( $self, $env, $reasons ) = @_;

    my $host;
    unless($host = $env->{'HTTP_HOST'}) {
        $host = $env->{'SERVER_NAME'};
        unless($env->{'SERVER_PORT'} == 80) {
            $host .= ':' . $env->{'SERVER_PORT'};
        }
    }
    my $path = $env->{'PATH_INFO'};

    my $links = '<ul>';

    my $from;

    if(@$reasons) {
        $from = $reasons->[0];
    } else {
        $from = $self->{'from'};
        $from = $from->[0] if ref $from;
    }

    if($from eq 'suffix') {
        foreach my $format (sort keys %{$self->{'mapping'}}) {
            my $type = $self->{'mapping'}{$format};
            $links .= "<li><a href='http://$host$path.$format'>$type</a></li>";
        }
    } elsif($from eq 'param') {
        my $param = $self->{'param'};

        foreach my $format (sort keys %{$self->{'mapping'}}) {
            my $type = $self->{'mapping'}{$format};
            $links .= "<li><a href='http://$host$path?$param=$format'>$type</a></li>";
        }
    }
    $links .= '</ul>';
    return [
        406,
        ['Content-Type' => 'application/xhtml+xml'],
        [$links],
    ];
}

sub call {
    my ( $self, $env ) = @_;

    if($env->{'REQUEST_METHOD'} eq 'GET') {
        my ( $format, $reasons ) = $self->extract_format($env);

        if(@$format) {
            foreach my $f (@$format) {
                unless(exists $self->{'mapping'}{$f}) {
                    return $self->unacceptable($env, $reasons);
                }
            }
            my @accept = split /\s*,\s*/, $env->{'HTTP_ACCEPT'} || '';
            foreach my $f (@$format) {
                my $mapping = $self->{'mapping'}{$f};
                my ( $mapping_type ) = split /\//, $mapping;
                foreach my $accept (@accept) {
                    if($accept eq $mapping) {
                        undef $mapping;
                        last;
                    }
                    next unless defined($accept) && $accept =~ /\*/;
                    my ( $type ) = split /\//, $accept;

                    if($type eq '*' || $type eq $mapping_type) {
                        undef $accept;
                    }
                }
                push @accept, $mapping if defined $mapping;
            }
            $env->{'HTTP_ACCEPT'} = join(', ', grep { defined } @accept);
        } else {
            if(exists $env->{'HTTP_ACCEPT'}) {
                my $accept = $env->{'HTTP_ACCEPT'};
                unless($self->acceptable($accept)) {
                    return $self->unacceptable($env, $reasons);
                }
            } else {
                $env->{'HTTP_ACCEPT'} = '*/*'
            }
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
