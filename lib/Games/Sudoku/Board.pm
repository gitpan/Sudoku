package Games::Sudoku::Board;

use strict;
use warnings;

use Games::Sudoku::Cell;

our $VERSION = '0.03';

sub new {
    my $caller = shift;
    my $caller_is_obj = ref($caller);

    my $class = $caller_is_obj || $caller;

    my $self = {
	NAME => shift || 'Root ',
	DEBUG => shift || 0,
	PAUSE => shift || 0, 
	UNSOLVED => 81, 
	STEP => 0, 
	ERROR => [ ],
	MOVES => [ ],
	
    };

    foreach (my $i = 1; $i < 10; $i++) {
	foreach (my $j = 1; $j < 10; $j++) {
	    my $ik = int (($i-1)/3);
	    my $jk = int (($j-1)/3);
	    my $s = $ik *3 + $jk + 1; 
	    push @{$self->{BOARD}}, new Games::Sudoku::Cell($i, $j, $s);
	}
    }

    bless $self, $class;
}

sub initFromFile {
    my $self = shift;
    my $fname = shift;
    open FH, "$fname" or die "ERROR: $fname : $!\n";
    my $i = 1;
    while (<FH>) {
	chop;
	my @v = split //;
	for (my $j = 0; $j < @v; $j++) {
	    my $index = ($i-1) * 9 + $j ;
	    my $p = $self->{BOARD}[$index];
	    $p->value = $v[$j];
	}
	$i++;
    }

    close FH;
}

sub displayBoard {
    my $self = shift;
    
    print "***** ", $self->_name, " *** STEP ", $self->_step, " ************************************************************";
    foreach my $p (sort { 10*($a->row <=> $b->row) + ($a->col <=> $b->col) }@{$self->{BOARD}}) {
	if ($p->col == 1) {
	    print "\n";
	}
	print $p->value ? sprintf("%8d ", $p->value): sprintf("(%6s) ", @{$p->accept} == 9 ? '1 .. 9' : join('', @{$p->accept}));
    }
    print "\n************************************************************************************\n";
}

sub solve {
    my $self = shift;
    do {
	do {
	    $self->pause();
	    $self->displayBoard() if ($self->_findSimple() && $self->debug);
	    if ($self->_error) {
		if ($self->debug) {
		    print "WRONG BRANCH :",$self->_name(), "\n";
		}
		return -1;
	    }
	} while ($self->_updateBoard());
	
	$self->displayBoard() if ($self->_findMedium() && $self->debug);
    } while ($self->_unsolved  && $self->_updateBoard());

    if ($self->_unsolved) {
	my $branches = $self->_findHard();
	if ($self->debug) {
	    print "*** BRANCHES: \n";
	    foreach (@$branches) {
		print "@{$_} \n";
	    }
	}
	my $sb;

	foreach my $b (@$branches) {
	    $sb = $self->new(
			     $self->_name."Branch(@$b)",
			     $self->debug,
			     $self->pause
			     );
	    foreach my $c (@{$self->{BOARD}}) {
		my $index = ($c->row - 1) * 9 + $c->col - 1;
		$sb->{BOARD}->[$index]->value = $c->value;
		$sb->{BOARD}->[$index]->accept = $c->accept;
	    }
	    my $code;
	    push @$code, $b;
	    $sb->_moves = $code;
	    $sb->_updateBoard();
	    $sb->solve();
	    last if (! $sb->_unsolved);
	}
	# $sb contains the successfull branch;
	# update the parent board ...

	foreach my $c (@{$sb->{BOARD}}) {
	    my $index = ($c->row - 1) * 9 + $c->col - 1;
	    $self->{BOARD}->[$index]->value = $c->value;
	    $self->{BOARD}->[$index]->accept = $c->accept;
	}
	
    }
    return undef;
}

sub debug {
    my $self = shift;
    $self->{DEBUG} = shift if (@_);
    return $self->{DEBUG};
}

sub pause {
    my $self = shift;

    if (@_) {
	$self->{PAUSE} = shift;
    } else {
	if ($self->{PAUSE}) {
	    print " *** Press ENTER to continue ****\n";
	    my $enter = <STDIN>;
	}
    }
}

##### Internal Functions #####################################################

sub _unsolved :lvalue { $_[0]->{UNSOLVED}; }
sub _moves :lvalue {$_[0]->{MOVES};}
sub _error :lvalue {$_[0]->{ERROR};}
sub _step :lvalue {$_[0]->{STEP};}
sub _name :lvalue { $_[0]->{NAME} ;}

sub _findHard {
    my $self = shift;
    my $cell = (sort { @{$a->accept} <=> @{$b->accept} } grep {! $_->value} @{$self->{BOARD}})[0];
    my $branches;

    foreach my $v ( @{$cell->accept} ) {
	push @$branches, [ $cell->row, $cell->col, $v ];
    }

    return $branches;
}

sub _findMedium {
    my $self = shift;

    my $notfound = 0;
    my $code;
    my $error;

    for (my $row = 1; $row < 10; $row ++) {
	my %vals;
	my @cells =  grep{ ($_->value == 0) && ($_->row == $row) } @{$self->{BOARD}};

	foreach my $rv (@cells) {
	    foreach my $av (@{$rv->accept}) {
		push @{$vals{$av}}, [$rv->row, $rv->col, $av];
	    }
	}
	foreach my $key (keys %vals) {
	    if (scalar @{$vals{$key}} == 1) {
		push @$code, pop @{$vals{$key}};
	    }
	}
    }

    for (my $col = 1; $col < 10; $col ++) {
	my %vals;
	my @cells =  grep{ ($_->value == 0) && ($_->col == $col) } @{$self->{BOARD}};

	foreach my $rv (@cells) {
	    foreach my $av (@{$rv->accept}) {
		push @{$vals{$av}}, [$rv->row, $rv->col, $av];
	    }
	}

	foreach my $key (keys %vals) {
	    if (scalar @{$vals{$key}} == 1) {
		push @$code, pop @{$vals{$key}};
	    }
	}
    }

    for (my $quad = 1; $quad < 10; $quad ++) {
	my %vals;
	my @cells =  grep{ ($_->value == 0) && ($_->quad == $quad) } @{$self->{BOARD}};

	foreach my $rv (@cells) {
	    foreach my $av (@{$rv->accept}) {
		push @{$vals{$av}}, [$rv->row, $rv->col, $av];
	    }
	}

	foreach my $key (keys %vals) {
	    if (scalar @{$vals{$key}} == 1) {
		push @$code, pop @{$vals{$key}};
	    }
	}
    }

    $self->_moves = $code;
    return $code ? (scalar(@$code)) : 0;
}

sub _findSimple {
    my $self = shift;

    my $notfound = 0;
    my $code;
    my $error;
    $self->_step ++;

    foreach my $p (sort { 10*($a->row <=> $b->row) + ($a->col <=> $b->col) }@{$self->{BOARD}}) {
	next if ($p->value);
	$notfound ++;
	my %vals = ( qw(1 1 2 1 3 1 4 1 5 1 6 1 7 1 8 1 9 1) );

	my @rvals =  grep{ $_->row == $p->row } @{$self->{BOARD}};
	foreach my $rv (@rvals) {
	    $vals{ $rv->value } = 0;
	}

	my @cvals =  grep{ $_->col == $p->col } @{$self->{BOARD}};
	foreach my $cv (@cvals) {
	    $vals{ $cv->value } = 0;
	}

	my @qvals =  grep{ $_->quad == $p->quad } @{$self->{BOARD}};
	foreach my $rv (@qvals) {
	    $vals{ $rv->value } = 0;
	}

	my @vals = grep { $vals{$_} } sort keys (%vals);
	$p->accept = [ @vals ];
	if (my $num = @vals) {
	    if ($num == 1) {
		my $v = $vals[0];
		push @$code, [$p->row, $p->col, $v];
	    }
	} else {
# Must have gone somewhere wrong - there is a cell that does not have a value and cannot accept any values
	    push @$error, [$p->row, $p->col];
	}
    }
    $self->_unsolved = $notfound;
    $self->_moves = $code;
    $self->_error = $error;
    return $code ? (scalar(@$code)) : 0;
}

sub _updateBoard {
    my $self = shift;
    my $code = $self->_moves;

    return 0 unless ($code && @$code);
    if ($self->debug) {
	print "* Updating board:\n";
    }

    while (my $cc = shift (@$code)) {
	my ($i, $j, $v) = @$cc;
	print "SET ($i, $j) = $v\n" if ($self->debug);
	my $index = ($i-1) * 9 + $j - 1;
	my $p = $self->{BOARD}[$index];
	$p->value = $v;
    }    
    return 1;
}

1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Sudoku - Perl extension for solving Su Doku puzzles

=head1 SYNOPSIS

  use Games::Sudoku::Board;

  my $game = new Games::Sudoku::Board('Game 1', $debug, $pause);

  $game->initFromFile($fname);

  $game->displayBoard();

  $game->solve();

  $game->displayBoard();

=head1 DESCRIPTION

  This module solves Su Doku puzzles.
   
  The puzzle must be stored in a file of the following format :
nine lines of nine characters where unknown characters presented by zero, 
e.g 

000050380
035006090
000100000
704000001
006872000
000504600
059700800
107285000
000040700

  The code then might look like:

#!/usr/bin/perl

use strict;

use warnings;

use Games::Sudoku::Board;

use Getopt::Long;

my ($fname, $pause, $debug) = ('', 0, 0);

GetOptions('file=s' => \$fname,
          'pause' => \$pause,
          'debug' => \$debug);

my $game = new Games::Sudoku::Board;

$game->initFromFile($fname);

$game->debug($debug);

$game->pause($pause);

$game->displayBoard();

$game->solve();

$game->displayBoard();



=head1 TODO

- Add board init from a data structure

- Add error handling and invalid layout capture

- Add support for 16x16 boards



=head1 AUTHOR

    Eugene Kulesha, <kulesha@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Eugene Kulesha

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.



=cut
