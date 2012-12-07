package XML::FuncWriter;

use strict;
use warnings;

our $VERSION = '0.01';

# use Data::Dump qw( pp );
# use feature qw( say );

sub import {
  my $pkg = shift;
  my $callpkg = caller( 0 );
#  say pp( @_ );

  if ( ref $_[0] eq 'ARRAY' ) {
    die "XML::FuncWriter : list of functions or list of configurations"
      unless @_ == 1;  # TODO: think through configuration options
    # Configure different function sets to do different things
    foreach my $fset ( @{$_[0]} ) { # for each function set
      die "XML::FuncWriter : list of configurations must be a list of hashes"
        unless ref($fset) eq 'HASH';
      my %cnfg = ( pre => '', post => '',
                   ( exists $fset->{cnfg} ) ? %{$fset->{cnfg}} : () );
      build_and_install_functions($callpkg, \%cnfg, @{$fset->{fncs}});
    }
  } else {
    # Configure all functions to do the same
    my %cnfg = ( pre => '', post => '',
                 ( ref $_[0] eq 'HASH' ) ? %{shift()} : () );
    build_and_install_functions($callpkg, \%cnfg, @_);
  }
}

sub build_and_install_functions{
  my $callpkg = shift;
  my %cnfg = %{shift()};
  foreach my $func ( @_ ) {
    no strict 'refs';
    *{"$callpkg\::$cnfg{pre}$func$cnfg{post}"} = make_func( $func, %cnfg );
  }
}

sub escape_ents {
  local $_ = shift;
  s/&/&amp;/g;
  s/</&lt;/g;
  s/>/&gt;/g;
  s/"/&quot;/g;
  s/'/&apos;/g;
  return $_;
}

sub stringify_attribs {
  return join '',
    map{
      ' '.escape_ents( $_ ).'="'.escape_ents( $_[0]{$_} ).'"'
    } sort keys %{$_[0]};
}

sub XML_elem {
  my $tag = shift;
  my $indent = shift;
  my @res; # return value

  my $attribs = shift @_ if( ref( $_[0] ) eq 'HASH' );
  my $open_tag = "<${tag}" . stringify_attribs( $attribs ) . ">";

  # handle an empty element
  $open_tag =~ s|>$| />| && return $open_tag if( @_ == 0 );

  my $close_tag = "</${tag}>";

  if( @_ == 1 && ref $_[0] eq 'ARRAY' ) {
    # Argument is an anonymous array.  Each element gets it's own pair of tags
    foreach my $arg ( @{ $_[0] } ) {
      push @res,
	$open_tag, recurse_if_code( $indent, $arg ), $close_tag;
    }
  } else {
    # Concatinate all arguments between 1 pair of tags.
    push @res,
      $open_tag, map( { recurse_if_code( $indent, $_ ) } @_ ), $close_tag;
  }
  return @res;
}

sub recurse_if_code{
  my $indent = shift;
  my $sub_item = shift;

  return map { $indent . $_ } $sub_item->( 'not root' )
    if( ref( $sub_item ) eq __PACKAGE__ );

  return $indent . escape_ents( $sub_item )
}

# Here there be magiks (nested closures, currying, overloaded
# operators, &c).  The outer closure curries the tag name, and tag
# configuration.  The second closure causes lazy evaluation of the
# subroutine XML_elem.  The second closure is blessed into the current
# package so operator overloading creates the XML string exactly when
# desired, and not a moment before.
sub make_func {
  my $tag = shift;
  my %cnfg = ( indent => '  ', line_sep => "\n", @_ );

  return sub {  # curry XML tag name - func takes tag contents
    my @contents = @_;
    return bless sub { # Lazy evaluation of XML_elem

      my %cnfg = (%cnfg, ( ref $_[0] eq 'HASH' ) ? %{shift()} : () );

      # create the XML elements
      my @res = XML_elem( $tag, $cnfg{indent}, @contents );

      # NOT Root Element - Don't concatinate elements.
      return @res if( $_[0] && $_[0] eq 'not root' );

      # Concatinate results.
      return join $cnfg{line_sep}, @res;
    }, __PACKAGE__;
  }
}

use overload
  '""'  => sub { $_[0]->() },
  'cmp' => sub { return $_[2] ? $_[1] cmp $_[0]->() : $_[0]->() cmp $_[1] };

1;

__END__

=head1 NAME

XML::FuncWriter - Write XML with functions

=head1 SYNOPSIS

  use XML::FuncWriter qw(person name address phone);

  print person(
      name('Snoopy' {IsHuman => 'False'}),
      address('32 Shultz Ave.'),
      phone('555-5555'),
  );

=cut
