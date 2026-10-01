use Test2::V1
  -pragmas,
  -target => { CLASS => 'Data::Path' },
  qw( dies is isa_ok isnt like ok plan subtest );

plan 21;

subtest 'Cannot identify selector' => sub {
  plan 3;

  isnt dies { CLASS->new( { foo => [ 1, 2 ] } )->get( 'foo' ) },        undef, 'Missing "/" before "foo"';
  isnt dies { CLASS->new( { foo => [ 1, 2 ] } )->get( '/foo[0]bar' ) }, undef, 'Missing "/" before "bar"';
  isnt dies { CLASS->new( { foo => [ 1, 2 ] } )->get( '/foo[-1]' ) },   undef, 'Negative index not supported yet'
};

my $data = {
  scalar => 'scalar_value',
  array  => [ qw( array_value0 array_value1 array_value2 array_value3) ],
  hash   => {
    hash1 => 'hash1_value',
    hash2 => 'hash2_value'
  },
  complex => { level2 => [ { level3_0 => [ 'level4_0', { level4_1 => { level5 => 'huhu' } }, 'level4_2' ] } ] },
  method  => sub { return 'sub val'; }

};

isa_ok my $self = CLASS->new( $data ), CLASS;

is $self->get( '/scalar' ), 'scalar_value', 'Key selector; scalar value';

is $self->get( '/array' ), [ qw( array_value0 array_value1 array_value2 array_value3 ) ], 'Key selector; array value';

is $self->get( '/array[0]' ), 'array_value0', 'Key selector and then index selector; scalar value';

is $self->get( '/hash/hash1' ), 'hash1_value', 'hash key, hash key, scalar value';

is $self->get( '/complex/level2[0]/level3_0[0]' ), 'level4_0',
  'hash key, hash key, array index, hash key, array index, scalar value';

is $self->get( '/complex/level2[0]/level3_0[2]' ), 'level4_2',
  'hash key, hash key, array index, hash key, array index, scalar value';

is $self->get( '/complex/level2[0]/level3_0[1]/level4_1/level5' ), 'huhu',
  'hash key, hash key, array index, hash key, array index, hash key, hash key, scalar value';

#local $Data::Path::Debug =1;
like dies { $self->get( '/complex/level2[99]/level3_0[1]/level4_1/level5' ) },
  qr/\AArray index 99 does not exist/, '"index_does_not_exist" callback fires';

like dies { $self->get( '/complex/level2[0]/level3_1[1]/level4_1/level5' ) }, qr/\AHash key 'level3_1' does not exist/,
  '"key_does_not_exist" callback fires';

is $self->get( '/complex/level2[0]/level3_0[1]/level4_1/level5_not_exists' ), undef, 'trailing hash key does not exist';

is $self->get( '/complex/level2[0]/level3_0[99]' ), undef, 'trailing array index does not exist';

isa_ok $self = CLASS->new(
  $data,
  {
    'key_does_not_exist'   => sub { die 'callback_error_key' }, ## no critic ( RequireCarping )
    'index_does_not_exist' => sub { die 'callback_error_index' } ## no critic ( RequireCarping )
  }
  ),
  CLASS;

like dies { $self->get( '/complex/home/' ) }, qr/callback_error_key/, 'use key does not exist callback';

like dies { $self->get( '/complex/level2[99]/level3_0' ) }, qr/callback_error_index/,
  'use index does not exist callback';

$data = [ [ qw( a0 a1 ) ], { foo => 7 } ];

isa_ok $self = CLASS->new( $data ), CLASS;

is $self->get( '[0][1]' ), 'a1', 'Select index and select index';

is $self->get( '[1]/foo' ), '7', 'Select index and select key';

like dies { $self->get( '[1][5]' ) }, qr/\ATry to retrieve an array index 5 from a HASH reference/,
  '"retrieve_index_from_non_array" callback fires';

like dies { $self->get( '[0]/foo' ) }, qr/\ATry to retrieve a hash key 'foo' from a ARRAY reference/,
  '"retrieve_key_from_non_hash" callback fires'
__END__
use Test::MockObject ();
is $self->get( '/method()' ), $data->{ method }->(), 'subroutine returned';

my $obj = Test::MockObject->new( {} );
$obj->mock( 'method2' => sub { 'method2 val' } );
isa_ok $self = CLASS->new( $obj ), CLASS;
is $self->get( '/method2()', $obj ), $obj->method2(), 'method returned';

my $deep_method = { foo => $obj };
isa_ok $self = CLASS->new( $deep_method ), CLASS;
is $self->get( '/foo/method2()' ), $obj->method2(), 'deep method returned';

