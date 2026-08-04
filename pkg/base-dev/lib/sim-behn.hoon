::  sim-behn: vere's behn io driver (pkg/vere/io/behn.c) in hoon
::
::    a field-for-field port.  every arm cites the C it mirrors.
::    the engine is a non-effectful door: uv-events (and arvo %doze
::    effects) in, uv-effects and arvo-bound ova out.
::
/-  *sim-uv
|%
::  $behn-sim: u3_behn
::
::    liv: car_u.liv_o     (driver live)
::    alm: teh_u->alm_o    (timer armed)
::    sev: teh_u->sev_l    (instance number; mug of boot time)
::    tim: teh_u->tim_u    (the one uv timer handle)
::    wake-tries, born-tries: egg_u->try_w for the retryable ova
::
+$  behn-sim
  $:  liv=?
      alm=?
      sev=@uv
      tim=hid
      wake-tries=@ud
      born-tries=@ud
  ==
::  +res: what every arm produces
::
+$  res  [fx=(list uv-effect) ova=(list sim-ovum) sim=behn-sim]
--
::
|_  sim=behn-sim
::  +init: u3_behn_io_init
::
::    the harness allocates the timer handle and supplies boot
::    entropy-time for sev (C: mug of gettimeofday).
::
++  init
  |=  [now=@da tim=hid]
  ^-  behn-sim
  [liv=| alm=| sev=`@uv`(mug now) tim=tim wake-tries=0 born-tries=0]
::  +this
::
++  this  .
::  +call: dispatch a uv-event
::
++  call
  |=  [now=@da ev=uv-event]
  ^-  res
  ?-  -.ev
    %talk        talk
    %timer-fire  (fire hid.ev)
    %news        (news [wire res]:ev)
    %exit        exit
  ==
::  +talk: _behn_io_talk — plan [%born ~] on /behn/0vsev
::
++  talk
  ^-  res
  [~ [[/behn/(scot %uv sev.sim) [%born ~]] ~] sim]
::  +take: _behn_io_kick — the only effect behn accepts is %doze
::
::    returns [took=? res]: took=| mirrors ret_o=c3n (not ours).
::    _behn_ef_doze: kick sets liv; stop the timer if armed; arm it
::    if wen is set.  gap is clamped at zero for past dates (C
::    computes a ms gap from gettimeofday).
::
++  take
  |=  [now=@da =wire card=sim-card]
  ^-  [took=? res]
  ?.  &(?=([%behn *] wire) ?=(%doze -.card))
    [| ~ ~ sim]
  =/  wen  ;;((unit @da) +.card)
  =.  liv.sim  &
  =^  stop=(list uv-effect)  sim
    ?.  alm.sim  [~ sim]
    [[%timer-stop tim.sim]~ sim(alm |)]
  ?~  wen
    [& stop ~ sim]
  =/  gap=@dr  `@dr`?:((gte u.wen now) (sub u.wen now) 0)
  [& (snoc stop [%timer-start tim.sim gap]) ~ sim(alm &)]
::  +fire: _behn_time_cb
::
::    disarm, then re-arm a ten-minute backstop (crash recovery for
::    a lost %doze), then plan [%wake ~] on /behn.
::
++  fire
  |=  t=hid
  ^-  res
  ?>  =(t tim.sim)
  =.  alm.sim  &                        ::  backstop armed
  :+  [%timer-start tim.sim ~m10]~
    [[/behn [%wake ~]] ~]
  sim
::  +news: ovum results — _behn_born_news / _behn_born_bail /
::  _behn_wake_bail
::
::    %done on the born wire: liv=&.  bails retry twice unless the
::    mote is dire; exhausted %born bails the pier, exhausted %wake
::    logs and blocks the timer queue (ops_u.beb ignored: we always
::    mirror the bail so tests see it).
::
++  news
  |=  [=wire result=$%([%done ~] [%bail =bail-mote])]
  ^-  res
  ?:  ?=([%behn @ ~] wire)                      ::  %born peer
    ?:  ?=(%done -.result)
      [~ ~ sim(liv &)]
    ?:  &((lth born-tries.sim 2) ?=(%soft bail-mote.result))
      [~ [[wire [%born ~]] ~] sim(born-tries +(born-tries.sim))]
    :+  [[%slog "behn: initialization failed"] [%bail ~] ~]
      ~
    sim
  ?:  ?=([%behn ~] wire)                        ::  %wake peer
    ?:  ?=(%done -.result)  [~ ~ sim]
    ?:  &((lth wake-tries.sim 2) ?=(%soft bail-mote.result))
      [~ [[wire [%wake ~]] ~] sim(wake-tries +(wake-tries.sim))]
    :+  [[%slog "behn: timer failed; queue blocked"] [%bail ~] ~]
      ~
    sim
  [~ ~ sim]
::  +exit: _behn_io_exit — close the timer handle
::
++  exit
  ^-  res
  [[%close tim.sim]~ ~ sim]
--
