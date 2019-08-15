package main;

use 5.008;

use strict;
use warnings;

use Game::Life::Faster;
use Test::More 0.88;	# Because of done_testing();

my $life = Game::Life::Faster->new( 10 );

is_deeply $life, {
    breed	=> [ undef, undef, undef, 1 ],
    live	=> [ undef, undef, 1, 1 ],
    max_x	=> 9,
    max_y	=> 9,
    size_x	=> 10,
    size_y	=> 10,
}, 'Initialized correctly'
    or diag explain $life;

is_deeply [ $life->get_breeding_rules() ],
[ 3 ], 'get_breeding_rules()';

is_deeply [ $life->get_living_rules() ],
[ 2, 3 ], 'get_living_rules()';

ok $life->toggle_point( 0, 0 ), 'toggle_point turned point on';

is_deeply $life->{grid}, [
    [ [ 1, 0 ], [ undef, 1 ] ],
    [ [ undef, 1 ], [ undef, 1 ], ],
], 'toggle_point left grid in correct state';

ok ! $life->toggle_point( 0, 0 ), 'toggle_point again turned point off';

is_deeply $life->{grid}, [
    [ [ 0, 0 ], [ undef, 0 ] ],
    [ [ undef, 0 ], [ undef, 0 ], ],
], 'toggle_point again left grid in correct state';

ok $life->set_point( 0, 1 ), 'set_point turned point on';

is_deeply $life->{grid}, [
    [ [ 0, 1 ], [ 1, 0 ], [ undef, 1 ] ],
    [ [ undef, 1 ], [ undef, 1 ], [ undef, 1 ] ],
], 'set_point left grid in correct state';

ok $life->set_point( 0, 1 ), 'set_point again left point on';

is_deeply $life->{grid}, [
    [ [ 0, 1 ], [ 1, 0 ], [ undef, 1 ] ],
    [ [ undef, 1 ], [ undef, 1 ], [ undef, 1 ] ],
], 'set_point again left grid unchanged';

ok ! $life->unset_point( 0, 0 ), 'unset_point on already-clear point';

is_deeply $life->{grid}, [
    [ [ 0, 1 ], [ 1, 0 ], [ undef, 1 ] ],
    [ [ undef, 1 ], [ undef, 1 ], [ undef, 1 ] ],
], 'unset_point on already-clear point left grid unchanged';

ok ! $life->unset_point( 0, 1 ), 'unset_point on set point';

is_deeply $life->{grid}, [
    [ [ 0, 0 ], [ 0, 0 ], [ undef, 0 ] ],
    [ [ undef, 0 ], [ undef, 0 ], [ undef, 0 ] ],
], 'unset_point on set point cleared it';


$life->place_text_points( 0, 0, 'X', <<'EOD' );
.X.
..X
XXX
EOD

$life->process( 10 );

is_deeply $life->get_grid(), [
    [ ( 0 ) x 10 ],
    [ ( 0 ) x 10 ],
    [ ( 0 ) x 10 ],
    [ 0, 0, 0, 0, 1, 0, 0, 0, 0, 0 ],
    [ 0, 0, 1, 0, 1, 0, 0, 0, 0, 0 ],
    [ 0, 0, 0, 1, 1, 0, 0, 0, 0, 0 ],
    [ ( 0 ) x 10 ],
    [ ( 0 ) x 10 ],
    [ ( 0 ) x 10 ],
    [ ( 0 ) x 10 ],
], 'Grid after running glider 10 steps';

is scalar $life->get_text_grid(), <<'EOD',
..........
..........
..........
....X.....
..X.X.....
...XX.....
..........
..........
..........
..........
EOD
    'Text grid after running glider 10 steps';

# TODO add blinker, block and step.

done_testing;

1;

# ex: set textwidth=72 :
