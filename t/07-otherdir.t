use strict;
use warnings;

use Test::More;
use Test::Snapshots;

#Test::Snapshots::combine(1);
Test::Snapshots::set_accessories_dir('eg/otherdir_accessories/');
test_all_snapshots('eg/otherdir_code');

