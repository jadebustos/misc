package PersonalPerlLibrary::Array;

use strict;
use Exporter;
use vars qw($VERSION @EXPORT @ISA);

@ISA = ('Exporter');
@EXPORT = qw (&search_pattern);
$VERSION='0.01';

###########################################
# Funcion que busca un patron en un array #
###########################################

sub search_pattern { # BEGIN search_pattern

	my ($pattern, $array) = @_;

	foreach my $item (@$array) { # BEGIN foreach
		if ( $item =~ /$pattern/ ) { # BEGIN if
			return 1;
		} # END if
	} # END foreach

	return 0;
} # END search_pattern

1;
