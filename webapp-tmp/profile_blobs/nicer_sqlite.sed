#!/bin/sed -urf
# -*- coding: UTF-8, tab-width: 2 -*-

s~( REFERENCES [a-z]+)\(([a-z]+)\) ~\1<\2> ~g

s~( \()([A-Za-z]+ [A-Za-z]+ )~\1\n\t\r\2~g
: parens_comma
  s~\r([A-Za-z0-9_<> .-]+,?) ?~\1\n\t\r~g
t parens_comma
s~\r~~g
$!s~;$~&\n~

s~( REFERENCES [a-z]+)<([a-z]+)> ~\1(\2) ~g

s~\t~  ~g
