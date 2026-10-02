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
      key_does_not_exist => $callback->{ key_does_not_exist } // sub {
        my ( $path, $data, $key ) = @_; ## no critic ( ProhibitReusedNames )
        croak "Hash key '$key' does not exist"
      },
      index_does_not_exist => $callback->{ index_does_not_exist } // sub {
        my ( $path, $data, $index ) = @_; ## no critic ( ProhibitReusedNames )
        croak "Array index $index does not exist"
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

sub get {
  # $path is the current path that gets shortened from the beginning
  my ( $self, $path, $data ) = @_;
  $data //= $self->{ data };

  return $data if $path eq '';

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
      $self->{ callback }->{ key_does_not_exist }->( $path, $data, $key )
        if not exists $data->{ $key } and $path;
      $value = $data->{ $key }
    }
  } elsif ( defined $index ) {
    $self->{ callback }->{ retrieve_index_from_non_array }->( $path, $data, $index )
      unless reftype $data eq 'ARRAY';
      # FIXME: As of perl 5.20.2 calling exists on array values is strongly discouraged!
    $self->{ callback }->{ index_does_not_exist }->( $path, $data, $index )
      if not exists $data->[ $index ] and $path;
    $value = $data->[ $index ]
  }

  $value = $self->get( $path, $value ) if $path;

  $value
}

sub _next_selector {
  my $path = shift;

  my $key;
  my $is_sub;
  my $index;
  # \A[A-Za-z_][A-Za-z0-9_]*\z
  if ( $$path =~ s/\A \/ ( [^\/\[]+ )//x ) {    # Key selector (example: /foo )
    $key    = $1;
    $is_sub = ( $key =~ s/(\(\))\z// )           # Key is method or sub name
  } elsif ( $$path =~ s/\A \[ ( 0 | -?[1-9][0-9]* ) \]//x ) {
    $index = $1;
  } else {
    croak "Cannot extract next selector from path '$$path'"
  }

  printf STDERR "path: %s, key: %s, is_sub: %s, index: %s\n", $$path, $key // '', $is_sub ? 'yes' : 'no', $index // ''
    if $Debug;
  ( $key, $is_sub, $index )
}

1
