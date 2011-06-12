use strict;
use warnings;

use Data::Dumper;
use HTTP::Request::Common;
use Test::Exception;
use Test::More tests => 146;
use Test::XML;
use Plack::Builder;
use Plack::Test;

$Data::Dumper::Purity = 1;
$Data::Dumper::Terse  = 1;

my $inner_app = sub {
    my ( $env ) = @_;

    return [
        200,
        ['Content-Type' => 'text/plain'],
        [$env->{'HTTP_ACCEPT'} || 'undef'],
    ]
};

my %map = (
    json => 'application/json',
    xml  => 'application/xml',
);

my $app = builder {
    enable 'SetAccept', from => 'suffix', mapping => \%map;
    $inner_app;
};

my $res;

test_psgi $app, sub {
    my ( $cb ) = @_;

    $res = $cb->(GET '/foo');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET '/foo.json');
    is $res->code, 200;
    is $res->content, 'application/json';

    $res = $cb->(GET '/foo.xml');
    is $res->code, 200;
    is $res->content, 'application/xml';

    $res = $cb->(GET '/foo?format=json');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET '/foo?format=xml');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET 'http://localhost:5000/foo.yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:5000/foo.json">application/json</a></li><li><a href="http://localhost:5000/foo.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:9000/bar.yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:9000/bar.json">application/json</a></li><li><a href="http://localhost:9000/bar.xml">application/xml</a></li></ul>';

    $res = $cb->(GET '/foo?format=yaml');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET '/foo', Accept => 'application/json');
    is $res->code, 200;
    is $res->content, 'application/json';

    $res = $cb->(GET '/foo', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml';

    $res = $cb->(GET 'http://localhost:5000/foo', Accept => 'application/x-yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:5000/foo.json">application/json</a></li><li><a href="http://localhost:5000/foo.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:9000/bar', Accept => 'application/x-yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:9000/bar.json">application/json</a></li><li><a href="http://localhost:9000/bar.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:5000/foo.json', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml, application/json';
};

$app = builder {
    enable 'SetAccept', from => 'param', param => 'format', mapping => \%map;
    $inner_app;
};

test_psgi $app, sub {
    my ( $cb ) = @_;

    my $res;

    $res = $cb->(GET '/foo');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET '/foo.json');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET '/foo.xml');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET '/foo?format=json');
    is $res->code, 200;
    is $res->content, 'application/json';

    $res = $cb->(GET '/foo?format=xml');
    is $res->code, 200;
    is $res->content, 'application/xml';

    $res = $cb->(GET '/foo.yaml');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET 'http://localhost:5000/foo?format=yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:5000/foo?format=json">application/json</a></li><li><a href="http://localhost:5000/foo?format=xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:9000/bar?format=yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:9000/bar?format=json">application/json</a></li><li><a href="http://localhost:9000/bar?format=xml">application/xml</a></li></ul>';

    $res = $cb->(GET '/foo', Accept => 'application/json');
    is $res->code, 200;
    is $res->content, 'application/json';

    $res = $cb->(GET '/foo', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml';

    $res = $cb->(GET 'http://localhost:5000/foo', Accept => 'application/x-yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:5000/foo?format=json">application/json</a></li><li><a href="http://localhost:5000/foo?format=xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:9000/bar', Accept => 'application/x-yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:9000/bar?format=json">application/json</a></li><li><a href="http://localhost:9000/bar?format=xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:5000/foo?format=json', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml, application/json';
};

throws_ok {
    builder {
        enable 'SetAccept';
    };
} qr/'from' parameter is required/;

throws_ok {
    builder {
        enable 'SetAccept', from => 'suffix';
    };
} qr/'mapping' parameter is required/;

throws_ok {
    builder {
        enable 'SetAccept', from => 'frob', mapping => {};
    };
} qr/'frob' is not a valid value for the 'from' parameter/;

throws_ok {
    builder {
        enable 'SetAccept', from => 'suffix', mapping => [];
    };
} qr/'mapping' parameter must be a hash reference/;

throws_ok {
    builder {
        enable 'SetAccept', from => 'suffix', mapping => sub {};
    };
} qr/'mapping' parameter must be a hash reference/;

lives_ok {
    builder {
        enable 'SetAccept', from => ['suffix', 'param'], param => 'format', mapping => {};
    };
};

throws_ok {
    builder {
        enable 'SetAccept', from => 'param', mapping => {};
    };
} qr/'param' parameter is required when using 'param' for from/;

throws_ok {
    builder {
        enable 'SetAccept', from => ['suffix', 'param'], mapping => {};
    };
} qr/'param' parameter is required when using 'param' for from/;

$app = builder {
    enable 'SetAccept', from => ['suffix', 'param'], param => 'format', mapping => \%map;
    $inner_app;
};

test_psgi $app, sub {
    my ( $cb ) = @_;

    my $res;

    $res = $cb->(GET '/foo');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET '/foo.json');
    is $res->code, 200;
    is $res->content, 'application/json';

    $res = $cb->(GET '/foo.xml');
    is $res->code, 200;
    is $res->content, 'application/xml';

    $res = $cb->(GET '/foo?format=json');
    is $res->code, 200;
    is $res->content, 'application/json';

    $res = $cb->(GET '/foo?format=xml');
    is $res->code, 200;
    is $res->content, 'application/xml';

    $res = $cb->(GET 'http://localhost:5000/foo.yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:5000/foo.json">application/json</a></li><li><a href="http://localhost:5000/foo.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:5000/foo?format=yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:5000/foo?format=json">application/json</a></li><li><a href="http://localhost:5000/foo?format=xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:9000/bar.yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:9000/bar.json">application/json</a></li><li><a href="http://localhost:9000/bar.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:9000/bar?format=yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:9000/bar?format=json">application/json</a></li><li><a href="http://localhost:9000/bar?format=xml">application/xml</a></li></ul>';

    $res = $cb->(GET '/foo', Accept => 'application/json');
    is $res->code, 200;
    is $res->content, 'application/json';

    $res = $cb->(GET '/foo', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml';

    $res = $cb->(GET 'http://localhost:5000/foo', Accept => 'application/x-yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:5000/foo.json">application/json</a></li><li><a href="http://localhost:5000/foo.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:9000/bar', Accept => 'application/x-yaml');
    is $res->code, 406;
    is $res->content_type, 'application/xhtml+xml';
    is_xml $res->content, '<ul><li><a href="http://localhost:9000/bar.json">application/json</a></li><li><a href="http://localhost:9000/bar.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:5000/foo?format=json', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml, application/json';

    $res = $cb->(GET 'http://localhost:5000/foo.json', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml, application/json';

    $res = $cb->(GET 'http://localhost:5000/foo.json?format=json', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml, application/json';
};

test_psgi $app, sub {
    my ( $cb ) = @_;

    $res = $cb->(POST '/foo.json');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(POST '/foo.json', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml';
};

test_psgi $app, sub {
    my ( $cb ) = @_;

    $res = $cb->(GET '/foo.json', Accept => '*/*');
    is $res->code, 200;
    is $res->content, 'application/json';

    $res = $cb->(GET '/foo.json', Accept => 'application/*');
    is $res->code, 200;
    is $res->content, 'application/json';

    $res = $cb->(GET '/foo.json', Accept => 'text/*');
    is $res->code, 200;
    is $res->content, 'text/*, application/json';
};

$app = builder {
    enable 'SetAccept', from => ['suffix', 'param'], param => 'format', mapping => \%map;
    sub {
        my ( $env ) = @_;

        return [
            200,
            ['Content-Type' => 'text/plain'],
            [Dumper([
                @{$env}{qw/SCRIPT_NAME PATH_INFO REQUEST_URI QUERY_STRING HTTP_ACCEPT/}
            ])],
        ];
    };
};

test_psgi $app, sub {
    my ( $cb ) = @_;

    my ( $script_name, $path_info, $request_uri, $query_string, $accept );

    $res = $cb->(GET '/');
    ( $script_name, $path_info, $request_uri, $query_string ) =
        @{ eval $res->content };

    is $script_name, '';
    is $path_info, '/';
    is $request_uri, '/';
    is $query_string, '';

    $res = $cb->(GET '/foo.json?foo=bar');
    ( $script_name, $path_info, $request_uri, $query_string ) =
        @{ eval $res->content };

    is $script_name, '/foo';
    is $path_info, '/foo';
    is $request_uri, '/foo?foo=bar';
    is $query_string, 'foo=bar';

    $res = $cb->(GET '/foo?foo=bar&format=json');
    ( $script_name, $path_info, $request_uri, $query_string ) =
        @{ eval $res->content };

    is $path_info, '/foo';
    is $request_uri, '/foo?foo=bar';
    is $query_string, 'foo=bar';

    $res = $cb->(GET '/foo?foo=bar&format=json');
    ( $script_name, $path_info, $request_uri, $query_string ) =
        @{ eval $res->content };

    is $script_name, '/foo';
    is $path_info, '/foo';
    is $request_uri, '/foo?foo=bar';
    is $query_string, 'foo=bar';

    $res = $cb->(GET '/foo.xml?foo=bar&format=json');
    ( $script_name, $path_info, $request_uri, $query_string ) =
        @{ eval $res->content };

    is $script_name, '/foo';
    is $path_info, '/foo';
    is $request_uri, '/foo?foo=bar';
    is $query_string, 'foo=bar';

    $res = $cb->(GET '/foo.bar.json');
    ( $script_name, $path_info, $request_uri, $query_string, $accept ) =
        @{ eval $res->content };

    is $script_name, '/foo.bar';
    is $path_info, '/foo.bar';
    is $request_uri, '/foo.bar';
    is $query_string, 'foo=bar';
    is $accept, 'application/json';

    $res = $cb->(GET '/foo?format=json&foo=bar&format=xml');
    ( $script_name, $path_info, $request_uri, $query_string, $accept ) =
        @{ eval $res->content };

    is $script_name, '/foo';
    is $path_info, '/foo';
    is $request_uri, '/foo?foo=bar';
    is $query_string, 'foo=bar';
    is $accept, 'application/json, application/xml';
};
