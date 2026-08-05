::  tests for sim-term: the term.c port
::
/-  *sim-uv
/+  *test, sim-term
=,  dill
=/  make  init:sim-term
|%
::  +test-term-talk: %born, %blew, %hail on /term/1
::
++  test-term-talk
  =/  r=res:sim-term  talk:~(. sim-term make)
  %+  expect-eq
    !>  :~  [/term/1 [%born ~]]
            [/term/1 [%blew 80 24]]
            [/term/1 [%hail ~]]
        ==
  !>(ova.r)
::  +test-term-belt: input becomes a %belt ovum
::
++  test-term-belt
  =/  r=res:sim-term  (belt:~(. sim-term make) [%txt (tuba "hi")])
  (expect-eq !>([[/term/1 [%belt %txt (tuba "hi")]] ~]) !>(ova.r))
::  +test-term-put-nel: writing then newline commits a line
::
++  test-term-put-nel
  =^  took1  make
    =/  r  (take:~(. sim-term make) /term/1 [%blit [%put "abc"] ~])
    [took.r sim.r]
  =/  r2  (take:~(. sim-term make) /term/1 [%blit [%nel ~] ~])
  ;:  weld
    (expect-eq !>(&) !>(took1))
    (expect-eq !>([%write 'abc']~) !>(fx.r2))
    (expect-eq !>(['abc' ~]) !>(hist.sim.r2))
    (expect-eq !>(~) !>(lin.sim.r2))
  ==
::  +test-term-hop-overwrite: cursor moves, text overwrites in place
::
++  test-term-hop-overwrite
  =/  r1  (take:~(. sim-term make) /term/1 [%blit [%put "hello"] [%hop 0] [%put "J"] [%nel ~] ~])
  (expect-eq !>([%write 'Jello']~) !>(fx.r1))
::  +test-term-mor: %mor recurs in order
::
++  test-term-mor
  =/  r1  (take:~(. sim-term make) /term/1 [%blit [%mor [%put "a"] [%nel ~] [%put "b"] [%nel ~] ~] ~])
  (expect-eq !>([[%write 'a'] [%write 'b'] ~]) !>(fx.r1))
::  +test-term-logo: %logo exits the pier
::
++  test-term-logo
  =/  r  (take:~(. sim-term make) /term/1 [%logo ~])
  (expect-eq !>([& [%pier-exit ~]~]) !>([took.r fx.r]))
::  +test-term-sav: %sav becomes a %save effect
::
++  test-term-sav
  =/  r  (take:~(. sim-term make) /term/1 [%blit [%sav /out/jam 0x1234] ~])
  %+  expect-eq
    !>([%save /out/jam (as-octs:mimes:html 0x1234)]~)
  !>(fx.r)
--
