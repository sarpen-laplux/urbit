::  make a unix commit event
::
::    call as > .event/jam +commit-event /path/to/file
::    to be used with ./urbit-binary -I event.jam pier
::
::    XX expand with arbitrary user-defined events?
::    XX only supports files in which +noun:grab in the mark file returns a @t
::       (e.g. hoon files)
::
:-  %say
|=  [[now=@da tick=@ud eny=@uvJ bec=beak] [=path ~] ~]
:-  %noun
?~  bema=(de-bema path)
  ~|(%path-not-bema !!)
=/  beam  (bema-to-beam u.bema)
=+  .^(file=@t %cx path)
[/c/sync %info desk=q.beam & [s.beam %ins %mime !>([/ (as-octs:mimes:html file)])]~]
