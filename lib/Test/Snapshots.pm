package Test::Snapshots;
use strict;
use warnings;

use 5.008005;

our $VERSION = '0.01';

# TODO deal with arguments
# TODO deal with multiple test cases

=head1 NAME

Test::Snapshots - for testing stand alone scripts and executables

=head1 SYNOPIS

 use Test::More;
 use Test::Snapshots;

 test_all_snapshots('eg');

Will go over all the .pl files in the eg/ directory, run them using
perl and compare the standar output and standard error for each SCRIPT
with the content of the SCRIPT.out and SCRIPT.err files


Optional configurations before calling test_all_snapshots:

 Test::Snapshots::debug(1);

Get some extra diag messages

 Test::Snapshots::combine(1);

Combines the stdout and stderr and compares them to the SCRIPT.out file


 Test::Snapshots::set_glob('*.t');

Change the way we locate the scripts to be executed.

=head1 WARNING

This is alpha software. The API will most certainly change as 
the requiremens clarify.

=cut

use Carp             ();
use File::Temp       qw(tempdir);
use Text::Diff       qw(diff);
use File::Find::Rule;

use base 'Test::Builder::Module';
use base 'Exporter';

our @EXPORT = qw(test_all_snapshots);

my $debug;
my $combine;
my $glob     = '*.pl';
my $command  = $^X;
my $skip     = {};

sub debug {
	$debug = shift;
}

sub combine {
	$combine = shift;
}
sub set_glob {
	$glob = shift;
}
sub skip {
	$skip = shift;
}
sub command {
	$command = shift;
}

sub test_all_snapshots {
	my ($dir) = @_;

	Carp::croak("Need to supply directory name") if not defined $dir;
	
	my @files = sort File::Find::Rule->file()->name($glob)->in($dir);

	my $T = Test::Builder->new;
	
	my $cnt = $combine ? 1 : 2;
	$T->plan(tests => @files * $cnt );

	my $tempdir = tempdir( CLEANUP => 1 );
	foreach my $file (@files) {
		if ($skip->{$file}) {
			$T->skip($skip->{$file}) for 1..$cnt;
			next;
		}
		my $in_file = "$file.in";

		my %std;
		$std{out} = "$tempdir/out";
		$std{err} = "$tempdir/err";

		my $cmd = "$command $file";
		if ($combine) {
			$cmd .= " >$std{out} 2>&1";
		} else {
			$cmd .= " >$std{out} 2>$std{err}";
		}
		if (-e $in_file) {
			$cmd .= " < $in_file";
		}
		if ($debug) {
			$T->diag($cmd);
		}
		#$T->diag($file);
		system $cmd;

		my @stds = $combine ? qw(out) : qw(err out);
		foreach my $ext (@stds) {
			my $expected = "$file.$ext";
			if (-e $expected) {
				my $diff = diff($expected, "$std{$ext}");
				$T->ok(!$diff, "$ext of $file") or $T->diag($diff);
			} else {
				my $data = slurp($std{$ext});
				$T->ok($data eq '', "$ext of $file")
					or $T->diag("Expected nothing.\nReceived\n\n$data");
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


=head1 COPYRIGHT

Copyright 2009 Gabor Szabo gabor@szabgab.com

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.


=cut


1;
