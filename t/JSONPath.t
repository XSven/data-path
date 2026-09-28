use Test2::V1
  -pragmas,
  -target => { CLASS => 'Data::Path' },
  qw( is isa_ok lives ok plan subtest );

plan 2;

# JSONPath
# https://www.rfc-editor.org/rfc/rfc9535.txt
# Segments can use bracket notation, or the more compact dot notation.
# the "dot" is the "slash" in Data::Path

subtest 'access root node' => sub {
  plan 3;

  my $data = { k => 'v' };
  isa_ok my $self = CLASS->new( $data ), CLASS;
  my $root_node;
  # use the root-identifier (the empty string ''; JSONPath uses $) to access
  # the whole Perl data structure
  ok lives { $root_node = $self->get( '' ) }, 'can get root node';
  is $root_node, $data, 'root node refers to whole Perl data structure';
};

subtest 'index based selection' => sub {
  plan 3;

  my $data = [ qw( a b ) ];
  isa_ok my $self = CLASS->new( $data ), CLASS;
  my $value;

  $self->get( '[1]' );
  ok lives { $value = $self->get( '[1]' ) }, 'can get 1st array element';
  is $value, 'b', 'check value';
};
