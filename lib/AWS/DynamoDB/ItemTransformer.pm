package AWS::DynamoDB::ItemTransformer;

=head1 NAME

AWS::DynamoDB::ItemTransformer - Convert Perl data structures to and
from AWS DynamoDB item attributes.

=head1 SYNOPSIS

    use AWS::DynamoDB::ItemTransformer;
    
    my %ddb_item = encode_ddb_item( foo => 32 );
    my %item = decode_ddb_item( foo => { N => '32' } );
    
    my $ddb_value = encode_ddb_value( 32 );
    my $value = decode_ddb_value( { N => '32' } );
    
    # Or, using the OO interface:
    my $item_transformer = AWS::DynamoDB::ItemTransformer->new();
    
    my %ddb_item = $item_transformer->encode_item( foo => 32 );
    my %item = $item_transformer->decode_item( foo => { N => 32 } );
    
    my $ddb_value = $item_transformer->encode_value( 32 );
    my $value = $item_transformer->decode_value( { N => 32 } );

=head1 DESCRIPTION

DynamoDB items have an explicit data type syntax.  This module makes
it easy to convert plain scalars, arrays, and hashes into the structure
that is needed to store your data in, and retrieve your data from, DynamoDB.

More information can be found at
L<http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_AttributeValue.html>.

This module has both a functional interface, which provides the default
feature set, as well as an OO interface which allows for the use
of plugins to provide advanced functionality.

=head1 PLUGINS

At this time available plugins include:

=over

=item *

L<AWS::DynamoDB::ItemTransformer::boolean>

=item *

L<AWS::DynamoDB::ItemTransformer::Set::Object>

=item *

L<AWS::DynamoDB::ItemTransformer::Paws>

=back

=head1 DATA TYPES

Perl does not have native data types for all the data types which DynamoDB
supports.  Due to this some "dumbing down" of the data types happen when
they are thawed.  For example, these:

    { B=>'a' },
    { BS=>['a','b','c'] },
    { BOOL=>1 },
    { SS=>['a','b','c'] },

all encode to:

    'a',
    ['a', 'b', 'c'],
    1,
    ['a', 'b', 'c'],

and will decode back to:

    { S=>'a' },
    { L=>['a','b','c'] },
    { N=>1 },
    { L=>['a','b','c'] },

Alternatively you can use various plugins to alter this behavior, such
as L<AWS::DynamoDB::ItemTransformer::boolean> which adds support for
encoding and decoding L<boolean> objects as the C<BOOL> data type.

=cut

use B;
use Carp qw( croak );

use Moo;
use strictures 2;
use namespace::clean;

use Exporter qw( import );

our @EXPORT = qw(
    encode_ddb_item
    decode_ddb_item
    encode_ddb_value
    decode_ddb_value
);

my $default_object = __PACKAGE__->new();

=head1 EXPORTED

=head2 encode_ddb_item

    my %ddb_item = encode_ddb_item( foo => 32 );
    # foo => { N => '32' }

Take a hash of key value pairs and returns a hash with the values
passed through L</encode_ddb_value>.  The returned hash is usually
used with the C<PutItem> API.

=head2 decode_ddb_item

    my %item = decode_ddb_item( foo => {N => '32'} );
    # foo => 32

Takes an item hash, usually returned by the C<GetItem> API, and
returns a new hash with the item values passed through
L</decode_ddb_value>.

=head2 encode_ddb_value

    my $ddb_value = encode_ddb_value( 32 );
    # { N => '32' }

Takes a plain scalar, hashref, or arrayref, and returns a new data
structure marked up and ready to be sent to AWS (usually to the
C<PutItem> API).

=head2 decode_ddb_value

    my $value = decode_ddb_value( {N => '32'} );
    # 32

Takes an AWS attribute value hash ref and returns the equivalent
Perl data structure.

=cut

sub encode_ddb_item { $default_object->encode_item( @_ ) }
sub decode_ddb_item { $default_object->decode_item( @_ ) }

sub encode_ddb_value { $default_object->encode_value( @_ ) }
sub decode_ddb_value { $default_object->decode_value( @_ ) }

=head1 METHODS

=head2 encode_item

This is the OO equivalent of L</encode_ddb_item>.

=cut

sub encode_item {
    my ($self, %item) = @_;

    return(
        map { $_ => $self->encode_value( $item{$_} ) }
        keys( %item )
    );
}

=head2 decode_item

This is the OO equivalent of L</decode_ddb_item>.

=cut

sub decode_item {
    my ($self, %ddb_item) = @_;

    return(
        map { $_ => $self->decode_value( $ddb_item{$_} ) }
        keys( %ddb_item )
    );
}

=head2 encode_value

This is the OO equivalent of L</encode_ddb_value>.

=cut

sub encode_value {
    my ($self, $value) = @_;

    if (!defined $value) {
        return { NULL => 1 };
    }

    my $ref = ref $value;

    if ($ref eq 'HASH') {
        return { M => {
        map {
            $_ => $self->encode_value($value->{$_})
        }
        keys( %$value )
        }};
    }
    elsif ($ref eq 'ARRAY') {
        return { L => [
        map { $self->encode_value($_) }
        @$value
        ]};
    }
    elsif (!$ref) {
        my $type = $self->is_numeric( $value ) ? 'N' : 'S';
        return { $type => "$value" };
    }

    local $Carp::Internal{ (__PACKAGE__) } = 1;
    croak "A $ref may not be encoded as a DynamoDB attribure value";
}

=head2 decode_value

This is the OO equivalent of L</decode_ddb_value>.

=cut

sub decode_value {
  my ($self, $ddb_value) = @_;

  my ($type) = keys(%$ddb_value);
  my $value = $ddb_value->{$type};

  return $value if
    $type eq 'B' or
    $type eq 'BS' or
    $type eq 'S' or
    $type eq 'SS';

  return !!$value if $type eq 'BOOL';

  return [
    map { $self->decode_value($_) }
    @$value
  ] if $type eq 'L';

  return {
    map { $_ => $self->decode_value($value->{$_}) }
    keys( %$value )
  } if $type eq 'M';

  return $value+0 if $type eq 'N';

  return [
    map { $_+0 }
    @$value
  ] if $type eq 'NS';

  return undef if $type eq 'NULL';

  local $Carp::Internal{ (__PACKAGE__) } = 1;
  croak "The $type DynamoDB attribute value type is unsupported by " . __PACKAGE__;
}

=head2 is_numeric

Returns true if the passed scalar is numeric.  Whether a scalar
is numeric is determined by looking at the SV flags for the scalar.

This is used by L</encode_value> to determine if a non-ref value is
a string (S) or number (N).

=cut

# stolen from JSON::PP
sub is_numeric {
   my ($self, $scalar) = @_;
   my $b_obj = B::svref_2object(\$scalar);
   my $flags = $b_obj->FLAGS;
   return (( $flags & B::SVf_IOK or $flags & B::SVp_IOK
          or $flags & B::SVf_NOK or $flags & B::SVp_NOK
        ) and !($flags & B::SVf_POK ))
}

1;
__END__

=head1 AUTHOR

Aran Clary Deltac <bluefeetE<64>gmail.com>

=head1 ACKNOWLEDGEMENTS

Thanks to L<ZipRecruiter|https://www.ziprecruiter.com/>
for encouraging their employees to contribute back to the open
source ecosystem.  Without their dedication to quality software
development this distribution would not exist.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

