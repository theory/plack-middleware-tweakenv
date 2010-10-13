package Plack::Middleware::TweakEnv;

use strict;
use 5.8.1;
use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw(tweaks);
use Carp;

our $VERSION = '0.10';

sub wrap {
    my $self = shift;
    return $self->SUPER::wrap(@_) if ref $self;
    my $app = shift;

    my @tweaks;
    while (@_) {
        my $key = shift;
        my $val = shift;
        my $ref = ref $val;
        my $code;
        if ($ref eq 'ARRAY') {
            my $meth = shift @{ $val };
            $code = $self->can($meth) or croak "No such method: $meth";
        } elsif ($ref eq 'CODE') {
            $code = $self->can('execute');
            $val = [$val];
        } elsif ($ref eq '') {
            $code = $self->can($val) or croak "No such method: $val";
            $val = [];
        } else {
            require Carp;
            croak("$val is not a valid parameter to " . __PACKAGE__);
        }
        push @tweaks, [ $code, [ $key, @{ $val } ] ];
    }
    return $self->SUPER::wrap( $app, tweaks => \@tweaks );
}

sub call {
    my ($self, $env) = @_;
    for my $cb (@{ $self->tweaks }) {
        my $meth = $cb->[0];
        $self->$meth($env, @{ $cb->[1] });
    }
    $self->app->($env);
}

sub set_to {
    my ($self, $env, $key, $val) = @_;
    $env->{$key} = $val;
}

sub copy_from {
    my ($self, $env, $key, $from) = @_;
    $env->{$key} = $env->{$from};
}

sub delete {
    my ($self, $env, $key) = @_;
    delete $env->{$key};
}

sub default_to {
    my ($self, $env, $key, $val) = @_;
    $env->{$key} = $val unless defined $env->{$key};
}

sub alt_from {
    my ($self, $env, $key, $from) = @_;
    $env->{$key} = $env->{$from} unless defined $env->{$key};
}

sub execute {
    my ($self, $env, $key, $code) = @_;
    $env->{$key} = $code->($env, $key);
}

1;
__END__

=head1 Name

Plack::Middleware::TweakEnv - Tweak the Plack environment

=head1 Synopsis

  use Plack::Builder;
  builder {
      enable TweakEnv => (
          HTTP_USER_AGENT => [ set_to    => 'Mozilla/3.0 (MSIE 4.0)' ],
          SCRIPT_NAME     => [ copy_from => 'HTTP_X_FORWARDED_SCRIPT_NAME' ],
          HTTP_EVILDOER   => 'delete',
          REMOTE_ADDR     => sub {
              my ($env, $key) = @_;
              my $for = $env->{HTTP_X_FORWARDED_FOR} or return $env->{$key}
              my ($ip) = $for =~ /([^,\s]+)$/;
              return $ip;
          },
      );
      $app;
  };

=head1 Description

Sometimes you just need to mess with the Plack environment before your app
uses it. Maybe you have a reverse proxy server that adds headers you need the
back end to see. Or maybe you just want to set custom values. If so then this
module is for you.

To use it, simply pass an array reference of key/value pairs. The keys should
be the names of the Plack environment keys you want to tweak. The values may
be either array references describing the actions to be taken, or code
references that return a value to set.

For the array reference parameters, the first item in the array should be the
name of a method to execute. The supported methods are:

=over

=item C<set_to>

  HTTP_USER_AGENT => [ set_to => 'Mozilla/3.0 (MSIE 4.0)' ]

Set the value for a particular key. In this example, the C<HTTP_USER_AGENT>
key will be set to the value C<"Mozilla/3.0 (MSIE 4.0)">.

=item C<copy_from>

  SCRIPT_NAME => [ copy_from => 'HTTP_X_FORWARDED_SCRIPT_NAME' ]

Copy the value from another key in the environment. In this example, the value
stored for the key C<HTTP_X_FORWARDED_SCRIPT_NAME> will be copied to the
C<SCRIPT_NAME> slot.

=item C<delete>

  HTTP_EVILDOER => ['delete']

Delete the key from the environment.

=item C<default_to>

  HTTP_USER_AGENT => [ default_to => 'Mozilla/3.0 (MSIE 4.0)' ]

Like C<set_to>, C<default_to> Sets the value for the key, but only if that key
does not already exist in the environment with a defined value.

=item C<alt_from>

  SCRIPT_NAME => [ alt_from => 'HTTP_X_FORWARDED_SCRIPT_NAME' ]

Like C<copy_from>, C<alt_from> copies the value for another key in the
environment, but only if that key does not already exist in the environment
with a defined value.

=back

For code reference parameters, the code reference should expect two arguments:

=over

=item *

The Plack environment hash.

=item *

The name of the header to be modified.

=back

For example:

  REMOTE_ADDR => sub {
      my ($env, $key) = @_;
      my $for = $env->{HTTP_X_FORWARDED_FOR} or return $env->{$key}
      my ($ip) = $for =~ /([^,\s]+)$/;
      return $ip;
  }

=head2 Adding Methods

If you'd like to add other kinds of tweaks for general use, simply subclass
Plack::Middleware::TweakEnv and add the method you want. For example, say you
wanted to add a method to replace a substring in a particular environment
slot. It might look something like this:

  package Plack::Middleware::TweakEnv::Replace;
  use parent 'Plack::Middleware::TweakEnv';

  sub subst {
      my ($self, $env, $key, $rgex, $replace) = @_;
      $env->{$key} =~ s/$rgex/$replace/;
  }

Then to use it:

  builder {
      enable 'TweakEnv::Replace' => (
          HTTP_CONTENT_TYPE => [ subst, qr/text/, "TEXT" ]
      );
  };

=head2 Security

Please be very careful using C<copy_from> and C<alt_from>, as these options
create potential security vulnerabilities. Only set the value of one variable
from the value of another if you know for sure that the other is from a
trusted source. For example, you might set the C<X-Forwarded-Script-Name>
header in a reverse proxy configuration in front of your Plack app, and thus
will be safe replacing C<SCRIPT_NAME> with C<HTTP_X_FORWARDED_SCRIPT_NAME>. If
your proxy server does not set such a header, however, B<please> do not use
it, as anyone can submit a request that contains it.

In short, only pay attention to HTTP slots when you know exactly where the
values come from.

=begin private

Methods we implement but don't need to publicly document.

=over

=item C<wrap>

=item C<call>

=item C<execute>

=back

=end private

=head1 See Also

=over

=item *

L<Plack|http://plackperl.org> is the "superglue interface between perl web
application frameworks and web servers, just like Perl is the duct tape of the
internet." You'll need to be writing a Plack app to use
Plack::Middleware::TweakEnv.

=item *

L<Plack::Middleware::ReverseProxy> provides middleware for typical environment
munging for a Plack app running behind a reverse proxy server.
Plack::Middleware::TweakEnv actually works well to tweak additional
environment settings.

=back

=head1 Support

This module is stored in an open L<GitHub
repository|http://github.com/theory/test-xpath/tree/>. Feel free to fork and
contribute!

Please file bug reports via L<GitHub
Issues|http://github.com/theory/plack-middleware-tweakenv/issues/> or by sending mail to
L<bug-Plack-Middleware-TweakEnv@rt.cpan.org|mailto:bug-Plack-Middleware-TweakEnv@rt.cpan.org>.

=head1 Author

David E. Wheeler <david@kineticode.com>

=head1 Copyright and License

Copyright (c) 2010 David E. Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
