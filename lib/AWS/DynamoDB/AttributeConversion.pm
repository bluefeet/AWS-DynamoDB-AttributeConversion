package AWS::DynamoDB::AttributeConversion;

=head1 NAME

AWS::DynamoDB::AttributeConversion - Adjust Perl data structures to be
compatible with AWS' DynamoDB API.

=head1 SYNOPSIS

    use AWS::DynamoDB::AttributeConversion;
    
    my $ready_for_aws = freeze( {this=>123} );
    # { M => { this => {N => '123'} } }

=head1 DESCRIPTION

Storing complex data structures in DynamoDB can be a pain.  This module makes
it easy to convert plain scalars, arrays, and hashes into the structure
that is needed to store your data in DynamoDB.  This way you can use DynamoDB's
ability to retrieve and filter data sets based on these structures.

This module is primarly targetted at being used with L<Paws::DynamoDB>, but is in
no way written as to be tied to L<Paws>.

Some more information can be found at
L<http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_AttributeValue.html>.

=head1 DATA TYPES

Perl does not have native data types for all the data types which DynamoDB
supports.  Due to this some "dumbing down" of the data types happen when
they are thawed.  For example, these:

    { B=>'a' },
    { BS=>['a','b','c'] },
    { BOOL=>1 },
    { SS=>['a','b','c'] },

all thaw to:

    'a',
    ['a', 'b', 'c'],
    1,
    ['a', 'b', 'c'],

and will freeze back to:

    { S=>'a' },
    { L=>['a','b','c'] },
    { N=>1 },
    { L=>['a','b','c'] },

A future update may include the option to enable native handling of these
types, such as using L<boolean> for C<BOOL> types.

=cut

use strict;
use warnings;

use B;
use Carp qw( croak );

use Exporter qw( import );

our @EXPORT = qw(
    freeze_attribute
    thaw_attribute
);

=head1 EXPORTED

=head2 freeze_attribute

    my $aws_data = freeze_attribute( $plain_data );

Takes a plain scalar, hashref, or arrayref, and returns a new data
structure marked up and ready to be sent to AWS (usually to C<PutItem>).

=cut

sub freeze_attribute {
  my ($data) = @_;

  if (!defined $data) {
    return { NULL => 1 };
  }

  my $ref = ref $data;

  if ($ref eq 'HASH') {
    return { M => {
      map {
        $_ => freeze_attribute($data->{$_})
      }
      keys( %$data )
    }};
  }
  elsif ($ref eq 'ARRAY') {
    return { L => [
      map { freeze_attribute($_) }
      @$data
    ]};
  }
  elsif (!$ref) {
    my $type = _is_numeric( $data ) ? 'N' : 'S';
    return { $type => "$data" };
  }

  local $Carp::Internal{ (__PACKAGE__) } = 1;
  croak "A $ref may not be frozen as a DynamoDB attribure";
}

=head2 thaw_attribute

    my $plain_data = thaw_attribute( $aws_data );

Takes a marked up AWS data structure (most often this will be the C<Item>
returned by C<GetItem>) and returns a plain scalar, hashref, or arrayref.

=cut

sub thaw_attribute {
  my ($data) = @_;

  my ($type) = keys(%$data);
  my $value = $data->{$type};

  return $value if
    $type eq 'B' or
    $type eq 'BS' or
    $type eq 'S' or
    $type eq 'SS';

  return !!$value if $type eq 'BOOL';

  return [
    map { thaw_attribute($_) }
    @$value
  ] if $type eq 'L';

  return {
    map { $_ => thaw_attribute($value->{$_}) }
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

  die 'bar';
}

# stolen from JSON::PP
sub _is_numeric {
   my $value = shift;
   my $b_obj = B::svref_2object(\$value);
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

