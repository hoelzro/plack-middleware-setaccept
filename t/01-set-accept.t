use strict;
use warnings;

use HTTP::Request::Common;
use Test::More tests => 26;
use Test::XML;
use Plack::Builder;
use Plack::Test;

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
    is $res->content, '*/*';

    $res = $cb->(GET '/foo?format=xml');
    is $res->code, 200;
    is $res->content, '*/*';

    $res = $cb->(GET 'http://localhost:5000/foo.yaml');
    is $res->code, 406;
    is_xml $res->content, '<ul><li><a href="http://localhost:5000/foo.json">application/json</a></li><li><a href="http://localhost:5000/foo.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:9000/bar.yaml');
    is $res->code, 406;
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
    is_xml $res->content, '<ul><li><a href="http://localhost:5000/foo.json">application/json</a></li><li><a href="http://localhost:5000/foo.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:9000/bar', Accept => 'application/x-yaml');
    is $res->code, 406;
    is_xml $res->content, '<ul><li><a href="http://localhost:9000/bar.json">application/json</a></li><li><a href="http://localhost:9000/bar.xml">application/xml</a></li></ul>';

    $res = $cb->(GET 'http://localhost:5000/foo.json', Accept => 'application/xml');
    is $res->code, 200;
    is $res->content, 'application/xml, application/json';
};

# try bad from
# try no param when from is param
# try both froms at once
# handle GET/POST
# See how all PSGI env vars are affected (eg. those regarding path, body)
# should we even do the 406 stuff?
