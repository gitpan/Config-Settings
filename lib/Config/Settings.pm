package Config::Settings;

use Carp qw/croak/;
use Parse::RecDescent;

use strict;
use warnings;

our $VERSION = '0.00_02';

my $parser = Parse::RecDescent->new (<<'EOF');
config:
  <skip: qr/\s* ([#] .*? \n \s*)*/x> scope

scope:
  assignment(s? /;+/) /;*/
  { $return = [ 'SCOPE',@{ $item[1] } ] }

assignment:
  deep_assignment | direct_assignment | <error>

deep_assignment:
  keyword keyword value
  { $return = [ $item[1] => $item[2] => $item[3] ]; 1 }

direct_assignment:
  keyword value
  { $return = [ $item[1] => $item[2] ]; 1 }

keyword:
  integer | string | bareword

value:
  integer | string | list | hash

bareword:
  /[\w:]+/

integer:
  /\d+/

string:
  <perl_quotelike>
  { $return = $item[1][2]; 1 }

list:
  "[" value(s?) "]"
  { $return = [ 'LIST',@{ $item[2] } ]; 1 }

hash:
  "{" scope "}"
  { $return = $item[2]; 1 }

EOF

sub new {
  my $class = shift;

  my $node = (ref $_[0] eq 'HASH' ? $_[0] : { @_ });

  return bless $node,$class;
}

sub parse_file {
  my ($self,$file) = @_;

  open (my $fh,$file) or croak $!;

  my $content = do { local $/; <$fh> };

  close $fh;

  return $self->parse ($content);
}

sub parse {
  my ($self,$content) = @_;

  return $self->_process_value ($parser->config ($content));
}

sub _process_scope {
  my ($self,$scope) = @_;

  my %result;

  foreach my $assignment (@$scope) {
    my ($key,$value) = @$assignment;

    if (@$assignment > 2) {
      $self->_deep_assignment (\%result,@$assignment);
    } else {
      $self->_simple_assignment (\%result,@$assignment);
    }
  }

  return \%result;
}

sub _simple_assignment {
  my ($self,$hashref,$key,$value) = @_;

  $value = $self->_process_value ($value);

  if (exists $hashref->{$key}) {
    if (ref $hashref->{$key} eq 'ARRAY') {
      push @{ $hashref->{$key} },$value;
    } else {
      $hashref->{$key} = [ $hashref->{$key},$value ];
    }
  } else {
    $hashref->{$key} = $value;
  }

  return;
}

sub _deep_assignment {
  my ($self,$hashref,$key1,$key2,$value) = @_;

  $value = $self->_process_value ($value);

  $key2 = $self->_process_value ($key2);

  if (ref $hashref->{$key1} eq 'HASH') {
    $hashref->{$key1}->{$key2} = $value;
  } else {
    $hashref->{$key1} = { $key2 => $value };
  }

  return;
}

sub _process_value {
  my ($self,$value) = @_;

  if (ref $value) {
    my $value_type = shift @$value;

    if ($value_type eq 'SCOPE') {
      return $self->_process_scope ($value);
    } elsif ($value_type eq 'LIST') {
      return [ map { $self->_process_value ($_) } @$value ];
    } else {
      die "Uh oh, this should never happen";
    }
  }

  return $value;
}

1;

__END__

=pod

=head1 NAME

Config::Settings - Parsing pleasant configuration files

=head1 SYNOPSIS

  # myapp.settings

  hello {
    world 1;
  };

  # myapp.pl

  use Config::Settings;

  my $settings = Config::Settings->new->parse_file ("myapp.settings");

  print "Hello world!\n" if $settings->{hello}->{world};

=head1 DESCRIPTION

Better description to come.

=head1 RATIONALE

The first thing that probably comes to most people's mind when they
see this module is "Why another Config:: module?". So I feel I should
probably first explain what motivated me to write this module in the
first place before I go into more details of how it works.

There are already numerous modules for doing configuration files
available on CPAN. L<YAML> appears to be a prefered module, as do
L<Config::General>. There are of course also modules like
L<Config::Any> which lets be open to many formats instead of being
bound to any particular one, but this modules only supports what is
already implemented in another module so if one feels one is not
entirely happy with any format with an implementation on CPAN, it
doesn't really doesn't solve the fundamental issue that was my
incentive to implement a new format.

=head2 YAML

So let us have a look at the other formats. As previously mentioned,
one of the more popular formats today appears to be YAML. YAML isn't
really a configuration file format as such, it's a serialization
format. It's just better than the more riddiculous alternatives like
say XML. It's well documented which is an important feature and
reading it, unlike XML, doesn't require a whole lot of brain power
for either a human or a machine. A problem with YAML is the
whitespace and tab sensitivity. Some will of course not call this a
problem. After all, python is constructed on the very same principle,
but this isn't python. This is perl. Chances are that if a python-ish
structure had been more appropriate for your brain, you would already
be using python and not reading the documentation for this module.

But more importantly, this sensitivity is also a problem for people
who are not familiar with the format. When I work on a Catalyst
project, I seldom work alone. I work with graphic designers, I work
with administrators, I work with a lot of people who is not likely to
ever have encountered YAML before. Now, YAML *is* easy to read, but
unfortunately it's not always easy to write. And sometimes, these
people who I am working with needs to make a change to the settings
for an application. They make the change, hit tab a few times to
make the element position correctly, save the file, and voila it
explodes without it really being obvious why.

=head2 Config::General

A different format that has recently become more popular is the
L<Config::General> module. This module has adopted the format used
by Apache. It's a mixture of markup language and simple key/value
pairs. And in light of what I talked about with regards to YAML, this
certainly is a better alternative. More people has configured
Apache, and even if they haven't it's still more obvious how to
modify the configuration file. The syntax of the format is to a much
larger extent self-documenting and this is an important feature for a
configuration file format. So what is the problem with this module?

For starters, it occationally becomes *too* simple. There is for
instance no way of constructing a single element array in it, or
really, a good way of specifying an array at all. An array in the
Config::General sense is more about a directive being specified
multiple times, not constructing arrays. However, I can see why the
decision to keep this out of the configuration format was made.
Staying true to the Apache format and allowing real arrays really
cannot be done. Another thing that bothers me about this format is
the weird way it uses something that looks like a markup language
to declare sections. I don't like this, I always tend to forget
closing tags for more complicated data structures. Such structures
rarely exists in a real Apache configuration file, but are very
common in a configuration file for a perl program. And the closing
tags are also uneccesarily long. Their long name does nothing to
help me remember which closing tag belongs to which starting tag,
it's really just noise in a configuration file.

=head1 METHODS

=head2 new

  my $parser = Config::Settings->new;

=head2 parse

  my $settings = $parser->parse ($string);

=head2 parse_file

  my $settings = $parser->parse_file ($filename);

=head1 EXAMPLES

=head2 A Catalyst application

  name "MyApp";

  Model::MyApp {
    schema_class "MyApp::Schema";

    connect_info {
      dsn        "dbi:SQLite:dbname=__HOME__/db/myapp.db";
      AutoCommit 1;
    };
  };

  View::TT {
    ENCODING           "UTF-8";
    TEMPLATE_EXTENSION ".html";
    INCLUDE_PATH       "__HOME__/templates";
  };

  Plugin::Authentication {
    default_realm "members";

    realms {
      members {
        credential {
          class              "Password";
          password_field     "password";
          password_type      "hashed";
          password_hash_type "SHA-256";
        };
 
        store {
          class      "DBIx::Class";
          user_model "MyApp::User";
        };
      };
    };
  };

=head1 SEE ALSO

=over 4

=item L<Config::General>

=back

=head1 BUGS

Most software has bugs. This module probably isn't an exception. 
If you find a bug please either email me, or add the bug to cpan-RT.

=head1 AUTHOR

Anders Nor Berle E<lt>berle@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Anders Nor Berle.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

