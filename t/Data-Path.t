use strict;
use warnings;

use Test::More import => [ qw( BAIL_OUT is like new_ok ok use_ok ) ], tests => 15;
use Test::Fatal      qw( exception );
use Test::MockObject ();

my $class;

BEGIN {
  $class = 'Data::Path';
  use_ok $class or BAIL_OUT "Cannot load class '$class'!";
}

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

my $self = new_ok( $class, [ $data ] );

is $self->get( '/scalar' ), 'scalar_value', 'hash key, scalar value';

is $self->get( '/array[0]' ), 'array_value0', 'hash key, array index, scalar value';

is $self->get( '/hash/hash1' ), 'hash1_value', 'hash key, hash key, scalar value';

is $self->get( '/complex/level2[0]/level3_0[0]' ), 'level4_0',
  'hash key, hash key, array index, hash key, array index, scalar value';

is $self->get( '/complex/level2[0]/level3_0[2]' ), 'level4_2',
  'hash key, hash key, array index, hash key, array index, scalar value';

is $self->get( '/complex/level2[0]/level3_0[1]/level4_1/level5' ), 'huhu',
  'hash key, hash key, array index, hash key, array index, hash key, hash key, scalar value';

like exception { $self->get( '/complex/level2[99]/level3_0[1]/level4_1/level5' ) },
  qr/key level2\[99\] does not exist/, 'index does not exist';

like exception { $self->get( '/complex/level2[0]/level3_1[1]/level4_1/level5' ) }, qr/key level3_1 does not exist/,
  'key does not exist';

is $self->get( '/complex/level2[0]/level3_0[1]/level4_1/level5_not_exists' ), undef, 'trailing hash key does not exist';

is $self->get( '/complex/level2[0]/level3_0[99]' ), undef, 'trailing array index does not exist';

$self = new_ok $class => [
  $data,
  {
    'key_does_not_exist'   => sub { die 'callback_error_key' },
    'index_does_not_exist' => sub { die 'callback_error_index' }
  }
];

like exception { $self->get( '/complex/home/' ) }, qr/callback_error_key/, 'use key does not exist callback';

like exception { $self->get( '/complex/level2[99]/level3_0' ) }, qr/callback_error_index/,
  'use index does not exist callback';

__END__
my $obj = Test::MockObject->new( {} );

$obj->mock( 'method2' => sub { 'method2 val' } );
my $b2 = new_ok $class => [ $obj ];
is( $b->get( '/method()' ),         $data->{ method }->(), "subroutine returned" );
is( $b2->get( '/method2()', $obj ), $obj->method2(),       "method returned" );

my $deep_method = { foo => $obj };

$b = new_ok $class => [ $deep_method ];
is( $b->get( '/foo/method2()' ), $obj->method2(), "deep method returned" );

throws_ok { $class->new( { foo => 1 } )->get( 'goo' ) }
qr/malformed path expression/, 'malformed path expression throws an error';
throws_ok { $class->new( { foo => [ 1, 2 ] } )->get( '/foo[]' ) }
qr/malformed array index request/, 'malformed array path expression throws an error';
