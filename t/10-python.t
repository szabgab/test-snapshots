use strict;
use warnings;

use Test::More;
use Test::Snapshots;

my $python = 'python3';
my $python_version = `$python --version 2>&1`;
if (not defined $python_version or $python_version !~ /^Python/) {
    $python = 'python';
    $python_version = `$python --version 2>&1`;
}
#diag $python_version;

if (not defined $python_version or $python_version !~ /^Python/) {
	plan skip_all => 'Could not find python on this system';
}

Test::Snapshots::command($python);
Test::Snapshots::set_glob('*.py');
test_all_snapshots('eg/python');

