package main;

use 5.008;

use strict;
use warnings;

use Game::Life::Faster;
use Test::More 0.88;	# Because of done_testing();

use constant CLASS	=> 'Game::Life::Faster';

my $life = CLASS->new( 10 );

my $clone = CLASS->THAW( undef, $life->FREEZE() );

isa_ok $clone, CLASS;

is_deeply $clone, $life, 'FREEZE/THAW empty object';

$life->place_points( 0, 0, [
	[ undef, 1 ],
	[ undef, undef, 1 ],
	[ 1, 1, 1 ],
    ] );

is_deeply CLASS->THAW( undef, $life->FREEZE() ), $life,
'FREEZE/THAW populated object';

$life->process( 4 );
$life->__prune();

is_deeply CLASS->THAW( undef, $life->FREEZE() ), $life,
'FREEZE/THAW processed object';

if ( eval {
	require JSON::XS;
	JSON::XS->can( 'allow_tags' )
    } ) {
    my $json = JSON::XS->new()->allow_tags();
    my $ref = ref $json;

    is_deeply $json->decode( $json->encode( $life ) ), $life,
	"$ref encode/decode processed object"
	    or diag join ' ', $ref, $json->VERSION(),
		'round-trip failure';
} else {
    note 'No usable JSON found; skipping.';
}

if ( eval { require CBOR::XS; CBOR::XS->VERSION( 0.04 ) } ) {

    is_deeply CBOR::XS::decode_cbor( CBOR::XS::encode_cbor( $life ) ),
	$life, 'CBOR::XS encode/decode processed object'
	    or diag join ' ', 'CBOR::XS', CBOR::XS->VERSION(),
		'round-trip-failure';
} else {
    note 'No usable CBOR::XS found; skipping.';
}

if ( eval {
	require Sereal::Encoder;
	Sereal::Encoder->VERSION( 2 );
	require Sereal::Decoder;
	Sereal::Decoder->VERSION( 2 );
	1 } ) {
    my $enc = Sereal::Encoder->new( {
	    freeze_callbacks	=> 1,
	} );
    my $dec = Sereal::Decoder->new();
    is_deeply $dec->decode( $enc->encode( $life ) ), $life,
	'Sereal encode/decode processed object'
	    or diag join ' ', ref $dec, $dec->VERSION(),
		ref $enc, $enc->VERSION(), 'round-trip failure';
} else {
    note 'No usable Sereal::Encoder/Sereal::Decoder found; skipping.';
}

done_testing;

# This encapsulation violation cleans up the original object so that
# is_deeply against a serialized/deserialized object will succeed if
# they are in fact equal. The issue is that:
# * If the object has been processed it may contain cells like
#   [ undef, 0 ]; that is, cells that were never initialized, and which
#   have no neighbors. Because the number of neighbors is not
#   represented in the serialization, these deserialize to undef,
#   causing the round-trip check to fail.
# * I can't do the pruning in get_grid_used() because the CBOR::XS
#   documentation warns (direly) against modifying the object in the
#   FREEZE() method.

sub Game::Life::Faster::__prune {
    my ( $self ) = @_;
    foreach ( @{ $self->{grid} || [] } ) {
	foreach ( @{ $_ || [] } ) {
	    $_
		and not defined $_->[0]
		and not $_->[1]
		and $_ = undef;
	}
    }
    return $self;
}

1;

# ex: set textwidth=72 :
