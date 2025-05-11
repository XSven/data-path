use 5.006001;
use strict;
use warnings;

package Data::Path;

use Scalar::Util qw( reftype blessed );
use Carp         qw( croak );

our $VERSION = '1.4.1';

sub new {
  my ( $class, $data, $callback ) = @_;
  $callback ||= {};
  my $self = {
    data => $data

      # set call backs to default if not given
    ,
    callback => {
      key_does_not_exist => $callback->{ key_does_not_exist }
        || sub {
        my ( $data, $key, $index, $value, $rest ) = @_;
        croak "key $key does not exists\n";
        }

      ,
      index_does_not_exist => $callback->{ index_does_not_exist }
        || sub {
        my ( $data, $key, $index, $value, $rest ) = @_;
        croak "key $key\[$index\] does not exists\n";
        }

      ,
      retrieve_index_from_non_array => $callback->{ retrieve_index_from_non_array }
        || sub {
        my ( $data, $key, $index, $value, $rest ) = @_;
        croak "trie to retrieve an index $index from a no array value (in key $key)\n";
        }

      ,
      retrieve_key_from_non_hash => $callback->{ retrieve_key_from_non_hash }
        || sub {
        my ( $data, $key, $index, $value, $rest ) = @_;
        croak "trie to retrieve a key from a no hash value (in key $key)\n";
        },
      not_a_coderef_or_method => $callback->{ not_a_coderef_or_method }
        || sub {
        my ( $data, $key, $index, $value, $rest ) = @_;
        croak "tried to retrieve from a non-existant coderef or method: $key in $data";
        }
    }

  };
  return bless $self, $class;
}

sub get {
  my ( $self, $rkey, $data ) = @_;

  # set data to
  $data ||= $self->{ data };

  # get key till / or [
  my $key = $1 if ( $rkey =~ s/^\/([^\/|\[]+)//o );
  croak 'malformed path expression'
    unless $key;

  croak 'malformed array index request'
    if $rkey =~ /^\[([^\d]*)\]/;
  # check index for index
  my $index = $1 if ( $rkey =~ s/^\[(\d+)\]//o );

  # set rest
  my $rest = $rkey;

  # get key from data
  my $value;
  if ( $key =~ s/(\(\))$// ) {
    $self->{ callback }->{ not_a_coderef_or_method }->( $data, $key, $index, $value, $rest )
      unless exists $data->{ $key }
      or ( blessed $data && $data->can( $key ) );

    $value = $data->{ $key }->() if ( exists $data->{ $key } );
    $value = $data->$key()       if blessed $data && $data->can( $key );
  } else {
    $value = $data->{ $key };
  }

  # croak if key does not exists and something after that is requested
  $self->{ callback }->{ key_does_not_exist }->( $data, $key, $index, $value, $rest )
    if not exists $data->{ $key } and $rest;

  # check index
  if ( defined $index ) {

    # croak if index does not exists and something after that is requested
    $self->{ callback }->{ index_does_not_exist }->( $data, $key, $index, $value, $rest )
      if not exists $value->[ $index ] and $rest;

    if ( reftype $value eq 'ARRAY' ) {
      $value = $value->[ $index ];
    } else {
      $self->{ callback }->{ retrieve_index_from_non_array }->( $data, $key, $index, $value, $rest );
    }
  }

  # check if last element is reached
  if ( $rest ) {
    if ( reftype $value eq 'HASH' || blessed $value ) {
      $value = $self->get( $rest, $value );
    } else {
      $self->{ callback }->{ retrieve_key_from_non_hash }->( $data, $key, $index, $value, $rest );
    }
  }

  return $value;
}

1;
