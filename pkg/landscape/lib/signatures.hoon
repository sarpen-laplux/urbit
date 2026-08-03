/-  post
^?
=<  [post .]
=,  post
|%
++  jael-scry
  |*  [=mold our=ship desk=term now=time tick=@ud =path]
  .^  mold
    %j
    (scot %p our)
    desk
    (en-cose da+now ud+tick)
    path
  ==
++  sign
  |=  [our=ship now=time tick=@ud =hash]
  ^-  signature
  =+  (jael-scry ,=life our %life now tick /(scot %p our))
  =+  (jael-scry ,=ring our %vein now tick /(scot %ud life))
  =/  cic  (nol:nu:cric:crypto ring)
  :+  `@ux`(jam [(sign:ed:crypto hash sgn:ven:ex:cic) hash])
    our
  life
::
++  is-signature-valid
  |=  [our=ship =signature =hash now=time tick=@ud]
  ^-  ?
  =+  (jael-scry ,lyf=(unit @) our %lyfe now tick /(scot %p q.signature))
  ::  we do not have a public key from ship at this life
  ::
  ?~  lyf  %.y
  ?.  =(u.lyf r.signature)  %.y
  =+  %:  jael-scry
        ,deed=[a=life b=pass c=(unit @ux)]
        our  %deed  now  tick  /(scot %p q.signature)/(scot %ud r.signature)
      ==
  ::  if signature is from a past life, skip validation
  ::  XX: should be visualised on frontend, not great.
  ?.  =(a.deed r.signature)  %.y
  ::  verify signature from ship at life
  ::
  =/  them  (com:nu:cric:crypto b.deed)
  =+  ;;([sig=@ msg=@] (cue p.signature))
  ?.  =(hash msg)  |
  (veri:ed:crypto sig msg sgn:ded:ex:them)
::
++  are-signatures-valid
  |=  [our=ship =signatures =hash now=time tick=@ud]
  ^-  ?
  =/  signature-list  ~(tap in signatures)
  |-
  ?~  signature-list
    %.y
  ?:  (is-signature-valid our i.signature-list hash now tick)
    $(signature-list t.signature-list)
  %.n
--
