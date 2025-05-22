use strict;
use warnings;

use Test::More import => [ qw( BAIL_OUT is is_deeply new_ok plan subtest use_ok ) ], tests => 2;
use Test::Fatal      qw( exception lives_ok );
use Test::MockObject ();

my $class;

BEGIN {
  $class = 'Data::Path';
  use_ok $class or BAIL_OUT "Cannot load class '$class'!";
}

# JSONPath
# https://www.rfc-editor.org/rfc/rfc9535.txt
# Segments can use bracket notation, or the more compact dot notation.
# the "dot" is the "slash" in Data::Path

subtest 'access root node' => sub {
  plan tests => 3;

  my $data = { k => 'v' };
  my $self = new_ok( $class, [ $data ] );
  my $root_node;
  # use the root-identifier (the empty string ''; JSONPath uses $) to access
  # the whole Perl data structure
  lives_ok { $root_node = $self->get( '' ) } 'can get root node';
  is_deeply $root_node, $data, 'root node refers to whole Perl data structure';
};
