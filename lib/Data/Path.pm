# Prefer numeric version for backwards compatibility
BEGIN { require 5.006000 }; ## no critic ( RequireUseStrict, RequireUseWarnings )
use strict;
use warnings;

#<<<
package Data::Path;
# ABSTRACT: Perl extension for XPath like accessing from complex data structures
BEGIN {
our $VERSION = 'v2.0.0';
}
#>>>

use Scalar::Util qw( reftype blessed );
use Carp         qw( croak );

sub new {
  my ( $class, $data, $callback ) = @_;
  $callback //= {};

  bless {
    data => $data,
    # Set callbacks to default if not given
    callback => {
      key_does_not_exist => $callback->{ key_does_not_exist } // sub {
        my ( $data, $key, $index, $value, $path ) = @_; ## no critic ( ProhibitReusedNames )
        croak "key $key does not exist"
      },
      index_does_not_exist => $callback->{ index_does_not_exist } // sub {
        my ( $data, $key, $index, $value, $path ) = @_; ## no critic ( ProhibitReusedNames )
        croak "key $key\[$index\] does not exist"
      },
      retrieve_index_from_non_array => $callback->{ retrieve_index_from_non_array } // sub {
        my ( $data, $key, $index, $value, $path ) = @_; ## no critic ( ProhibitReusedNames )
        croak "trie to retrieve an index $index from a no array value (in key $key)"
      },
      retrieve_key_from_non_hash => $callback->{ retrieve_key_from_non_hash } // sub {
        my ( $data, $key, $index, $value, $path ) = @_; ## no critic ( ProhibitReusedNames )
        croak "trie to retrieve a key from a no hash value (in key $key)"
      },
      not_a_coderef_or_method => $callback->{ not_a_coderef_or_method } // sub {
        my ( $data, $key, $index, $value, $path ) = @_; ## no critic ( ProhibitReusedNames )
        croak "tried to retrieve from a non-existant coderef or method: $key in $data"
      }
    }
  } => $class
}

sub get {
  # $path is the current path that gets shortened from the beginning
  my ( $self, $path, $data ) = @_;
  $data //= $self->{ data };

  return $data if $path eq '';

  my $key;
  my $index;
  # Match and remove child operator "/"; JSONPath uses "."
  if ( $path =~ s/\A\/// ) {
    # Get mandatory key
    if ( $path =~ s/\A ( [^\/|\[]+ )//x ) {
      $key = $1
    } else {
      croak "Malformed path expression caused by undefined key: $path"
    }
    # Get optional index
    if ( $path =~ s/\A \[ ( [^\]]* ) \]//x ) {
      $index = $1;
      croak "Malformed path expression caused by invalid array index: $index"
        unless $index =~ m/\A\d+\z/
    }
  } else {
    croak "Malformed path expression caused by missing child operator: $path"
  }

  my $key_refers_to_coderef_or_method = ( $key =~ s/(\(\))\z// );

  $self->{ callback }->{ key_does_not_exist }->( $data, $key, $index, undef, $path )
    if not exists $data->{ $key } and $path;

  my $value;
  if ( $key_refers_to_coderef_or_method ) {
    if ( blessed $data and $data->can( $key ) ) {
      $value = $data->$key()
    } elsif ( ref $data->{ $key } eq 'CODE' ) {
      $value = $data->{ $key }->()
    } else {
      $self->{ callback }->{ not_a_coderef_or_method }->( $data, $key, $index, $value, $path )
    }
  } else {
    # FIXME: retrieve_key_from_non_hash callback should be called if $data
    # isn't a HASH reference!
    $value = $data->{ $key }
  }

  if ( defined $index ) {
    $self->{ callback }->{ index_does_not_exist }->( $data, $key, $index, $value, $path )
      if not exists $value->[ $index ] and $path;

    if ( reftype $value eq 'ARRAY' ) {
      $value = $value->[ $index ]
    } else {
      $self->{ callback }->{ retrieve_index_from_non_array }->( $data, $key, $index, $value, $path )
    }
  }

  # check if last element is reached
  if ( $path ) {
    if ( reftype $value eq 'HASH' || blessed $value ) {
      $value = $self->get( $path, $value )
    } else {
      $self->{ callback }->{ retrieve_key_from_non_hash }->( $data, $key, $index, $value, $path )
    }
  }

  $value
}

1
