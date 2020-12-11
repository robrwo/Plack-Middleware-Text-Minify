package Plack::Middleware::Text::Minify;

use v5.10;

use strict;
use warnings;

use parent qw/ Plack::Middleware /;

use Plack::Util;
use Plack::Util::Accessor qw/ path type /;
use Ref::Util qw/ is_arrayref is_coderef /;
use Text::Minify::XS v0.3.1 ();

# RECOMMEND PREREQ:  Ref::Util::XS

sub call {
    my ($self, $env) = @_;

    my $res = $self->app->($env);

    if (my $match = $self->path) {

        my $path = $env->{PATH_INFO};

        unless ( ( is_coderef($match) && $match->( $path, $env ) )
            || ( $path =~ $match ) )
        {
            return $res;
        }
    }

    return Plack::Util::response_cb(
        $res,
        sub {
            my ($res) = @_;

            return unless is_arrayref($res);

            my $type = Plack::Util::header_get( $res->[1], 'content-type' );
            if ( my $match = $self->type ) {
                return
                  unless ( ( is_coderef($match) && $match->( $type, $res ) )
                    || ( $type =~ $match ) );
            }
            else {
                return unless $type =~ m{^text/};
            }

            my $body = $res->[2];
            return unless is_arrayref($body);

            $res->[2] = [ Text::Minify::XS::minify( join("", @$body ) ) ];

            return;
        }
    );

}

1;
