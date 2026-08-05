::  sim-term: vere's terminal driver (pkg/vere/io/term.c) in hoon
::
::    the semantic layer of term.c: belts in, blits applied to a
::    virtual screen, rendered output as effects.  the raw-byte
::    escape/utf8 parser (_term_read_cb and tat_u.esc/.fut) is not
::    modeled: input enters at the $belt level, which is where
::    vere's parser delivers it to arvo anyway.  each arm cites the
::    C it mirrors.
::
/-  *sim-uv
=,  dill
|%
::  $term-sim: u3_utty + u3_utat, reduced to the semantic fields
::
::    liv: car_u.liv_o
::    tid: terminal id (always '1' — _term_io_talk's wire)
::    siz: tat_u.siz [cols rows]
::    cur: cursor column on the bottom line (tat_u.mir.cus_w)
::    lin: bottom-line contents (tat_u.mir.lin_w)
::    hist: committed lines, most recent first (the transcript;
::          replaces bytes written to the tty)
::    born-tries: egg_u->try_w for %born
::
+$  term-sim
  $:  liv=?
      tid=@ta
      siz=[cols=@ud rows=@ud]
      cur=@ud
      lin=(list @c)
      hist=(list cord)
      born-tries=@ud
  ==
+$  res  [fx=(list uv-effect) ova=(list sim-ovum) sim=term-sim]
--
::
|_  sim=term-sim
++  this  .
::  +init: u3_term_io_init — 80x24, session '1'
::
++  init
  ^-  term-sim
  [liv=| tid='1' siz=[80 24] cur=0 lin=~ hist=~ born-tries=0]
::  +talk: _term_io_talk — %born (peered), %blew, %hail on /term/1
::
++  talk
  ^-  res
  :-  ~
  :_  sim
  :~  [/term/[tid.sim] [%born ~]]
      [/term/[tid.sim] [%blew siz.sim]]
      [/term/[tid.sim] [%hail ~]]
  ==
::  +belt: _term_read_cb → u3_term_ef_bake — plan [%belt ...]
::
++  belt
  |=  bet=belt:dill
  ^-  res
  [~ [[/term/[tid.sim] [%belt bet]] ~] sim]
::  +take: _term_io_kick — %blit and %logo
::
::    returns [took=? res].  %blit applies each blit to the screen
::    (_term_ef_blit); %logo mirrors u3_pier_exit.
::
++  take
  |=  [=wire card=sim-card]
  ^-  [took=? res]
  ?.  ?=([%term *] wire)
    [| ~ ~ sim]
  ?+  -.card  [| ~ ~ sim]
    %logo  [& [%pier-exit ~]~ ~ sim]
    %blit  =^  fx  sim  (blits ;;((list blit) +.card))
           [& fx ~ sim]
  ==
::  +blits: _term_ef_blit over a list
::
++  blits
  |=  bis=(list blit)
  ^-  [(list uv-effect) term-sim]
  =|  fx=(list uv-effect)
  |-
  ?~  bis  [(flop fx) sim]
  =^  new  sim  (blit-one i.bis)
  $(bis t.bis, fx (weld (flop new) fx))
::  +blit-one: one blit against the virtual screen
::
::    %put writes at the cursor on the bottom line; %nel commits the
::    bottom line to the transcript as a %write effect; %hop moves
::    the cursor; %clr/%wyp clear; %klr renders a stub plainly;
::    %sag/%sav become %save effects, %url %browse; %bel is dropped
::    (a beep writes no state).  %mor recurs.
::
++  blit-one
  |=  bit=blit
  ^-  [(list uv-effect) term-sim]
  ?-  -.bit
    %bel  [~ sim]
    %clr  [~ sim(lin ~, cur 0, hist ~)]
    %hop  [~ sim(cur ?@(p.bit p.bit x.p.bit))]
    %mor  =/  bis  p.bit
          =|  fx=(list uv-effect)
          |-
          ?~  bis  [(flop fx) sim]
          =^  new  sim  ^$(bit i.bis)
          $(bis t.bis, fx (weld (flop new) fx))
    %nel  =/  line  (crip (tufa lin.sim))
          :-  [%write line]~
          sim(lin ~, cur 0, hist [line hist.sim])
    %put  :-  ~
          =/  new  (place lin.sim cur.sim p.bit)
          sim(lin new, cur (add cur.sim (lent p.bit)))
    %klr  :-  ~
          =/  txt  `(list @c)`(zing (turn p.bit |=([* t=(list @c)] t)))
          =/  new  (place lin.sim cur.sim txt)
          sim(lin new, cur (add cur.sim (lent txt)))
    %sag  [[%save p.bit (as-octs:mimes:html (jam q.bit))]~ sim]
    %sav  [[%save p.bit (as-octs:mimes:html q.bit)]~ sim]
    %url  [[%browse p.bit]~ sim]
    %wyp  [~ sim(lin ~, cur 0)]
  ==
::  +place: overwrite .txt into .lin at column .cur, padding with
::  spaces (the mirror-buffer write in _term_it_show_tour)
::
++  place
  |=  [lin=(list @c) cur=@ud txt=(list @c)]
  ^-  (list @c)
  =/  pad  ?:((gte (lent lin) cur) lin (weld lin (reap (sub cur (lent lin)) `@c`' ')))
  ;:  weld
    (scag cur pad)
    txt
    (slag (add cur (lent txt)) pad)
  ==
::  +news: _born_bail_cb — %born retries, then gives up quietly
::
++  news
  |=  [=wire result=$%([%done ~] [%bail =bail-mote])]
  ^-  res
  ?.  ?=([%term *] wire)  [~ ~ sim]
  ?:  ?=(%done -.result)  [~ ~ sim(liv &)]
  ?:  &((lth born-tries.sim 2) ?=(%soft bail-mote.result))
    [~ [[wire [%born ~]] ~] sim(born-tries +(born-tries.sim))]
  [[%slog "term: %born failed"]~ ~ sim]
--
