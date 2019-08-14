package Game::Life::Faster;

use 5.008;

use strict;
use warnings;

use Carp;
use List::Util qw{ max min };

our $VERSION = '0.000_01';

use constant ARRAY_REF	=> ref [];

use constant DEFAULT_BREED	=> [ 3 ];
use constant DEFAULT_LIVE	=> [ 2, 3 ];
use constant DEFAULT_SIZE	=> 100;

use constant NEW_LINE_RE		=> qr< \n >smx;
use constant NON_NEGATIVE_INTEGER_RE	=> qr< \A [0-9]+ \z >smx;
use constant POSITIVE_INTEGER_RE	=> qr< \A [1-9][0-9]* \z >smx;

sub new {
    my ( $class, $size, $breed, $live ) = @_;

    my %self;

    my $ref = ref $size;
    if ( ARRAY_REF eq $ref ) {
	@self{ qw{ size_x size_y } } = @{ $size };
    } elsif ( ! $ref ) {
	$self{size_x} = $self{size_y} = $size;
    } else {
	croak "Argument may not be $size";
    }
    $self{size_x} ||= DEFAULT_SIZE;
    $self{size_y} ||= DEFAULT_SIZE;
    $self{size_x} =~ POSITIVE_INTEGER_RE
	and $self{size_y} =~ POSITIVE_INTEGER_RE
	or croak 'Sizes must be positive integers';
    --$self{size_x};
    --$self{size_y};

    $breed ||= DEFAULT_BREED;
    ARRAY_REF eq ref $breed
	or croak 'Breed rule must be an array reference';
    $self{breed} = [];
    foreach ( @{ $breed } ) {
	$_ =~ NON_NEGATIVE_INTEGER_RE
	    or croak 'Breed rule must be a reference to an array of non-negative integers';
	$self{breed}[$_] = 1;
    }

    $live ||= DEFAULT_LIVE;
    ARRAY_REF eq ref $live
	or croak 'Live rule must be an array reference';
    $self{live} = [];
    foreach ( @{ $live } ) {
	$_ =~ NON_NEGATIVE_INTEGER_RE
	    or croak 'Live rule must be a reference to an array of non-negative integers';
	$self{live}[$_] = 1;
    }

    $self{grid} = [];

    my $me = bless \%self, ref $class || $class;

    foreach my $x ( 0 .. $self{size_x} ) {
	$self{grid}[$x] = [];
	foreach my $y ( 0 .. $self{size_y} ) {
	    $me->set_point_state( $x, $y, 0 );
	}
    }
    delete $self{changed};

    return $me;
}

sub get_text_grid {
    my ( $self, $living, $dead ) = @_;
    $living	||= 'X';
    $dead	||= '.';
    my @char = ( $dead, $living );
    my @rslt;
    foreach my $x ( 0 .. $self->{size_x} ) {
	push @rslt, join '', map { $char[$self->{grid}[$x][$_][0]] }
	0 .. $self->{size_y};
    }
    return wantarray ? @rslt : join '', map { "$_\n" } @rslt;
}

sub place_text_points {
    my ( $self, $x, $y, $living, @array ) = @_;
    my $ix = $x;
    1 == @array
	and $array[0] =~ NEW_LINE_RE
	and @array = split qr< @{[ NEW_LINE_RE ]} >smx, $array[0];
    foreach my $line ( @array ) {
	my $iy = $y;
	foreach my $value ( map { $living eq $_ } split qr<>, $line ) {
	    $self->set_point_state( $ix, $iy, $value );
	    $iy++;
	}
	$ix++;
    }
    return;
}

sub process {
    my ( $self, $steps ) = @_;
    $steps ||= 1;

    foreach ( 1 .. $steps ) {
	my @toggle;

	foreach my $chg ( keys %{ $self->{changed} } ) {
	    my ( $x, $y ) = split qr< , >smx, $chg;
	    my $cell = $self->{grid}[$x][$y];
	    if ( $cell->[0] ) {
		$self->{live}[ $cell->[1] || 0 ]
		    or push @toggle, [ $x, $y, 0 ];
	    } else {
		$self->{breed}[ $cell->[1] || 0 ]
		    and push @toggle, [ $x, $y, 1 ];
	    }
	}

	delete $self->{changed};

	foreach my $cell ( @toggle ) {
	    $self->set_point_state( @{ $cell } );
	}
    }
    return;
}

sub set_point_state {
    my ( $self, $x, $y, $state ) = @_;
    my $off_grid = ( $x < 0 || $x > $self->{size_x} ||
	$y < 0 || $y > $self->{size_y} )
	and $state
	and croak 'Attempt to place living cell outside grid';
    $state = $state ? 1 : 0;
    my $prev_val = $off_grid ? 0 : $self->{grid}[$x][$y][0] ? 1 : 0;
    unless ( $off_grid ) {
	$self->{grid}[$x][$y][0] = $state;
	$self->{grid}[$x][$y][1] ||= 0;
    }
    my $delta = $state - $prev_val
	or return $state;
    foreach my $ix ( max( 0, $x - 1 ) .. min( $self->{size_x}, $x + 1 ) ) {
	foreach my $iy ( max( 0, $y - 1 ) .. min( $self->{size_y}, $y + 1 ) ) {
	    $self->{grid}[$ix][$iy][1] += $delta;
	    $self->{changed}{"$ix,$iy"}++;
	}
    }
    # A cell is not its own neighbor, but the above nested loops assumed
    # that it was. We fix that here, rather than skip it inside the
    # loops.
    unless ( $off_grid ) {
	$self->{grid}[$x][$y][1] -= $delta;
	--$self->{changed}{"$x,$y"};
    }
    return $state;
}

1;

__END__

=head1 NAME

Game::Life::Faster - Plays John Horton Conway's Game of Life

=head1 SYNOPSIS

 use Game::Life::Faster;
 my $game = Game::Life::Faster->new( 20 );
 $game->place_points( 10, 10, [
     [ 1, 1, 1 ],
     [ 1, 0, 0 ],
     [ 0, 1, 0 ],
  ] );
  for ( 1 .. 20 ) {
      print scalar $game->get_text_grid(), "\n\n";
      $game->process();
  }

=head1 DESCRIPTION

This Perl package is yet another implementation of John Horton Conway's
Game of Life. This "game" takes place on a rectangular grid, each of
whose cells is considered "living" or "dead". The grid is seeded with an
initial population, and then the rules are iterated. In each iteration
cells change state based on their current state and how many of the 8
adjacent cells (orthogonally or diagonally) are "living".

In Conway's original formulation, the rules were that a "dead" cell
becomes alive if it has exactly two living neighbors, and a "living"
cell becomes "dead" unless it has two or three living neighbors.

This implementation was inspired by L<Game::Life|Game::Life>, and is
intended to be reasonably compatible with its API. But the internals
have been tweaked in a number of ways in order to get better
performance, particularly on large but mostly-empty grids.

=head1 METHODS

This class supports the following public methods:

=head2 new

 my $life = Game::Life::Faster->new( $size, $breed, $live )

This static method creates a new instance of the game. The arguments
are:

=over

=item $size

This specifies the size of the grid. It must be either a positive
integer (which creates a square grid) or a reference to an array
containing two positive integers (which creates a rectangular grid of
the given width and height.

The default is C<100>.

=item $breed

This specifies the number of neighbors a "dead" cell needs to become
"living". It must be a reference to an array of non-negative integers;
the cell will become "living" if its number of neighbors appears in the
array. Order is not important.

The default is C<[ 3 ]>.


=item $live

This specifies the number of neighbors a "living" cell needs to remain
"living". It must be a reference to an array of non-negative integers;
the cell will remain "living" if its number of neighbors appears in the
array. Order is not important.

=back

=head2 get_text_grid

 print "$_\n" for $life->get_text_grid( $living, $dead );

This method returns an array of strings representing the state of the
grid. The arguments are:

=over

=item $living

This is the character used to represent a "living" cell.

The default is C<'X'>.

=item $dead

This is the character used to represent a "dead" cell.

The default is C<'.'>.

=back

As an incompatible change to the same-named method of
L<Game::Life|Game::Life>, if called in scalar context this method
returns a single string representing the entire grid.

=head2 place_text_points

 $life->place_text_points( $x, $y, $living, @array );

This method populates a portion of the grid whose top left corner is
specified by C<$x> and C<$y> with the state information found in the
text of C<@array>, one row per element. Characters in C<@array> that
match the character in C<$living> cause the corresponding cells to be
made "living." All other characters cause the cell to be made "dead."
This method interprets the strings in C<@array> as new state

As an incompatible change to the same-named method of
L<Game::Life|Game::Life>, if C<@array> contains exactly one element
B<and> that element contains new line characters, it is split on new
lines, allowing something like

 $life->place_text_points( 0, 0, 'X', <<'EOD' );
 .X.
 ..X
 XXX
 EOD

=head2 process

 $life->process( $iterations );

This method runs the game for the specified number of iterations, which
defaults to C<1>.

=head2 set_point_state

 $life->set_point_state( $x, $y, $state );

This method sets the state of the point at position C<$x>, C<$y> of the
grid to C<$state>. A true value of C<$state> sets the cell "living;" a
false value sets it "dead."

An exception will be raised if you attempt to set a point "live" which
is outside the grid.

This method is an extension to L<Game::Life|Game::Life>.

=head1 SEE ALSO

L<Game::Life|Game::Life>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2019 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
