use warnings;
use strict;

# ---------------------------------------------------------------------------
package phone_book;

use XML::FuncWriter 'phone_book';

sub new {
  my $pkg = shift;
  return bless [], $pkg;
}

sub add {
  my $self = shift;
  push @$self, phone_book::entry->new( @_ )
}

# <!-- phone_book member functions here  -->

sub serialize{
  my $self = shift;
  return phone_book( {fmt_ver => 0.2},
                     map{ $_->serialize() } @$self );
}

# ---------------------------------------------------------------------------
package phone_book::entry;

use XML::FuncWriter(
  [
    {
      fncs => [ qw( name number street city zip ) ],
      cnfg => {
        pre => "X_",    # prefix the function name with 'X_'
        line_sep => "", # No newline between tags & elements
        indent=>"",     # No indenting spaces
      },
    },
    {
      fncs => [ qw( entry ) ],  # default config for <entry> tags & elements
    },
  ]
);

sub new {
  my $pkg = shift;
  my %self;
  @self{ qw( name number street city zip ) } = @_;
  return bless \%self, $pkg;
}

# <!-- phone_book_entry member functions here  -->

sub serialize {
  my $self = shift;

  return
    entry(
      X_name(   $self->{name} ),
      X_number( $self->{number} ),
      X_street( $self->{street} ),
      X_city(   $self->{city} ),
      X_zip(    $self->{zip} ),
    );
}

# ---------------------------------------------------------------------------
package main;
use Test::More tests => 1;

my $book = phone_book->new();
$book->add(
  'snoopy', '555-6666', '15 mocking bird lane', 'somewhere', '12345'
);

$book->add(
  'Charle Brown', '777-8888', '15 mocking bird lane', 'somewhere', '12345'
);

$book->add(
  'Lucy VanPelt', '222-3333', '32 Shultz Ave', 'somewhere', '12345'
);

# print $book->serialize();

is( $book->serialize(),
'<phone_book fmt_ver="0.2">
  <entry>
    <name>snoopy</name>
    <number>555-6666</number>
    <street>15 mocking bird lane</street>
    <city>somewhere</city>
    <zip>12345</zip>
  </entry>
  <entry>
    <name>Charle Brown</name>
    <number>777-8888</number>
    <street>15 mocking bird lane</street>
    <city>somewhere</city>
    <zip>12345</zip>
  </entry>
  <entry>
    <name>Lucy VanPelt</name>
    <number>222-3333</number>
    <street>32 Shultz Ave</street>
    <city>somewhere</city>
    <zip>12345</zip>
  </entry>
</phone_book>',
     "Phone Book Example" );

