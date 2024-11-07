module AST { }

class AST::Rule is repr('Uninstantiable') { }

class AST::Rule::Positive is AST::Rule {
    has Str $.key;
}

class AST::Rule::Negative is AST::Rule {
    has Str $.key;
}

class AST::Rule::Nested is AST::Rule {
    has Str $.key;
    has $.pattern; # AST::Pattern:D TODO type it when Comma recognizes stub
}

class AST::Pattern {
    has AST::Rule:D @.rules;

    method positives { @!rules.grep(AST::Rule::Positive) }
    method negatives { @!rules.grep(AST::Rule::Negative) }
    method nesteds { @!rules.grep(AST::Rule::Nested) }
}

class X::ParseFail is Exception {
    has Str $.reason is required;
    has Cursor $.cursor is required;

    method message() {
        "JSON Mask parse failed: $!reason at line $.line near '$.near'"
    }

    method line() {
        $!cursor.orig.substr(0, $!cursor.pos).split(/\n/).elems
    }

    method near() {
        $!cursor.orig.substr($!cursor.pos, 40)
    }
}

grammar Mask {
    token TOP {
        :my @*stack;
        <pattern>
    }

    token pattern {
        :my $*has-seen-positive = False;
        :my $*has-seen-negative = False;
        :my @*seen-keys;
        <rule>+ %% ','
    }

    proto token rule { * }

    token rule:positive {
        <key> {}
        [ '()' <.panic: "Invalid empty nested rule">
        || '(' ~ ')' [ :temp @*stack; { push @*stack, $<key>.made } <pattern> ]
        || <?{ $*has-seen-negative }> <.panic: "Cannot have a positive rule after a negative rule">
        || { $*has-seen-positive = True; } ]
        { self.check-seen($<key>.made) }
    }

    token rule:negative {
        '-' <key>
        [ <?{ $*has-seen-positive }> <.panic: "Cannot have a negative rule after a positive rule">
        || { $*has-seen-negative = True; } ]
        { self.check-seen($<key>.made) }
        [ <?before '('> <.panic: "Cannot have a nested negative group"> ]?
    }

    method check-seen(Str $key) {
        if $key (elem) @*seen-keys {
            self.panic("Key $key already present");
        }
        @*seen-keys.push: $key;
    }

    proto token key { * }
    token key:simple { \w+ }
    token key:quoted { '"' ~ '"' (<-["]>+) } # TODO escapes

    method panic($reason is copy) {
        $reason ~= ' in ' ~ @*stack.join('.') if @*stack;
        die X::ParseFail.new(reason => $reason ~ (' in ' ~ @*stack.join('.') if @*stack),
                             :cursor(self));
    }
}

class MaskActions {
    method TOP($/) {
        make $<pattern>.made
    }

    method pattern($/) {
        make AST::Pattern.new(rules => $<rule>>>.made)
    }

    method rule:positive ($/) {
        if $<pattern> {
            make AST::Rule::Nested.new(key => $<key>.made, pattern => $<pattern>.made)
        } else {
            make AST::Rule::Positive.new(key => $<key>.made)
        }
    }

    method rule:negative ($/) {
        make AST::Rule::Negative.new(key => $<key>.made)
    }

    method key:simple ($/) { make ~$/ }
    method key:quoted ($/) { make ~$0 }
}

multi sub evaluate(AST::Pattern $pattern, @data) {
    # Pair code commented out as this format isn't JSON-like. Might be revisited.
    #return evaluate($pattern, %@data) if all(@data) ~~ Pair;
    @data.map({ evaluate($pattern, $_) }).List;
}

multi sub evaluate(AST::Pattern $pattern, %data) {
    my %scooped;
    if $pattern.negatives -> @negatives {
        %scooped = %data{keys %data.keys (-) @negatives.map(*.key)}:kv;
    } elsif $pattern.positives -> @positives {
        %scooped = %data{@positives.map(*.key)}:kv;
    }

    for $pattern.nesteds -> AST::Rule::Nested $nested {
        with %data{$nested.key} -> \value {
            @*stack.push: $nested.key;
            unless value ~~ Positional | Associative {
                die "Nested value for $(@*stack.join: '.') doesn't have the right shape under"
            }
            %scooped{$nested.key} = evaluate($nested.pattern, value)
        }
    }

    %scooped
}

sub compile-mask(Str $mask) is export {
    Mask.parse($mask, :actions(MaskActions.new))
}

multi sub mask(Mask $pattern, \data) is export {
    my @*stack;
    evaluate($pattern.made, data)
}

multi sub mask($mask, \data) is export {
    with compile-mask($mask) {
        mask($_, data);
    } else {
        die "Unable to parse JSON Mask";
    }
}

=begin pod

=head1 NAME

JSON::Mask - JSON filtering

=head1 SYNOPSIS

=begin code :lang<raku>

use JSON::Mask;

# Select keys "a", "b", and "c".
mask('a,b,c', %data);

my $mask = compile-mask('a,b,c');
mask($mask, %data1);

=end code

=head1 DESCRIPTION

Allows to filter JSON-like data so it's suitable for public consumption.
The pattern describes the schema, and the module trims the extra data.

=head2 Basic syntax

To select keys, list them in a comma-separated string:

=begin code :lang<raku>

# Select keys "a", "b", and "c".
mask('a,b,c', %data);

=end code

To select all keys except a few, negate them:

=begin code :lang<raku>

# Select all the keys that aren't "a" or "b".
mask('-a,-b', %data);

=end code

To select subkeys, use parentheses:

=begin code :lang<raku>

# Keeps only "a", and in it only its subkeys "b" and "c".
mask('a(b,c)', %data);

=end code

You can of course combine them:

=begin code :lang<raku>

# Select everything but "password", but only keep the
# "name" and "email" subkeys from "profile".
mask('-password,profile(name,email)', %data);

=end code

You can quote a key if it contains "special" characters:

=begin code :lang<raku>

# Select everything but "password" and "password-confirmation".
mask('-password,-"password-confirmation"', %data);

=end code

=head2 Compilation

If you want to reuse masks, you can pre-compile them:

=begin code :lang<raku>

my $mask = compile-mask('a,b,c');
mask($mask, %data1);
mask($mask, %data2);
mask($mask, %data3);

=end code

=head2 Array handling

The module handles arrays without you needing to do anything:
a mask will be applied recursively on each element of the array.

=begin code :lang<raku>

my @data =
  %(id => 1, name => "First Volume"),
  %(id => 2, name => "Second Adventure"),
  %(id => 3, name => "Final Countdown")
;
mask('id', @data); # Select key "id" in each sub-hash

=end code

=head2 Error handling

The module ignores missing keys.  It will however throw an exception
if a nested key ("a(b,c)") is not actually C<Associative> (or
C<Positional>).

=head1 AUTHOR

vendethiel

Source can be located at: https://github.com/raku-community-modules/JSON-Mask .
Comments and Pull Requests are welcome.

=head1 COPYRIGHT AND LICENSE

Copyright 2020 Edument AB

Copyright 2024 The Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
