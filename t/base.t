#!/usr/bin/env perl

use strict;
#use Test::More tests => 21;
use Test::More 'no_plan';
use Plack::Test;

BEGIN { use_ok 'Plack::Middleware::TweakEnv' or die; }

my @keys;

my $base_app = sub {
    my $env = shift;
    my $output = join ', ', map { defined $_ ? $_ : '' } @{$env}{@keys};
    return [200, ['Content-Type' => 'text/plain'], [ $output ] ];
};
ok my $app = Plack::Middleware::TweakEnv->wrap($base_app),
    'Create TweakEnv app with no args';

test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/'));
    is $res->content, '', 'No args should do nothing';
};

# Try set_to.
ok $app = Plack::Middleware::TweakEnv->wrap(
    $base_app,
    FOO => [ set_to => 'hello' ],
), 'Create app using set_to';

@keys = qw(FOO);
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/'));
    is $res->content, 'hello', 'Env should have been set'
};

# Try copy_from.
ok $app = Plack::Middleware::TweakEnv->wrap(
    $base_app,
    FOO => [ copy_from => 'REQUEST_METHOD' ],
), 'Create app using copy_from';

test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/'));
    is $res->content, 'GET', 'Env should have been copied'
};

# Try delete.
ok $app = Plack::Middleware::TweakEnv->wrap(
    $base_app,
    REQUEST_METHOD => [ 'delete' ],
), 'Create app using delete';

@keys = qw(REQUEST_METHOD);
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/'));
    is $res->content, '', 'Env should have been deleted'
};

# Try delete as scalar.
ok $app = Plack::Middleware::TweakEnv->wrap(
    $base_app,
    REQUEST_METHOD => 'delete',
), 'Create app using delete as scalar';

@keys = qw(REQUEST_METHOD);
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/'));
    is $res->content, '', 'Env should have been deleted'
};

# Test default_to.
ok $app = Plack::Middleware::TweakEnv->wrap(
    $base_app,
    HTTP_FOO => [ default_to => 'hello' ],
), 'Create app using default_to';

@keys = qw(HTTP_FOO);
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/'));
    is $res->content, 'hello', 'Env should have been set'
};

# Make sure it isn't set if it's already set.
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/', ['Foo' => 'bar']));
    is $res->content, 'bar', 'Env should not have been overridden'
};

# Make sure it isn't set if it's defined.
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/', ['Foo' => 0]));
    is $res->content, '0', 'Defined Env should not have been overridden'
};

# Test alt_from.
ok $app = Plack::Middleware::TweakEnv->wrap(
    $base_app,
    HTTP_FOO => [ alt_from => 'REQUEST_METHOD' ],
), 'Create app using alt_from';

@keys = qw(HTTP_FOO);
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/'));
    is $res->content, 'GET', 'Env should have been set'
};

# Make sure it isn't set if it's already set.
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/', ['Foo' => 'bar']));
    is $res->content, 'bar', 'Env should not have been overridden'
};

# Make sure it isn't set if it's defined.
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/', ['Foo' => 0]));
    is $res->content, '0', 'Defined Env should not have been overridden'
};

# Try a code reference.
ok $app = Plack::Middleware::TweakEnv->wrap(
    $base_app,
    HTTP_FOO => sub { 'hi there' },
), 'Create app using a code reference';

test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/'));
    is $res->content, 'hi there',
        'Env should have been set with value returned by the code reference'
};

# Test order.
ok $app = Plack::Middleware::TweakEnv->wrap(
    $base_app,
    REQUEST_METHOD => 'delete',
    FOO => [ copy_from => 'REQUEST_METHOD' ],
), 'Create app using delete + copy_from';

@keys = qw(FOO);
test_psgi $app, sub {
    my $res = shift->(HTTP::Request->new(GET => '/'));
    is $res->content, '', 'Rules should execute in order';
};
