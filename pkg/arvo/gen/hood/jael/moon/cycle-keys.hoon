::  change the keys of a moon
::
::::  /hoon/moon-cycle-keys/hood/gen
  ::
/-  *sole
/+  *generators
::
::::
  ::
:-  %say
|=  $:  [now=@da tick=@ud eny=@uvJ our=@p ^]
        [mon=@p ~]
        =life
        public-key=pass
    ==
:-  %helm-moon
^-  (unit [=ship =udiff:point:jael])
=/  ran  (clan:title our)
?:  ?=([?(%earl %pawn)] ran)
  %-  %-  slog  :_  ~
      leaf+"can't manage a moon from a {?:(?=(%earl ran) "moon" "comet")}"
  ~
=/  seg=ship  (sein:title our now tick mon)
?.  =(our seg)
  %-  %-  slog  :_  ~
      :-  %leaf
      "can't create keys for {(scow %p mon)}, which belongs to {(scow %p seg)}"
  ~
=/  =^life
  ?.  =(*^life life)
    life
  +(.^(^life %j (en-bema [our %life [da+now ud+tick]] /(scot %p mon))))
=/  ryf=(unit rift)
  .^((unit rift) %j (en-bema [our %ryft [da+now ud+tick]] /(scot %p mon)))
?~  ryf
  %.  ~
  %-  slog
  [leaf+"can't cycle keys for {(scow %p mon)}, it doesn't exists."]~
=/  =pass
  ?.  =(*pass public-key)
    public-key
  =/  cic  (pit:nu:cric:crypto 512 (shaz (jam mon life eny)) %b ~)
  =/  =feed:jael
    [[%2 ~] mon u.ryf [life sec:ex:cic]~]
  %-  %-  slog
      :~  leaf+"moon: {(scow %p mon)}"
          leaf+(scow %uw (jam feed))
      ==
  pub:ex:cic
`[mon *id:block:jael %keys [life 1 pass] %.n]
