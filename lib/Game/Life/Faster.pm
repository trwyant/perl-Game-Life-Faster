package Game::Life::Faster;

use 5.008001;

use strict;
use warnings;

use Carp;
use List::Util qw{ max min };

our $VERSION = '0.007';

use constant ARRAY_REF	=> ref [];

use constant DEFAULT_BREED	=> [ 3 ];
use constant DEFAULT_LIVE	=> [ 2, 3 ];
use constant DEFAULT_SIZE	=> 100;

use constant NEW_LINE_RE		=> qr< \n >smx;
use constant NON_NEGATIVE_INTEGER_RE	=> qr< \A [0-9]+ \z >smx;
use constant POSITIVE_INTEGER_RE	=> qr< \A [1-9][0-9]* \z >smx;

use constant TOGGLE_STATE	=> do { bless \my $x, 'Toggle_State' };
use constant TOGGLE_STATE_REF	=> ref TOGGLE_STATE;

sub new {
    my ( $class, $size, $breed, $live ) = @_;

    my $self;

    my $ref = ref $size;
    if ( ARRAY_REF eq $ref ) {
	$self->{size_x} = $size->[1];
	$self->{size_y} = $size->[0];
    } elsif ( ! $ref ) {
	$self->{size_x} = $self->{size_y} = $size;
    } else {
	croak "Argument may not be $size";
    }
    $self->{size_x} ||= DEFAULT_SIZE;
    $self->{size_y} ||= DEFAULT_SIZE;
    $self->{size_x} =~ POSITIVE_INTEGER_RE
	and $self->{size_y} =~ POSITIVE_INTEGER_RE
	or croak 'Sizes must be positive integers';
    $self->{max_x} = $self->{size_x} - 1;
    $self->{max_y} = $self->{size_y} - 1;

    bless $self, ref $class || $class;
    $self->set_rules( $breed, $live );

    $self->clear();

    return $self;
}

sub clear {
    my ( $self ) = @_;
    delete $self->{grid};
    delete $self->{changed};
    $self->{living_x} = [];
    $self->{living_y} = [];
    $self->{change_count} = 0;
    return $self;
}

sub get_active_grid_coord {
    my ( $self ) = @_;
    my ( $min_x, $max_x, $min_y, $max_y ) = ( $self->{size_x}, 0,
	$self->{size_y}, 0 );
    foreach my $ix ( keys %{ $self->{changed} } ) {
	$min_x = $ix if $ix < $min_x;
	$max_x = $ix if $ix > $max_x;
	foreach my $iy ( keys %{ $self->{changed}{$ix} } ) {
	    $min_y = $iy if $iy < $min_y;
	    $max_y = $iy if $iy > $max_y;
	}
    }
    $max_x < $min_x
	and croak 'No active cells';
    return [ $min_x, $max_x, $min_y, $max_y ];
}

sub get_breeding_rules {
    my ( $self ) = @_;
    return $self->get_rule( 'breed' );
}

sub get_grid {
    my ( $self, $coord ) = @_;
    $coord ||= $self->get_grid_coord();
    $self->{grid}
	or return [ ( [ ( 0 ) x ( $coord->[3] - $coord->[2] + 1 ) ] ) x
	    ( $coord->[1] - $coord->[0] + 1 ) ];
    my @rslt;
    foreach my $x ( $coord->[0] .. $coord->[1] ) {
	if ( $self->{grid}{$x} ) {
	    push @rslt, [];
	    foreach my $y ( $coord->[2] .. $coord->[3] ) {
		push @{ $rslt[-1] }, $self->{grid}{$x}{$y} ?
		    $self->{grid}{$x}{$y}[0] ? 1 : 0 : 0;
	    }
	} else {
	    push @rslt, [ ( 0 ) x ( $coord->[3] - $coord->[2] + 1 ) ];
	}
    }
    return \@rslt;
}

sub get_grid_coord {
    my ( $self ) = @_;
    return [ 0, $self->{max_x}, 0, $self->{max_y} ];
}

sub get_living_rules {
    my ( $self ) = @_;
    return $self->get_rule( 'live' );
}

sub get_text_grid {
    my ( $self, $living, $dead, $coord ) = @_;
    $living	||= 'X';
    $dead	||= '.';
    $coord ||= $self->get_grid_coord();
    my @rslt;
    if ( $self->{grid} ) {
	foreach my $x ( $coord->[0] .. $coord->[1] ) {
	    if ( $self->{grid}{$x} ) {
		push @rslt, join '', map {
		    ( $self->{grid}{$x}{$_} && $self->{grid}{$x}{$_}[0]) ?
		    $living : $dead
		} $coord->[2] .. $coord->[3];
	    } else {
		push @rslt, $dead x ( $coord->[3] - $coord->[2] + 1 );
	    }
	}
    } else {
	@rslt = ( $dead x ( $coord->[3] - $coord->[2] + 1 ) ) x (
	    $coord->[1] - $coord->[0] + 1 );
    }
    return wantarray ? @rslt : join '', map { "$_\n" } @rslt;
}

sub get_active_text_grid {
    my ( $self, $living, $dead ) = @_;
    return $self->get_text_grid( $living, $dead,
	$self->get_active_grid_coord() );
}

sub get_used_text_grid {
    my ( $self, $living, $dead ) = @_;
    return $self->get_text_grid( $living, $dead,
	$self->get_used_grid_coord() );
}

sub get_used_grid {
    my ( $self ) = @_;
    return $self->get_grid( $self->get_used_grid_coord() );
}

sub get_used_grid_coord {
    my ( $self ) = @_;
    my $min_x = $self->{size_x};
    for ( $min_x = 0; $min_x < $self->{size_x}; $min_x++ ) {
	$self->{living_x}[$min_x]
	    or next;
	my ( $max_x, $min_y, $max_y );
	for ( $max_x = $self->{size_x}; $max_x >= $min_x; ) {
	    $self->{living_x}[--$max_x]
		and last;
	}
	for ( $min_y = 0; $min_y < $self->{size_y}; $min_y++ ) {
	    $self->{living_y}[$min_y]
		and last;
	}
	for ( $max_y = $self->{size_y}; $max_y >= $min_y; ) {
	    $self->{living_y}[--$max_y]
		and last;
	}
	return [ $min_x, $max_x, $min_y, $max_y ];
    }
    croak 'No occupied cells';
}

sub place_points {
    my ( $self, $x, $y, $array ) = @_;
    my $ix = $x;
    foreach my $row ( @{ $array } ) {
	my $iy = $y;
	foreach my $state ( @{ $row } ) {
	    $self->set_point_state( $ix, $iy, $state );
	    $iy++;
	}
	$ix++;
    }
    return;
}

sub place_text_points {
    my ( $self, $x, $y, $living, @array ) = @_;
    my $ix = $x;
    1 == @array
	and $array[0] =~ NEW_LINE_RE
	and @array = split qr< @{[ NEW_LINE_RE ]} >smx, $array[0];
    foreach my $line ( @array ) {
	my $iy = $y;
	foreach my $state ( map { $living eq $_ } split qr<>, $line ) {
	    $self->set_point_state( $ix, $iy, $state );
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

	my $changed = delete $self->{changed};
	$self->{change_count} = 0;

	foreach my $x ( keys %{ $changed } ) {
	    foreach my $y ( keys %{ $changed->{$x} } ) {
		my $cell = $self->{grid}{$x}{$y};
		no warnings qw{ uninitialized };
		if ( $cell->[0] ) {
		    $self->{live}[ $changed->{$x}{$y} ]
			or $self->unset_point( $x, $y );
		} else {
		    $self->{breed}[ $changed->{$x}{$y} ]
			and $self->set_point( $x, $y );
		}
	    }
	}

	$self->{change_count}
	    or last;
    }
    return $self->{change_count};
}

sub set_point {
    my ( $self, $x, $y ) = @_;
    return $self->set_point_state( $x, $y, 1 );
}

sub set_point_state {
    my ( $self, $x, $y, $state ) = @_;

    defined $x
	and defined $y
	and $x =~ NON_NEGATIVE_INTEGER_RE
	and $y =~ NON_NEGATIVE_INTEGER_RE
	or croak 'Coordinates must be non-negative integers';
    defined $state
	or return $state;

    if ( $x >= 0 && $x < $self->{size_x} &&
	$y >= 0 && $y < $self->{size_y}
    ) {
	# We're on-grid.

	# This autovivifies, but we're going to assign it anyway, so ...
	my $prev_state = $self->{grid}{$x}{$y}[0] || 0;
	$state = TOGGLE_STATE_REF eq ref $state ? 1 - $prev_state :
	    $state ? 1 : 0;

	$self->{grid}{$x}{$y}[0] = $state;
	$self->{grid}{$x}{$y}[1] ||= 0;
	my $delta = $state - $prev_state
	    or return $state;
	$self->{living_x}[$x] += $delta;
	$self->{living_y}[$y] += $delta;

	$self->{change_count}++;

	foreach my $ix ( max( 0, $x - 1 ) .. min( $self->{max_x}, $x + 1 ) ) {
	    foreach my $iy ( max( 0, $y - 1 ) .. min( $self->{max_y}, $y + 1 )
	    ) {
		$self->{changed}{$ix}{$iy} =
		    $self->{grid}{$ix}{$iy}[1] += $delta;
	    }
	}

	# A cell is not its own neighbor, but the above nested loops
	# assumed that it was. We fix that here, rather than skip it
	# inside the loops.
	$self->{changed}{$x}{$y} =
	    $self->{grid}{$x}{$y}[1] -= $delta;

    } elsif ( $state ) {
	croak 'Attempt to place living cell outside grid';
    }

    return $state;
}

{
    my %dflt = (
	breed	=> DEFAULT_BREED,
	live	=> DEFAULT_LIVE,
    );

    sub get_rule {
	my ( $self, $kind ) = @_;
	$dflt{$kind}
	    or croak "'$kind' is not a valid rule kind";
	return( grep { $self->{$kind}[$_] } 0 .. $#{ $self->{$kind} } );
    }

    sub set_rule {
	my ( $self, $kind, $rule ) = @_;
	$dflt{$kind}
	    or croak "'$kind' is not a valid rule name";
	$rule ||= $dflt{$kind};
	ARRAY_REF eq ref $rule
	    or croak "\u$kind rule must be an array reference";
	$self->{$kind} = [];
	foreach ( @{ $rule } ) {
	    $_ =~ NON_NEGATIVE_INTEGER_RE
		or croak "\u$kind rule must be a reference to an array of non-negative integers";
	    $self->{$kind}[$_] = 1;
	}
	return;
    }
}

sub set_rules {
    my ( $self, $breed, $live ) = @_;
    $self->set_rule( breed => $breed );
    $self->set_rule( live => $live );
    return;
}

sub toggle_point {
    my ( $self, $x, $y ) = @_;
    return $self->set_point_state( $x, $y, TOGGLE_STATE );
}

sub unset_point {
    my ( $self, $x, $y ) = @_;
    return $self->set_point_state( $x, $y, 0 );
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

B<General note:> In all methods that specify C<$x>-C<$y> coordinates,
the C<$x> is the row number (zero-based) and the C<$y> is the column
number (also zero-based).

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
the given width and height). B<Note> that this means we specify number
of columns before number of rows, which is inconsistent with the
C<General note> above, but is consistent with L<Game::Life|Game::Life>.

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

=head2 clear

This method clears the grid, setting all cells to "dead." It returns its
invocant.

This method is an extension to L<Game::Life|Game::Life>.

=head2 get_active_grid_coord

 my $coord = $life->get_active_text_grid();

This method returns the coordinates of the bounding rectangle for all
active points in the grid -- that is, all whose value changed in the
most-recent iteration (if any) or whose values were manually changed
since the most-recent iteration. An exception is thrown if there are no
active points.

The return is a reference to an array containing the minimum and maximum
X coordinate followed by the minimum and maximum Y coordinate; that is:

 [ $min_x, $max_x, $min_y, $max_y ]

Note that these intervals are closed on both ends. To iterate over the
active rows you would specify C<$min_x .. $max_x>.

=head2 get_active_text_grid

 print $life->get_active_text_grid( $living, $dead )

This convenience method returns the result of

 $life->get_text_grid( $living, $dead,
     $life->get_active_grid_coord() )

The arguments are the character to represent an occupied cell and the
character to represent an empty cell.

=head2 get_breeding_rules

 use Data::Dumper;
 print Dumper( [ $self->get_breeding_rules() ] );

This method returns the breeding rule, as specified in the C<$breed>
argument to L<new()|/new>, but as an array rather than an array
reference.

B<Note> that this method always returns the data in ascending order. The
corresponding L<Game::Life|Game::Life> method returns them in the
originally-specified order.

=head2 get_grid

 my $grid = $life->get_grid( $coord )

This method returns the grid as a reference to an array of array
references. The argument is a reference to the minimum and maximum X and
Y coordinates:

 [ $min_x, $max_x, $min_y, $max_y ]

If the argument is omitted you get the entire grid.

=head2 get_grid_coord

 my $coord = $life->get_grid_coord();

This method returns the coordinates of the bounding rectangle for the
entire grid.

The return is a reference to an array containing the minimum and maximum
X coordinate followed by the minimum and maximum Y coordinate. Assuming
the size specified when the object was created was

 [ $size_x, $size_y ]

the return will be

 [ 0, $size_x - 1, 0, $size_y - 1 ]

=head2 get_living_rules

 use Data::Dumper;
 print Dumper( [ $self->get_living_rules() ] );

This method returns the living rule, as specified in the C<$breed>
argument to L<new()|/new>, but as an array rather than an array
reference.

B<Note> that this method always returns the data in ascending order. The
corresponding L<Game::Life|Game::Life> method returns them in the
originally-specified order.

=head2 get_rule

 use Data::Dumper;
 print "'$rule' rule is ", Dump( [ $life->get_rule( $rule ) ] );

This method returns the rule specified by the C<$rule> argument, which
must be either C<'breed'> or C<'live'>. B<Note> that in contrast to
L<set_rule()|/set_rule>, this method returns an array rather than an
array reference.

B<Note> that this method always returns the data in ascending order. The
corresponding L<Game::Life|Game::Life> method returns them in the
originally-specified order.

This method is an extension to L<Game::Life|Game::Life>.

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

=head2 get_used_grid_coord

 my $coord = $life->get_used_grid_coord()

This method returns the coordinates of the bounding rectangle for all
occupied points in the grid.

The return is a reference to an array containing the minimum and maximum
X coordinate followed by the minimum and maximum Y coordinate; that is:

 [ $min_x, $max_x, $min_y, $max_y ]

Note that these intervals are closed on both ends. To iterate over the
active rows you would specify C<$min_x .. $max_x>.

=head2 get_used_text_grid

 my ( $x, $y, $grid ) = $life->get_used_text_grid()
 print "${grid}at row $x column $y\n"

This convenience method returns the living portion of the grid as
text. Specifically, the returns are the number of the first row that
contains a living cell, the number of the column that contains the first
living cell, and the text grid with each line C<"\n">-terminated.

If there are no living cells, nothing is returned.

If called in scalar context you get the living portion of the grid.

=head2 get_used_grid

 use Data::Dumper;
 print Dumper( $life->get_used_grid() );

This method is similar to L<get_grid()|/get_grid>, but only returns
cells that have actually been assigned a value, or acquired a value in
the course of processing. Cells that have never had a value are
represented by C<undef>. Trailing C<undef>s in a row are suppressed.
Rows consisting only of unused cells are represented by C<undef>, not
C<[]>, and trailing C<undef> rows are also suppressed.

=head2 place_points

 $life->place_points( $x, $y, $array );

This method populates a portion of the grid whose top left corner is
specified by C<$x> and C<$y> with the state information found in
C<$array>. This is a reference to an array of array references.  Each
value of the inner array represents the state of the corresponding cell,
with a true value representing "living," and a false value representing
"dead."

As an incompatible change to the same-named method of
L<Game::Life|Game::Life>, points whose value is C<undef> are ignored.

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

The heavy lifting is done by L<set_point_state()|/set_point_state>.

=head2 process

 $life->process( $iterations );

This method runs the game for the specified number of iterations, which
defaults to C<1>.

As an incompatible change to the same-named method of
L<Game::Life|Game::Life>, the number of points that actually changed
state is returned. If C<$iterations> is greater than C<1>, the return
represents the last iteration. The corresponding
L<Game::Life|Game::Life> method does not have an explicit C<return>.

=head2 set_point

 $life->set_point( $x, $y );

This method sets the state of the point at position C<$x>, C<$y> of the
grid to "living." It returns a true value.

This method is a wrapper for L<set_point_state()|/set_point_state>.
Because of this, it is fatal to attempt to set a point outside the grid.

=head2 set_point_state

 $life->set_point_state( $x, $y, $state );

This method sets the state of the point at position C<$x>, C<$y> of the
grid to C<$state>. An C<undef> value is ignored; a true value of
C<$state> sets the cell "living;" a false value sets it "dead." It
returns the state.

An exception will be raised if you attempt to set a point "live" which
is outside the grid.

This method is an extension to L<Game::Life|Game::Life>.

=head2 set_rule

 $life->set_rule( $kind, $rule );

This method sets the C<breed> or C<live> rules, which govern the
transition from "dead" to "living" and "living" to "dead" respectively.
The arguments are:

=over

=item $kind

This argument specifies the kind of rule being set, and must be either
C<'breed'> or C<'live'>.

=item $rule

This argument specifies the actual rule. It must be either an array of
non-negative integers specifying the number of neighbors that must exist
to apply this rule, or a false value to specify the default.

The defaults depend on the value of C<$kind> as follows:

=over

=item breed => [ 3 ]

=item live => [ 2, 3 ]

=back

=back

This method is an extension to L<Game::Life|Game::Life>.

=head2 set_rules

 $life->set_rules( $breed, $live );

This method sets the C<breed> and C<live> rules from arguments C<$breed>
and C<$live> respectively. It is implemented in terms of
L<set_rule()|/set_rule>.

=head2 toggle_point

 $life->toggle_point( $x, $y );

This method toggles the state of the point at position C<$x>, C<$y> of
the grid. That is, if it was "dead" it becomes "living," and vice versa.
It returns the a true value if the cell became "living," and a false one
otherwise.

This method is a wrapper for L<set_point_state()|/set_point_state>.
Because of this, it is fatal to attempt to toggle a point outside the
grid.

=head2 unset_point

 $life->unset_point( $x, $y );

This method sets the state of the point at position C<$x>, C<$y> of the
grid to "dead." It returns a false value.

This method is a wrapper for L<set_point_state()|/set_point_state>.

=head1 SEE ALSO

L<Game::Life|Game::Life>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Game-Life-Faster>,
L<https://github.com/trwyant/perl-Game-Life-Faster/issues>, or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2019-2022 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
