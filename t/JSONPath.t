use Test2::V1
  -pragmas,
  -target => { CLASS => 'Data::Path' },
  qw( is isa_ok lives ok plan subtest );

plan 2;

# JSONPath
# https://www.rfc-editor.org/rfc/rfc9535.txt
# Segments can use bracket notation, or the more compact dot notation.
# the "dot" is the "slash" in Data::Path

subtest 'Access root node' => sub {
  plan 3;

  my $data = { k => 'v' };
  isa_ok my $self = CLASS->new( $data ), CLASS;
  my $root_node;
  # Use the root-identifier (the empty string ''; JSONPath uses $) to access
  # the whole data structure
  ok lives { $root_node = $self->get( '' ) }, 'Can get root node';
  is $root_node, $data, 'Root node refers to whole data structure'
};

subtest 'Index based selection of array data structure' => sub {
  plan 3;

  my $data = [ qw( a b ) ];
  isa_ok my $self = CLASS->new( $data ), CLASS;
  my $value;

  $self->get( '[1]' );
  ok lives { $value = $self->get( '[1]' ) }, 'Can get 1st array element';
  is $value, 'b', 'Check value'
}
