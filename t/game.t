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

done_testing;

1;

# ex: set textwidth=72 :
