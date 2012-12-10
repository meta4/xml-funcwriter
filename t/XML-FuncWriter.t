use warnings;
use strict;

use Test::More tests => 17;

BEGIN {
  use_ok( 'XML::FuncWriter',  qw( foo bar ) );
}

ok( __PACKAGE__->can( 'foo' ), 'import foo()' );
ok( __PACKAGE__->can( 'bar' ), 'import bar()' );

is( foo(), '<foo />', 'empty' );

is( foo( 'foo_arg1' ),
'<foo>
  foo_arg1
</foo>',
    'simple'
);

is( foo( 'foo_arg' )->( { indent => '', line_sep => '' } ),
    '<foo>foo_arg</foo>',
    'compact layout'
);

is( foo( { ID => 1, attr => 1 },
         bar( foo(), 'bar contents' ) ),
'<foo ID="1" attr="1">
  <bar>
    <foo />
    bar contents
  </bar>
</foo>',
    'nested'
);

is( foo( '&"\'<>' ),
'<foo>
  &amp;&quot;&apos;&lt;&gt;
</foo>',
    'entity references'
);

is( foo( bar( [ qw( one two ) ] ) ),
'<foo>
  <bar>
    one
  </bar>
  <bar>
    two
  </bar>
</foo>',
    'distributive property'
);

# addapted from the CGI.pm documentation
is( foo( bar( { type=>'disc' }, [ qw( Sneezy Doc Sleepy Happy ) ] ) ),
'<foo>
  <bar type="disc">
    Sneezy
  </bar>
  <bar type="disc">
    Doc
  </bar>
  <bar type="disc">
    Sleepy
  </bar>
  <bar type="disc">
    Happy
  </bar>
</foo>',
    'distributive property with attributes'
);

# create an anonymous function that does XML::FuncWriter stuff
my $baz = XML::FuncWriter::make_func( 'baz' );
like( ref( $baz ), qr(CODE), 'make function manually' );

is( $baz->(), '<baz />', 'empty element from anonymous function' );

# use anonymous function with installed functions
is( foo( $baz->( 'baz contents' ) ),
'<foo>
  <baz>
    baz contents
  </baz>
</foo>',
    'mix anonymous and installed'
);

# store intermediate XML and use it later
my $xml1 = foo( 'two' );
my $xml2 = bar( 'one', $xml1 );
my $xml3 = foo( $xml2, 'three', $xml2, 'three' );

is( $xml2,
'<bar>
  one
  <foo>
    two
  </foo>
</bar>',
    'intermediate element storage and first use'
);

is( $xml3,
'<foo>
  <bar>
    one
    <foo>
      two
    </foo>
  </bar>
  three
  <bar>
    one
    <foo>
      two
    </foo>
  </bar>
  three
</foo>',
    'intermediate element storage and reuse'
);

# create an anonymous function that does XML::FuncWriter stuff with different
# layout options
my $qux =
  XML::FuncWriter::make_func( 'qux', indent => '', line_sep => '' );

is( $qux->( 'qux args' ), '<qux>qux args</qux>',
    'compact layout from anonymous function' );

# use anonymous function with installed functions
is( foo( $qux->( 'qux contents' ) ),
'<foo>
  <qux>qux contents</qux>
</foo>',
    'mix anonymous and installed; normal layout and compact layout'
);
