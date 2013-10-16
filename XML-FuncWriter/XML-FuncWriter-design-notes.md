# Easy XML production using Lazy Evaluation, Closures, Currying, operator overloading.

## Introduction

This document explains a perl package I created to write XML the way `CGI.pm` writes HTML using nested functions.  The functions in this package take a list of entity contents to enclose between XML tags.  They also take an optional hash reference specifying arbitrary XML attributes.  Some of the entity contents might be nested XML entities, which include their own tags, attributes, contents, sub-entities, etc.  The resulting nesting of XML elements should correspond directly to nested function calls in the code creating the XML fragment.

### Motivation

This article to explores lazy evaluation, closures, currying function arguments, with a splash of operator overloading for that last little bit of syntactic sugar.  If you don't know what these things are, or you have never seen a demonstration of how powerful they can be, especially when combined, you might find the following interesting.  

I am also looking for feedback.  I honestly have no idea whether this is genius or insanity or somewhere in between.

### Instructions

The code in this article can be run as you read.  If you create a perl file and paste the code into it as you read, the resulting perl program should execute at the end of each example.  The output from the example code is not included in this writeup to motivate you to run the examples.  It _might_ be useful to run the code in the debugger to see exactly how things happen, but, due to the recursive nature of the code, this may be more confusing than illuminating.  If you do use the debugger, watching the `$tag` variable should help keep track of where you are in the recursion.

Or, you can just read.  I'm not the boss of you.

On to the code!

## Code experiments

Before showing the final code that satisfies the requirements described above we'll walk through a few versions of the main functions.  Some of versions don't work for interesting reasons.  Some sort-of work.  But each version introduces a problem, a soulution and a design concept.

### Utility Functions

We start with the two standard perl sanity check pragmas, warnings and strict, and two utility functions.  the first function, `escape_ents`, (escape XML entities) converts characters not allowed in XML data into their XML representations.  The second function, `stringify_attribs`, converts a hash into XML attributes to be used inside a tag. There may be more robust ways to accomplish these things but this way is simple and it works.

     use warnings;
     use strict;

     sub escape_ents {
       local $_ = shift;
       s/&/&amp;/g;
       s/</&lt;/g;
       s/>/&gt;/g;
       s/"/&quot;/g; # "
       s/'/&apos;/g;
       return $_;
     }

     sub stringify_attribs {
       return join '',
         map{
           ' '.escape_ents( $_ ).'="'.escape_ents( $_[0]{$_} ).'"'
         } sort keys %{$_[0]};
     }

### The `XML_elem` function

This function generates XML.  It is used throughout the rest of this document so it's worth spending a few moments studying what it does and referring back to it as you read further.  It's not too complicated.

The first argument to `XML_elem` is the name of the XML element.  It is stored in the variable `$tag`.

The second argument is optional.  It's a hash reference.  If the second argument is a hash reference then that reference gets stored in `$atribs`.  Otherwise, `$attribs` is undefined.

The remaining arguments are pulled out of `@_` as they are processed.

The array `@result` stores the resulting XML fragments.

First put the opening XML tag into `@results`. Convert atributes, if there are any, to XML attributes using `stringify_attribs`, and insert them into the opening tag.

If there are no other arguments turn the opening XML tag into an empty element XML tag. Return it and exit.

If there *are* remaining arguments process them one by one in the foreach loop.

If an argument is a code ref (used to produce XML-sub-elements)  execute it, and store the results in `@results`.  If the argument is a string of plain text, escape any illegal characters with `escape_ents`, and store the result in the `@results` array.

Finally append the closing XML tag to the `@results` array and return the results to the caller.  `XML_elem` leaves it up to the caller to concatenate all the results together.

Pretty simple stuff.

    sub XML_elem {
      my $tag = shift;
      my $attribs = shift @_ if( ref( $_[0] ) eq 'HASH' );

      my @results; # return value

      push @results, "<${tag}" . stringify_attribs( $attribs ) . ">";

      if( @_ == 0 ) { # handle an empty element
        $results[0] =~ s|>$| />|;
        return @results;
      }

      foreach my $arg ( @_ ) {
        if( ref( $arg ) eq 'CODE' ) {
          push @results, map{ "  $_" } $arg->(); # <--- ???
        } else {
          push @results, '  ' . escape_ents( $arg )
        }
      }

      push @results, "<\\${tag}>";
      return @results;
    }

### First Attempt

This example, and all the examples in the first half of this writeup should produce three nested XML elements.  The outermost XML element should have the tag name "root".  Inside the "root" element is the "branch" element, and inside the "branch" element is the "sub-branch" element.  There are some attributes, text contents, and entities to be converted into their XML representation included to complete the example.

<a id="desired-result"></a>
Here is the result I'm trying to produce:

    <root ID="0">
      <branch>
        <sub_branch foo="2">
          some contents &amp; entities, &quot;&lt;&gt;&quot;
        </sub_branch>
        other contents
      </branch>
      root stuff
    </root>


<a id="first-attempt"></a>
The following code fragment tries to use `XML_elem` to produce the XML example.  By nesting call to `XML_elem`, it tries to produce nested XML elements.

    print join "\n",
      XML_elem( 'root', { ID => 0 },
        XML_elem( 'branch',
          XML_elem( 'sub_branch', { foo => 2 },
            'some contents & entities, "<>"'
          ),
          'other contents',
        ),
      'root stuff',
      );

Do you see what went wrong?  Run the code to see what happens. (Or just read on.)

## The First Results

The source of the problem is complicated.  It may take a serious effort to understand the explanation of the problem.  Fundamentaly, the problem has to do with the way functions are called in perl, and most programming languages.

### The Problem

Perl evaluates the nested `XML_elem` functions from the inside out.  The innermost `XML_elem` function (the `'sub_branch'` call) is evaluated first, before the `'branch'` call to `XML_elem`.  When the `'branch'` `XML_elem` function is called it gets is the `@results` array from the `'sub_branch'` `XML_elem` function call.  At this point the contents of the `@results` array are all strings.  Some of these strings are XML tags and some are just the XML contens.  These XML tags and entities are escaped by `escape_ents` as they are interpolated into the `'branch'` element.  Then the contents of `@results` produced by the `'branch'` call to `XML_elem` are escaped again when they are interpolated in the `'root'` call to `XML_elem`. The result is a big mess.  It *is* actually valid XML, but not the XML we want.

None of the arguments to the `'branch'` and `'root'` calls to `XML_elem` are function references, so the line marked by `# <--- ???`  in `XML_elem` never executes.  `XML_elem`  identifies an argument is an XML-sub-element if the argument is a code reference.  If it is a code reference `XML_elem` does not escape any entities produced by that argument.  The sub-element's call to `XML_elem` is responsible for escaping the entities in the sub-element.  In our first attempt the enclosing calls to `XML_elem` can't distinguish between the XML tags and the XML content strings.

There is a certain element of "Doctor, it hurts when I do this" to this problem.  So, it is tempting to respond, "Well, don't do that!".  The way Perl evaluates arguments to functions (eager evaluation) is fundamental to the way Perl works.  Lazy evaluation is a un-natural thing to do.  But, in this document, I'm  presenting lazy evaluation as a tool to solve a complicated library interface problem.  It is a strange concept, and using it everywhere is not appropriate, at least in Perl.  But, there are places where it might be useful.

Note: In the first line of the code in the first attempt, the list of results from `XML_elem` are joined together separated newlines before the results are printed.  Remember, `XML_elem` returns an array so we can, in theory, nest XML elements created in one part of a program inside XML generated in another part of the program.  (It doesn't work at this point but it will soon) The code fragments in this document create the XML fragment all in one statement, but, by the end, we will be able to distribute the creation of the XML elements to wherever it is most convenient.

### Lazy Evaluation

What we need to do is prevent the nested `XML_elem` functions from being evaluated until inside the calling function.  This is Lazy Evaluation. Perl can delay the evaluation of a function by passing a code reference as an argument and calling the function through the code reference inside the function, instead of calling the function in the argument list.

This solves one problem but creates another.  If we pass a function reference, how do we pass arguments to the function when it is called via the reference deep inside nested calls to `XML_elem`?  The solution to this new problems is to use a closure to bind the subroutine reference and the arguments together into a function that can be called with no arguments.

### The First Closure

This simple subroutine, called `ml` for make lazy, solves our problem.  Each time it is called it packages the subroutine reference in the variable `$theFunc` and all the remaining arguments in the array `@args`, and returns a reference to an anonymous subroutine.  When the anonymous subroutine is called it simply returns the result of calling the function, via the reference stored in `$theFunc`, using the arguments stored in `@args`.  Using this function we  delay the execution of `XML_elem` until the anonymous function that `ml` returns is executed.

Since `ml` declares `$theFunc` and `@args` as lexical variables with `my`, new sets are created each time `ml` is called.  Additionally, as long as we keep a reference to each subroutine that `ml` returns, each pair of `$theFunc` and `@args` variables are kept.  Perl keeps distinct copies of `$theFunc` and `@args` together inside each anonymous subroutine so the pointer to the subroutine implicitly contains the proper `$theFunc`, and `@args` variables.  This is the magic of closures used to produce lazy evaluation.

    # ml (Make Lazy) takes a reference to a subroutine as it's 1st arg.  All
    # remaining args are saved and used as arguments for the subroutine when
    # the results of execution are desired.  returns a subroutine that behaves
    # almost exactly as if the subroutine had been called when ml was called.
    sub ml {
      my $theFunc = shift;
      my @args = @_;
      return sub {
        return $theFunc->( @args );
      };
    }

### Second Attempt

<a id="second-attempt"></a>
This code fragment demonstrates `ml` in action.  Notice how all the arguments, in the nested function calls, that were passed to `XML_elem` in the [first attempt](#first-attempt) are now passed to `ml` preceded by a reference to the `XML_elem` function.

    print join "\n",
      XML_elem( 'root', { ID => 0 },
        ml( \&XML_elem, 'branch',
          ml( \&XML_elem, 'sub_branch', { foo => 2 },
            'some contents & entities, "<>"'
          ),
          'other contents',
        ),
      'root stuff',
      );

### Currying Arguments Part 1

This works!!!  It produces the [desired result](#desired-result), but the function arguments are cluttered.  Some nesting of function calls is desired to indicate which XML elements are nested inside each other.  But the amount of nesting in the [second attempt](#second-attempt) is clumsy, and excessive.  If we wanted to have multiple `'branch'` elements we would have to use `\$XML_elem` and `'branch'` as arguments to ml for each element.  It would be nice to specify the tag in one place and have something that we could use and re-use to create the desired XML.

So, lets change how we call `ml`.  The [second attempt](#second-attempt) crams too many arguments of different kinds into `ml`.  The first argument is a reference to a subroutine.  The second argument is name of the XML tag.  The remaining arguments are the contents of the XML element including an optional attribute hash and all the sub-elements.  These are all mashed together in one argument list.  You have to count arguments for each function to determine what is what.  And, you have to re-declare all the arguments when you want to re-use a tag.

This argument mashing may seem normal, however, it is possible to break argument lists apart.  To specify the subroutine reference and the XML tag name in one place, and the XML element contents and attributes somewhere else.  This is called currying arguments (named after the logician Haskell Curry).

To curry the arguments to `ml` we call one function with a reference to the `XML_elem` subroutine and the tag name in one place, then, somewhere else supply the remaining XML entity contents.

Currying arguments requires keeping track of which functions should be called with which arguments, and what remaining arguments are needed.  What happens is, when the first arguments are supplied the function returns a reference to an anonymous function that takes the remaining arguments.  In the code fragment below the anonymous function pointers are stored in variables whose names are the names of the XML tags.  This makes it easy to track which arguments go with which functions.

Some languages implement currying automatically.  If you don't supply enough arguments to a function it curries those arguments and returns an anonymous function where you supply the rest of the arguments.  With Perl you have to be a little more explicit.  Fortunately, Perl can implement currying using closures.  The closure we need simply stores the first two arguments to `ml` in lexical variables, and returns a subroutine which takes the remaining arguments and then calls `ml`.
<a id="third-attempt"></a>

    # ca4ml (Curry Arguments for ML)
    sub ca4ml {
      my $theFunc = shift;
      my $tag = shift;
      return sub {
        my @args = @_;
        return ml( $theFunc, $tag, @args );
      }
    }

    my $root       = ca4ml( \&XML_elem, 'root' );
    my $branch     = ca4ml( \&XML_elem, 'branch' );
    my $sub_branch = ca4ml( \&XML_elem, 'sub_branch' );

    print join "\n",
      $root->( { ID => 0 },
        $branch->(
          $sub_branch->( { foo => 2 },
          	 'some contents & entities "<>"'
          ),
          'other contents',
        ),
        'root stuff',
      )->();

## Currying Results

This third attempt looks much nicer than the [second attempt](#second-attempt).  It is easier to see the XML tag, attribute and content nesting.  The code which produces the XML mimics the XML layout almost exactly.  This example doesn't, but we could, use the function in `$branch` to create multiple `'branch'` entities.

This examle does have one really subtle part, the final anonymous function call indicated by the ")->()" in the last line of the code.  Remember, `ml` returns an anonymous function.  If we don't execute the outermost anonymous function no XML is produced.  In fact, `XML_elem` is not called until that anonymous subroutine is executed.  Up to that point all we've done is assemble a hierarchy of anonymous functions and argument lists which contain more anonymous functions. We must execute the outermost anonymous function to actually produce the XML.  The lazy evaluation is lazy.  It doesn't actually do any of the work we want until we force it too.

One other issue with this implementation can be improved.  Notice that the first argument to ca4ml is always a reference to the subroutine `XML_elem`.  It always will be.  If we know what an argument will be we don't need to pass it as an argument.

This example shows this change in action.  I changed the name from `ca4ml` to `make_func`.  The anonymous functions `make_func` returns are the only interface to this XML writing technique.

    sub make_func {
      my $tag = shift;
      return sub {
        my @args = @_;
        return ml( \&XML_elem, $tag, @args );
      }
    }

    $root       = make_func( 'root' );
    $branch     = make_func( 'branch' );
    $sub_branch = make_func( 'sub_branch' );

    print join "\n",
      $root->( { ID => 0 },
        $branch->(
          $sub_branch->( { foo => 2 },
    	 'some contents & entities "<>"'
          ),
          'other contents',
        ),
        'root stuff',
      )->();

Now, come on! You have to admit, that's pretty cool.  

This scheme can use the function in `$branch` in multiple places.  You can create create different parts of an XML document in different functions and combine the resulting parts into one final XML document that is created when output.

For example to create a simple HTML page containing a table.
<a id="HTML-table-example"></a>

    my $body  = make_func( 'body' );
    my $h1    = make_func( 'h1' );
    my $table = make_func( 'table' );
    my $tr    = make_func( 'tr' );
    my $td    = make_func( 'td' );

    sub make_table_row {
      my $i = shift;
      return $tr->(
        $td->( $i ),
        $td->( $i * 10 + $i )
      );
    }

    sub make_table{
      return $table->(
        $tr->(
          { BGCOLOR => 'blue',
            ID      => 'tbl1' },
          $td->('X'), $td->('X * 10 + X')),
        map{ make_table_row( $_ ) } (0..5)
      );
    }

    sub make_body{
      return $body->(
        $h1->('My realy cool table'),
        make_table(),
        "isn't that a cool table?"
      );
    }

    print join "\n", make_body()->();

This is cool but, I think it can be cooler.

### The Story So Far ...

In the introduction I said I was looking for a package which wrote XML using this nested function paradigm.  What we have so far is not a package but it can easily be turned into a package with a rather novel interface.  The title mentions overloaded operators; I haven't overloaded any operators yet.  You need to have a package to overload operators.

## Starting Over

At this point we are going to create the package described in the introduction.  The following code fragments augment/replace the code fragments listed above, so you can't just copy them into the same perl file without producing errors.  Either start a new file or open the func_writer.pl file, and follow along.

### Introduction to XML::FuncWriter

The interface for this module is rather novel in that the user specifies the functions he/she wants in the `use` statement, and this library creates the desired functions at compile time and installs them in the calling packages namespace.  The functions the user wants don't exist until the user asks for them!

Also, there were two issues in the previous implementation that are fixed here.

The first improvement removes the dangling function call that cause all the lazy evaluation to occur.  It is to easy to forget the "->()" at the end, and end up with "CODE(0x1b41244)" in your output where you expected XML.  It also removes the need to join all returned `@result` elements together to produce a single output string as the result.

The second improvement is the addition of what is called the distributive property in the documentation for the `CGI.pm` module in the perl core.  Here is a portion of the documentation from `CGI.pm`

    One of the cool features of the HTML shortcuts is that they are
    distributive. If you give them an argument consisting of a reference to a
    list, the tag will be distributed across each element of the list. For
    example, here's one way to make an ordered list:
       print ul(
                 li({-type=>'disc'},['Sneezy','Doc','Sleepy','Happy'])
               );
    This example will result in HTML output that looks like this:
       <ul>
         <li type="disc">Sneezy</li>
         <li type="disc">Doc</li>
         <li type="disc">Sleepy</li>
         <li type="disc">Happy</li>
       </ul>

This library lets you do the same thing with any XML tag you want.

There are other changes and some refactoring which I will describe below.  The first is, of course, the addition of the package declaration.

    package XML::FuncWriter;

    use warnings;
    use strict;

    sub escape_ents {
      local $_ = shift;
      s/&/&amp;/g;
      s/</&lt;/g;
      s/>/&gt;/g;
      s/"/&quot;/g; # "
      s/'/&apos;/g;
      return $_;
    }

    sub stringify_attribs {
      return join '',
        map{
          ' '.escape_ents( $_ ).'="'.escape_ents( $_[0]{$_} ).'"'
        } sort keys %{$_[0]};
    }

Apart from the package declaration these functions are exactly the same as above.

To generate functions on-the-fly requires a custom `import` function instead of using the perl `exporter` module.  However the `import` function is not that complicated.

    sub import {
      my $pkg = shift;
      my $callpkg = caller( 0 );

      foreach my $func ( @_ ) {
        no strict 'refs';
        *{"$callpkg\::$func"} = make_func( $func );
      }
    }

`XML_elem` also requires a change to implement the Distributive Property for XML tags.

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
        # Argument is an anonymous array. (distributive property)
        # Each element gets it's own pair of tags
        foreach my $arg ( @{ $_[0] } ) {
          push @res,
            $open_tag, recurse_if_code( $indent, $arg ), $close_tag;
        }
      } else {
        # Concatenate all arguments between 1 pair of tags.
        push @res,
          $open_tag, map( { recurse_if_code( $indent, $_ ) } @_ ), $close_tag;
      }
      return @res;
    }

`XML_elem` implements the recursion and the distributive property.  So, I re-factored the recursion into the function `recurse_if_code`.  The `'not root'` argument is explained below.

    sub recurse_if_code{
      my $indent = shift;
      my $arg = shift;

      return map { $indent . $_ } $arg->( 'not root' )
        if( ref( $arg ) eq __PACKAGE__ );

      return $indent . escape_ents( $arg )
    }

I moved the functionality of the `ml` (make lazy) function into `make_func` since that was the only place it was called.  This makes `make_func` a bit more complicated, but it consolidates all the wizard stuff in one function (except the operator overloading stuff, which we'll get to in a minute). 

Since this library handles concatenating the results of `XML_elem` into one string when desired it also allows the user to specify how they would like the indentation handled in the resulting XML.  This is handled by allowing the user to specify two named arguments in an anonymous hash to the final anonymous function to produce the XML string.  The argument specified by `indent` is prepended to each line once for each level of element nesting. Unless the user is doing something weird `indent` should just be a string of white space.  The default is two spaces.  The argument specified by `line_sep` is used to join all the XML elements together.

    # The outer closure curries one argument, the tag name, The second closure
    # causes lazy evaluation of the subroutine XML_elem. It also curries
    # information for formating the resulting XML fragment.  The second closure is
    # blessed into the current package so the XML string gets written when the
    # user wants it.

    sub make_func {
      my $tag = shift;
      return sub {  # curry XML tag name
        my @args = @_;
        return bless sub { # Lazy evaluation of XML_elem

          my %format_info = ( indent => '  ', line_sep => "\n" );

          %format_info = ( %format_info, %{shift( @_ )} )
    	    if( defined $_[0] && ref $_[0] eq 'HASH' );

          # create all the XML elements
          my @res = XML_elem( $tag, $format_info{indent}, @args );

          # NOT Root Element - Don't concatenate elements.
          return @res if( $_[0] && $_[0] eq 'not root' );

          # Root Element - Concatenate results.
          return join $format_info{line_sep}, @res;
        }, __PACKAGE__;
      }
    }

`make_func` blesses the anonymous function, turning it into a `XML::FuncWriter` object.  (Yes, an anonymous function can be an object in Perl.) This allows us to use operator overloading.  Operator overloading requires one of the operands be an object with the operator overloaded.

"Why do we want to use operator overloading?", you ask.  "Isn't the interface to this library is a bunch of anonymous functions that are created as needed?"

Yes.  That's the problem.  After we build up this structure of anonymous functions what we *get* is an anonymous function representing the root object of the XML.  What we *want* is a string containing the XML produced by calling that function.  In the examples in the code experiments we manually called the anonymous function with the ugly, dangling `)->()`.

Until we want to print it out, or otherwise deliver XML to the world, we would like to keep our XML as an anonymous function.  As long as it remains an anonymous function we can use it in one or more other calls to other XML generating functions.  You can use the same fragment of XML in multiple places in a larger XML fragment, or in multiple other XML fragments.  But, the moment you print it or concatenate it with another string it should magically convert that anonymous function into the desired XML string.

We want to override the stringification operator.

    use overload
      '""'  => sub { $_[0]->() },
      'cmp' => sub { return $_[2] ? $_[1] cmp $_[0]->() : $_[0]->() cmp $_[1] };

We also want to test the module with `Test::more` so we need to overload the cmp operator.  (This was an interesting case of testing uncovering a bug of omission.)

## Wrap up

Now we can create the [HTML table example](#HTML-table-example) using the function oriented interface.

In a new file:

    use warnings;
    use strict;
    use XML::FuncWriter qw(Body H1 Table Tr Td);  # beware! builtin tr overwrites your tr

    sub make_table_row {
      my $i = shift;
      return Tr( Td( [$i, $i * 10 + $i] ) );
    }

    sub make_table{
      return Table(
        Tr(
          { BGCOLOR => 'blue',
            ID      => 'tbl1' },
          Td('X'), Td('X * 10 + X')),
        map{ make_table_row( $_ ) } (0..5)
      );
    }

    sub make_body{
      return Body(
        H1('My realy cool table'),
        make_table(),
        "isn't that a cool table?"
      );
    }

    print make_body();

And that is it!