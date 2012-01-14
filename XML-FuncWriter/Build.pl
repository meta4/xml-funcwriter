use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'XML::FuncWriter',
    license           => 'perl',
    dist_author       => 'Peter Wilson <peter.t.wilsn@gmail.net>',
    dist_version_from => 'lib/XML/FuncWriter.pm',
    dist_abstract     => 'A function interface to XML writing',
    license           => 'perl',
    build_requires => {
        'Test::More' => 0,
    },
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
