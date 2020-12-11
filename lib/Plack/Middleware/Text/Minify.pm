package Plack::Middleware::Text::Minify;

use v5.10;

use strict;
use warnings;

use parent qw/ Plack::Middleware /;

use Plack::Util;
use Ref::Util qw/ is_plain_arrayref /;
use Text::Minify::XS v0.3.1 ();

# RECOMMEND PREREQ:  Ref::Util::XS

sub call {
    my ($self, $env) = @_;

    my $res = $self->app->($env);

    return Plack::Util::response_cb(
        $res,
        sub {
            my ($res) = @_;

            return unless is_plain_arrayref($res);

            my $type = Plack::Util::header_get( $res->[1], 'content-type' );
            return unless $type =~ m{^text/};

            my $body = $res->[2];
            return unless is_plain_arrayref($body);

            $res->[2] = [ Text::Minify::XS::minify( join("", @$body ) ) ];

            return;
        }
    );

}

1;
