-module(app_ffi).

-export([atom_from_string/1]).

atom_from_string(Prefix) ->
    binary_to_atom(Prefix, utf8).
