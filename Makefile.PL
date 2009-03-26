use 5.008005;
use strict;
use inc::Module::Install 0.77;





#####################################################################
# Normal Boring Commands

# NOTE: Core modules that aren't dual-life should always have a version of 0

name           'Test-Snapshots';
license        'perl';
author         'Gabor Szabo';
all_from       'lib/Test/Snapshots.pm';
requires       'perl'                     => '5.008005';
requires       'Carp'                     => 0;
requires       'File::Basename'           => 0;
requires       'File::Find::Rule'         => '0.30';
requires       'File::Spec'               => '3.2701';
requires       'File::Spec::Functions'    => '3.2701';
requires       'FindBin'                  => 0;
test_requires  'Test::More'               => '0.47';

WriteAll;
