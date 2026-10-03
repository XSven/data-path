use Test2::V1
  -pragmas,
  -target => { CLASS => 'Data::Path' },
  qw( dies is isa_ok isnt like ok plan subtest );

plan 7;

subtest 'Selectors' => sub {
  plan 15;

  ok my $sub = CLASS->can( '_next_selector' ), 'Locate private subroutine';

  my $path = '';
  is [ $sub->( \$path ) ], [ ( undef ) x 3 ], 'Empty path selector';
  is $path,                '',                'Path is empty';

  $path = 'foo';
  like dies { $sub->( \$path ) }, qr/\ACannot extract next selector from path 'foo'/, 'Missing "/" before "foo"';
  is $path, 'foo', 'Path has not changed';

  for ( -15, -1, 0, 7, 15 ) {
    $path = "[$_]";
    is [ $sub->( \$path ) ], [ undef, undef, $_ ], "Select index $_";
    is $path,                '',                   'Path is empty'
  }
};

subtest 'Data structure is hash reference' => sub {
  plan 19;

  my $data = {
    sv   => 'string',
    aref => [ qw( item0 item1 item2 item3 ) ],
    href => {
      key1 => 'value1',
      key2 => 'value2'
    },
    complex => {
      level2 => [
        {
          level3_0 => [
            'level4_0',
            {
              level4_1 => {
                level5 => 'huhu'
              }
            },
            'level4_2'
          ]
        }
      ]
    }
  };

  isa_ok my $self = CLASS->new( $data ), CLASS;

  is $self->get( '/sv' ), $data->{ sv }, 'Key selector returns scalar value';

  is $self->get( '/aref' ), $data->{ aref }, 'Key selector returns array reference';

  is $self->get( '/aref[0]' ), $data->{ aref }->[ 0 ], 'Key selector and index selector returns scalar value';

  like dies { $self->get( '/aref/key' ) }, qr/\ATry to retrieve a hash key 'key' from a ARRAY reference/,
    '"retrieve_key_from_non_hash" callback fires';

  is $self->get( '/href' ), $data->{ href }, 'Key selector returns hash reference';

  is $self->get( '/href/key2' ), $data->{ href }->{ key2 }, 'Key selector and key selector returns scalar value';

  like dies { $self->get( '/href[5]' ) }, qr/\ATry to retrieve an array index 5 from a HASH reference/,
    '"retrieve_index_from_non_array" callback fires';

  is $self->get( '/complex/level2[0]/level3_0[0]' ), 'level4_0',
    'Key selector and key selector and index selector and key selector and index selector returns scalar value';

  is $self->get( '/complex/level2[0]/level3_0[2]' ), 'level4_2',
    'Key selector and key selector and index selector and key selector and index selector returns scalar value';

  is $self->get( '/complex/level2[0]/level3_0[-1]' ), 'level4_2',
    'Key selector and key selector and index selector and key selector and negative index selector returns scalar value';

  is $self->get( '/complex/level2[0]/level3_0[1]/level4_1/level5' ), 'huhu',
    'hash key, hash key, array index, hash key, array index, hash key, hash key, scalar value';

  like dies { $self->get( '/complex/level2[99]/level3_0[1]/level4_1/level5' ) },
    qr/\AValue for array index 99 is undefined/, '"array_value_is_undefined" callback fires';

  like dies { $self->get( '/complex/level2[0]/level3_1[1]/level4_1/level5' ) },
    qr/\AValue for hash key 'level3_1' is undefined/,
    '"hash_value_is_undefined" callback fires';

  is $self->get( '/complex/level2[0]/level3_0[1]/level4_1/level5_not_exists' ), undef, 'trailing hash key does not exist';

  is $self->get( '/complex/level2[0]/level3_0[99]' ), undef, 'trailing array index does not exist';

  isa_ok $self = CLASS->new(
    $data,
    {
      'hash_value_is_undefined'  => sub { die 'callback_error_key' }, ## no critic ( RequireCarping )
      'array_value_is_undefined' => sub { die 'callback_error_index' } ## no critic ( RequireCarping )
    }
    ),
    CLASS;

  like dies { $self->get( '/complex/home/' ) }, qr/callback_error_key/, 'use key does not exist callback';

  like dies { $self->get( '/complex/level2[99]/level3_0' ) }, qr/callback_error_index/,
    'use index does not exist callback'
};

my $data = [ [ qw( a0 a1 ) ], { foo => 7 } ];

isa_ok my $self = CLASS->new( $data ), CLASS;

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
