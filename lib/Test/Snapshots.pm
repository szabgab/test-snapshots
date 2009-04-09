package Test::Snapshots;
use strict;
use warnings;

use 5.008005;

our $VERSION = '0.01';

=head1 NAME

Test::Snapshots - for testing stand alone scripts and executables

=head1 SYNOPIS

 use Test::More;
 use Test::Snapshots;

 test_all_snapshots('eg');

Will go over all the .pl files in the eg/ directory, run them using
with the content of the SCRIPT.out and SCRIPT.err files


Optional configurations before calling test_all_snapshots:

 Test::Snapshots::debug(1);

Get some extra diag messages

 Test::Snapshots::combine(1);

Combines the stdout and stderr and compares them to the SCRIPT.out file


 Test::Snapshots::set_glob('*.t');

Change the way we locate the scripts to be executed.


 Test::Snapshots::set_accessories_dir('path/to/dir');

Change the place where TS looks for .out files.

=head1 WARNING

This is alpha software. The API will most certainly change as 
the requirements get clearer.

=head1 TODO

=over 4

=item *

Test this module.

=item *

Change the API to look more OO. Probably sg. like:

Test::Snapshots->set_glob()
    ->combine()
    ->set_accessories_dir()
    ->set_directories('eg')
    ->test_all_snapshots();

=item *

Deal with command line arguments. (.argv ?)

=item *

Deal with multiple test cases (multiple .out, .err, .in etc files for a single script)
.01.out  .02.out .02.err ?

=item *

Deal with single file asseccories: A single file that holds the contents of 
the .in , .our, .err etc... file in sections. 

E.g. the PHP core testing has .phpt files with sections:

 --TEST--
 Name of the test
 --FILE--
 The code that needs to be saved in a file and executed
 --EXPECT--
 The expected output

Test::Snapshots should be able to support that with the code
to be executed inside as in the case of php or being outside
as when testing executables.

=item *

Allow to pass several directories to traverse

=item *

Allow multiple runs in the same test script. (This will probably
mean the test counting needs to be done separately or we will have 
to use the new "add plan" feature of Test::More.

=item *

Set timeout for the executions so if one of them gets stuck 
(e.g. waiting on STDIN) the whole test suit won't suffer.

=item *

Allow definiton of expected exit code.

=item *

Use L<Capture::Tiny> ?

=back

=head1 DESCRIPTION

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
my $accessories_dir;
my $default_expected_exit = 0;

sub debug {
	$debug = shift;
}

=head2 combine

Set to 1 if you'd like to combine the STDOUT and STDERR and compare the
combined output to the .out file.

Default is 0 meaning they will be captured separatelly and compared 
separatelly to the .out and .err files.

=cut

sub combine {
	$combine = shift;
}

=head2 set_glob

Set what glob to use to fine the files to be executed. Currently it 
defaults to '*.pl' but maybe it should have no default forcing the user
to set one.

=cut

sub set_glob {
	$glob = shift;
}

=head2 skip

Pass to it a hash ref of     path => 'explanation' pairs
for all the files that need to be skipped.

  skip({
    path => 'good reason',
    path2 => 'some excuse',
  });

=cut

sub skip {
	$skip = shift;
}

=head2 set_accessories_dir

We are calling the .out, .err etc files accessories.
	
In some cases you don't want them to be next to the script that 
are being tested. In such cases you can use the above function 
to tell Test::Snapshots where those files can be found.

=cut

sub set_accessories_dir {
	$accessories_dir = shift;
}

=head2 command

By default Test::Snapshots will assume the files to be tested 
are stand alone executables or that at least they know where their
interpreter is. So they will be executed directly.

In most of the cases you will want to run them with some 
specific command. e.g. You might want to make sure they run with the
same perl interpreter as your test script runs. In that case call the following:

 command($^X)

In other cases the files need to be executed with some other tool, eg. 
the perl 6 or python interpreter which is in the path:

 command("perl6");

or

 command("python");

=cut

sub command {
	$command = shift;
}

=head2 test_all_snapshots

This is the call that actually goes out, locates all the
files to be tested, sets the C<plan> and executes all the test.
Currently one should give a directory as a paramter to it but 
I plan to move that parameter to a separate method and to allow
the setting of multiple directories.

=cut

sub test_all_snapshots {
	my ($dir) = @_;

	Carp::croak("Need to supply directory name") if not defined $dir;
	
	my @files = sort File::Find::Rule->file()->name($glob)->in($dir);
	my $prefix_length = length $dir;

	my $T = Test::Builder->new;
	
	my $cnt = $combine ? 1 : 2;
	$cnt++; # for exit codes
	$T->plan(tests => @files * $cnt );

	my $tempdir = tempdir( CLEANUP => 1 );
	foreach my $file (@files) {
		if ($skip->{$file}) {
			$T->skip($skip->{$file}) for 1..$cnt;
			next;
		}
		my $accessories_path = $accessories_dir ? $accessories_dir . substr($file, $prefix_length) : $file;
		#$T->diag($accessories_path);
		my $in_file = "$accessories_path.in";

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
		my $exit = $?;
		#$T->diag("Exit '$exit'");

		my @stds = $combine ? qw(out) : qw(err out);
		foreach my $ext (@stds) {
			my $expected = "$accessories_path.$ext";
			if (-e $expected) {
				my $diff = diff($expected, "$std{$ext}");
				$T->ok(!$diff, "$ext of $file") or $T->diag($diff);
			} else {
				my $data = _slurp($std{$ext});
				$T->ok($data eq '', "$ext of $file")
					or $T->diag("Expected nothing.\nReceived\n\n$data");
			}
		}
		# exit code
		{
			my $expected_exit = $default_expected_exit;
			my $expected_file = "$accessories_path.exit";
			if (-e $expected_file) {
				$expected_exit = _slurp($expected_file);
				chomp $expected_exit;
			}
			$T->is_eq($exit >> 8, $expected_exit, "Exit code of $file");
		}
	}
}

# a private slurp method.
sub _slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	return <$fh>;
}

=head1 See Also

L<Test::Simple>, L<Test::More> and L<Test::Most>.

L<Test::Output>, L<Capture::Tiny>, L<Test::Cmd>,

=head1 COPYRIGHT

Copyright 2009 Gabor Szabo gabor@szabgab.com http://szabgab.com/

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
