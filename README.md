[![Actions Status](https://github.com/raku-community-modules/JSON-Mask/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/JSON-Mask/actions) [![Actions Status](https://github.com/raku-community-modules/JSON-Mask/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/JSON-Mask/actions) [![Actions Status](https://github.com/raku-community-modules/JSON-Mask/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/JSON-Mask/actions)

NAME
====

JSON::Mask - JSON filtering

SYNOPSIS
========

```raku
use JSON::Mask;

# Select keys "a", "b", and "c".
mask('a,b,c', %data);

my $mask = compile-mask('a,b,c');
mask($mask, %data1);
```

DESCRIPTION
===========

Allows to filter JSON-like data so it's suitable for public consumption. The pattern describes the schema, and the module trims the extra data.

Basic syntax
------------

To select keys, list them in a comma-separated string:

```raku
# Select keys "a", "b", and "c".
mask('a,b,c', %data);
```

To select all keys except a few, negate them:

```raku
# Select all the keys that aren't "a" or "b".
mask('-a,-b', %data);
```

To select subkeys, use parentheses:

```raku
# Keeps only "a", and in it only its subkeys "b" and "c".
mask('a(b,c)', %data);
```

You can of course combine them:

```raku
# Select everything but "password", but only keep the
# "name" and "email" subkeys from "profile".
mask('-password,profile(name,email)', %data);
```

You can quote a key if it contains "special" characters:

```raku
# Select everything but "password" and "password-confirmation".
mask('-password,-"password-confirmation"', %data);
```

Compilation
-----------

If you want to reuse masks, you can pre-compile them:

```raku
my $mask = compile-mask('a,b,c');
mask($mask, %data1);
mask($mask, %data2);
mask($mask, %data3);
```

Array handling
--------------

The module handles arrays without you needing to do anything: a mask will be applied recursively on each element of the array.

```raku
my @data =
  %(id => 1, name => "First Volume"),
  %(id => 2, name => "Second Adventure"),
  %(id => 3, name => "Final Countdown")
;
mask('id', @data); # Select key "id" in each sub-hash
```

Error handling
--------------

The module ignores missing keys. It will however throw an exception if a nested key ("a(b,c)") is not actually `Associative` (or `Positional`).

AUTHOR
======

vendethiel

Source can be located at: https://github.com/raku-community-modules/JSON-Mask . Comments and Pull Requests are welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2020 Edument AB

Copyright 2024 The Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

