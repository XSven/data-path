# Prefer numeric version for backwards compatibility
BEGIN { require 5.006000 }; ## no critic ( RequireUseStrict, RequireUseWarnings )
use strict;
use warnings;

#<<<
package Data::Selectable;
# ABSTRACT: Perl extension for XPath like accessing from complex data structures
BEGIN {
our $VERSION = 'v2.0.0';
}
#>>>

use Scalar::Util qw( reftype );
use Carp         qw( croak );

our $Debug; ## no critic ( ProhibitPackageVars )

sub new {
  my ( $class, $data, $callback ) = @_;
  $callback //= {};

  bless {
    data => $data,
    # Set callbacks to default if not given
    callback => {
      hash_value_is_undefined => $callback->{ hash_value_is_undefined } // sub {
        my ( $path, $data, $key ) = @_; ## no critic ( ProhibitReusedNames )
        croak "Value for hash key '$key' is undefined"
      },
      array_value_is_undefined => $callback->{ array_value_is_undefined } // sub {
        my ( $path, $data, $index ) = @_; ## no critic ( ProhibitReusedNames )
        croak "Value for array index $index is undefined"
      },
      retrieve_index_from_non_array => $callback->{ retrieve_index_from_non_array } // sub {
        my ( $path, $data, $index ) = @_; ## no critic ( ProhibitReusedNames )
        croak "Try to retrieve an array index $index from a ${ \( reftype $data ) } reference"
      },
      retrieve_key_from_non_hash => $callback->{ retrieve_key_from_non_hash } // sub {
        my ( $path, $data, $key ) = @_; ## no critic ( ProhibitReusedNames )
        croak "Try to retrieve a hash key '$key' from a ${ \( reftype $data ) } reference"
      }
    }
  } => $class
}

sub select {
  # $path is the current path that gets shortened from the beginning
  my ( $self, $path, $data ) = @_;
  $data //= $self->{ data };

  my ( $key, $is_sub, $index ) = _next_selector( \$path );

  my $value;
  if ( defined $key ) {
    if ( $is_sub ) {
      croak 'Not implemented yet'
      #      if ( blessed $data and $data->can( $key ) ) {
      #        $value = $data->$key()
      #      } elsif ( ref $data->{ $key } eq 'CODE' ) {
      #        $value = $data->{ $key }->()
      #      } else {
      #        $self->{ callback }->{ not_a_coderef_or_method }->( $data, $key, $index, $value, $path )
      #      }
    } else {
      $self->{ callback }->{ retrieve_key_from_non_hash }->( $path, $data, $key )
        unless reftype $data eq 'HASH';
      $self->{ callback }->{ hash_value_is_undefined }->( $path, $data, $key )
        if not defined $data->{ $key } and $path;
      $value = $data->{ $key }
    }
  } elsif ( defined $index ) {
    $self->{ callback }->{ retrieve_index_from_non_array }->( $path, $data, $index )
      unless reftype $data eq 'ARRAY';
    $self->{ callback }->{ array_value_is_undefined }->( $path, $data, $index )
      if not defined $data->[ $index ] and $path;
    $value = $data->[ $index ]
  } else {
    $value = $data
  }

  $value = $self->select( $path, $value ) if $path;

  $value
}

sub _next_selector {
  my $path = shift;

  my $key;
  my $is_sub;
  my $index;
  # \A[A-Za-z_][A-Za-z0-9_]*\z
  if ( $$path eq '' ) {
    1
  } elsif ( $$path =~ s/\A \/ ( [^\/\[]+ )//x ) {    # Key selector (example: /foo )
    $key    = $1;
    $is_sub = ( $key =~ s/(\(\))\z// )               # Key is method or sub name
  } elsif ( $$path =~ s/\A \[ ( 0 | -?[1-9][0-9]* ) \]//x ) {
    $index = $1;
  } else {
    croak "Cannot extract next selector from path '$$path'"
  }

  printf STDERR "path: %s, key: %s, is_sub: %s, index: %s\n", $$path, $key // '<undef>', $is_sub // '<undef>',
    $index // '<undef>'
    if $Debug;
  ( $key, $is_sub, $index )
}

1
