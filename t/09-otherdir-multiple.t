use strict;
use warnings;

use Test::More;
use Test::Snapshots;

Test::Snapshots::multiple(1);
Test::Snapshots::set_accessories_dir('eg/multiple_accessories');
test_all_snapshots('eg/multiple_code');

