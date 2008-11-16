package Config::Settings;

use Carp qw/croak/;
use Parse::RecDescent;

use strict;
use warnings;

our $VERSION = '0.00_01';

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

Config::Settings

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

I will extend the documentation for the next release, this is just to
get the module up on CPAN so people interested can start playing with
it.

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

