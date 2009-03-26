package Test::Snapshots;
use strict;
use warnings;

use 5.008005;

our $VERSION = '0.01';

use Carp             ();
use File::Temp       qw(tempdir);
use Text::Diff       qw(diff);
use File::Find::Rule;

use base 'Test::Builder::Module';
use base 'Exporter';

our @EXPORT = qw(test_all_snapshots);

sub test_all_snapshots {
	my ($dir) = @_;

	Carp::croak("Need to supply directory name") if not defined $dir;
	
	my @files = File::Find::Rule->file()->name('*.pl')->in($dir);

	my $T = Test::Builder->new;
	$T->plan(tests => @files * 2);

	my $tempdir = tempdir( CLEANUP => 1 );
	foreach my $file (@files) {
		my $in_file = "$file.in";

		my %std;
		$std{out} = "$tempdir/out";
		$std{err} = "$tempdir/err";

		my $cmd = "$^X $file >$std{out} 2>$std{err}";
		if (-e $in_file) {
			$cmd .= " < $in_file";
		}
		$T->diag($cmd);
		#$T->diag($file);
		system $cmd;

		my @stds = qw(out err);
		foreach my $ext (@stds) {
			my $expected = "$file.$ext";
			if (-e $expected) {
				my $diff = diff "$std{$ext}", $expected;
				$T->ok(!$diff, "$ext of $file") or $T->diag($diff);
			} else {
				my $data = slurp($std{$ext});
				my $empty = '';
				my $diff = diff(\$empty, \$data);
				$T->ok(!$diff, "$ext of $file") or $T->diag($diff);
			}
		}
	}
}

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}


1;
