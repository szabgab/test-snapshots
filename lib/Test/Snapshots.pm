package Test::Snapshots;
use strict;
use warnings;

use 5.008005;

our $VERSION = '0.01';
use Carp ();

use base 'Test::Builder::Module';
use base 'Exporter';

our @EXPORT = qw(test_all_snapshots);

sub test_all_snapshots {
	my ($dir) = @_;

	Carp::croak("Need to supply directory name") if not defined $dir;
	my $Test = Test::Builder->new;
	$Test->plan(tests => 1);
	
	$Test->ok(1);

}


1;
