#!perl

use utf8;

use v5.14;
use warnings;

use Test2::V0;

use HTTP::Request::Common;
use Plack::Builder;
use Plack::MIME;
use Plack::Test;

my $handler = builder {

    enable "Text::Minify",
        type => sub {
            my ($type, $res) = @_;
            return $type =~ qr{html};
    };
    enable "ContentLength";


    sub {
        my $env    = shift;
        my $path   = $env->{PATH_INFO};
        my $type   = Plack::MIME->mime_type($path);

        my $body = <<EOB;
<html>
  <head>
    <title>Test</title>
  </head>
  <body>
    <h1>Test</h1>
    <p>Here is some text.</p>
</html>
EOB

        return [
            200,
            [ 'Content-Type' => $type || 'text/plain; charset=utf8' ],
            [ $body ]
        ];
    };

};

test_psgi
    app => $handler,
    client => sub {
        my ($cb) = @_;

        subtest 'simple' => sub {

            my $req = GET '/index.html';
            my $res = $cb->($req);

            unlike $res->content, qr/\n[ ]/, "no leading spaces";
        };

        subtest 'not text' => sub {

            my $req = GET '/index.txt';
            my $res = $cb->($req);

            like $res->content, qr/\n[ ]/, "leading spaces";
        };

};

done_testing;
