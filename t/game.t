package main;

use 5.008;

use strict;
use warnings;

use Game::Life::Faster;
use Test::More 0.88;	# Because of done_testing();

my $life = Game::Life::Faster->new( 10 );

is_deeply $life, {
    breed	=> [ undef, undef, undef, 1 ],
    grid	=> [
	( [ ( [ 0, 0 ] ) x 10 ] ) x 10,
    ],
    live	=> [ undef, undef, 1, 1 ],
    size_x	=> 9,
    size_y	=> 9,
}, 'Initialized correctly';

$life->place_text_points( 0, 0, 'X', <<'EOD' );
.X.
..X
XXX
EOD

$life->process( 10 );

is scalar $life->get_text_grid(), <<'EOD', 'Run glider 10 steps';
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


done_testing;

1;

# ex: set textwidth=72 :
