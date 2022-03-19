package Plack::Middleware::Text::Minify;

# ABSTRACT: remove HTML indentation on the fly

use v5.9.3;

use strict;
use warnings;

use parent qw/ Plack::Middleware /;

use Plack::Util;
use Plack::Util::Accessor qw/ path type /;
use Ref::Util qw/ is_arrayref is_coderef /;
use Text::Minify::XS v0.4.8 ();

# RECOMMEND PREREQ:  Ref::Util::XS

our $VERSION = 'v0.3.1';

sub call {
    my ($self, $env) = @_;

    my $res = $self->app->($env);

    return $res if $env->{'psgix.no-minify'};

    my $method = $env->{REQUEST_METHOD};
    unless ($method =~ /^(GET|POST)$/) {
        return $res;
    }

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

            return if @$res < 3;

            return if Plack::Util::status_with_no_entity_body( $res->[0] );

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
            if ( is_arrayref($body) ) {    # no reason to call a function for each line in the body
                $res->[2] = [ Text::Minify::XS::minify( join( "", @$body ) ) ];
            }
            else {
                my $text = "";
                Plack::Util::foreach( $body, sub { $text .= $_[0] } );
                $res->[2] = [ Text::Minify::XS::minify($text) ];
            }

            if (Plack::Util::header_exists( $res->[1], 'content-length' )) {
                Plack::Util::header_set( $res->[1], 'content-length', length( $res->[2][0] ) );
            }

            return;
        }
    );

}

=head1 SYNOPSIS

  use Plack::Builder;

  builder {

    enable "Text::Minify",
        path => qr{\.(html|css|js)},
        type => qr{^text/};

  ...

  };

=head1 DESCRIPTION

This middleware uses L<Text::Minify::XS> to remove indentation and
trailing whitespace from text content.

It will be disabled if the C<psgix.no-minify> environment key is set
to a true value. (Added in v0.2.0.)

=attr path

This is a regex or callback that matches against C<PATH_INFO>.  If it
does not match, then the response won't be minified.

The callback takes the C<PATH_INFO> and Plack environment as arguments.

By default, it will match against any path except for HTTP status
codes with no bodies, or request methods other than C<GET> or C<POST>.

=attr type

This is a regex or callback that matches against the content-type. If it
does not match, then the response won't be minified.

The callback takes the content-type header and the Plack reponse as
arguments.

By default, it will match against any "text/" MIME type.

=head1 KNOWN ISSUES

=head2 Support for older Perl versions

This module requires Perl v5.9.3 or newer, which is the minimum
version supported by L<Text::Minify::XS>.

=head2 Use with templating directive that collapse whitespace

If you are using a templating system with directives that collapse
whitespace in HTML documents, e.g. in L<Template-Toolkit|Template>

    [%- IF something -%]
      <div class="foo">
        ...
      </div>
    [%- END -%]

then you may find it worth removing these and letting the middleware
clean up extra whitespace.

=head2 Collapsed Newlines

The underlying minifier does not understand markup, so newlines will
still be collapsed in HTML elements where whitespace is meaningful,
e.g. C<pre> or C<textarea>.

=head1 SEE ALSO

L<Text::Minify::XS>

L<PSGI>

=cut

1;
