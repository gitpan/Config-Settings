#!/usr/bin/env perl

use Test::More;
use Test::Exception;

use strict;
use warnings;

plan tests => 12;

use_ok 'Config::Settings';

my $parser = Config::Settings->new;

isa_ok $parser,'Config::Settings';

# XXX: to be replaced with an actual test when we start using options.
Config::Settings->new ({});

{
  my $settings = $parser->parse ("");

  ok ref $settings eq 'HASH',"empty configuration";
}

{
  my $settings = $parser->parse ("foo 42");

  is_deeply $settings,{ foo => 42 },"simple assignment";
}

{
  my $settings = $parser->parse ("foo { bar 42 }");

  is_deeply $settings,{ foo => { bar => 42 } },"scope";
}

{
  my $settings = $parser->parse ("foo bar 42");

  is_deeply $settings,{ foo => { bar => 42 } },"deep assignment";
}

{
  my $settings = $parser->parse ("foo { bar 42 }; foo baz 84");

  is_deeply $settings,{ foo => { bar => 42,baz => 84 } },"deep assignment merge";
}

{
  my $settings = $parser->parse ("foo 42; foo 84; foo 168");

  is_deeply $settings,{ foo => [ 42, 84, 168 ] },"list construction";
}

{
  my $settings = $parser->parse ("foo [ 42 84 168]");

  is_deeply $settings,{ foo => [ 42, 84, 168 ] },"list construction (experimental)";
}

throws_ok { $parser->_process_value ([ 'FOO' ]) } qr/Uh oh/;

dies_ok { $parser->parse_file ("some_file_that_doesnt_exist") };

{
  my $settings = $parser->parse_file ("t/test.settings");

  is_deeply $settings,{ foo => 42 },"parse_file";
}

