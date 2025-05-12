use inc::Module::Install;

name 'Data-Path';
perl_version '5.006';

abstract_from 'lib/Data/Path.pod';
author_from 'lib/Data/Path.pod';
license_from 'lib/Data/Path.pod';

version_from 'lib/Data/Path.pm';
perl_version_from 'lib/Data/Path.pm';

requires 'Carp'         => '0';
requires 'Scalar::Util' => '0';

build_requires 'Test::More'       => '0.7';
build_requires 'Test::Exception'  => '0';
build_requires 'Test::MockObject' => '1.08';

WriteAll;
