::  tests for sim-behn: the behn.c port, driven through sim-io
::
/+  *test, sim-behn, sim-io
/-  *sim-uv
=/  t0  ~2026.1.1
|%
++  make
  ^-  behn-sim:sim-behn
  (init:~(. sim-behn *behn-sim:sim-behn) t0 1)
::  +test-behn-talk: driver start plans %born on the sev wire
::
++  test-behn-talk
  =/  sim  make
  =/  =res:sim-behn  talk:~(. sim-behn sim)
  ;:  weld
    (expect-eq !>(~) !>(fx.res))
    (expect-eq !>([[/behn/(scot %uv (mug t0)) [%born ~]] ~]) !>(ova.res))
    (expect-eq !>(|) !>(liv.sim.res))
  ==
::  +test-behn-doze-set: %doze [~ wen] arms the timer for the gap
::
++  test-behn-doze-set
  =/  sim  make
  =^  took  sim
    =/  r  (take:~(. sim-behn sim) t0 /behn [%doze `(add t0 ~m1)])
    [[took.r fx.res.r] sim.res.r]
  ;:  weld
    (expect-eq !>([& [%timer-start 1 ~m1]~]) !>(took))
    (expect-eq !>(&) !>(alm.sim))
    (expect-eq !>(&) !>(liv.sim))
  ==
::  +test-behn-doze-replace: a second %doze stops then re-arms
::
++  test-behn-doze-replace
  =/  sim  make
  =/  r1  (take:~(. sim-behn sim) t0 /behn [%doze `(add t0 ~m1)])
  =/  r2  (take:~(. sim-behn sim.res.r1) t0 /behn [%doze `(add t0 ~m5)])
  (expect-eq !>([[%timer-stop 1] [%timer-start 1 ~m5] ~]) !>(fx.res.r2))
::  +test-behn-doze-cancel: %doze ~ just stops
::
++  test-behn-doze-cancel
  =/  sim  make
  =/  r1  (take:~(. sim-behn sim) t0 /behn [%doze `(add t0 ~m1)])
  =/  r2  (take:~(. sim-behn sim.res.r1) t0 /behn [%doze ~])
  ;:  weld
    (expect-eq !>([%timer-stop 1]~) !>(fx.res.r2))
    (expect-eq !>(|) !>(alm.sim.res.r2))
  ==
::  +test-behn-past-doze: a past date arms with zero gap
::
++  test-behn-past-doze
  =/  sim  make
  =/  r  (take:~(. sim-behn sim) (add t0 ~d1) /behn [%doze `t0])
  (expect-eq !>([%timer-start 1 `@dr`0]~) !>(fx.res.r))
::  +test-behn-fire: timer fire plans %wake and arms the backstop
::
++  test-behn-fire
  =/  sim  make
  =/  r1  (take:~(. sim-behn sim) t0 /behn [%doze `(add t0 ~m1)])
  =/  r2  (call:~(. sim-behn sim.res.r1) (add t0 ~m1) [%timer-fire 1])
  ;:  weld
    (expect-eq !>([%timer-start 1 ~m10]~) !>(fx.res.r2))
    (expect-eq !>([[/behn [%wake ~]] ~]) !>(ova.res.r2))
    (expect-eq !>(&) !>(alm.sim.res.r2))
  ==
::  +test-behn-wake-retry: soft bail replans %wake twice, then blocks
::
++  test-behn-wake-retry
  =/  sim  make
  =/  r1  (call:~(. sim-behn sim) t0 [%news /behn %bail %soft])
  =/  r2  (call:~(. sim-behn sim.res.r1) t0 [%news /behn %bail %soft])
  =/  r3  (call:~(. sim-behn sim.res.r2) t0 [%news /behn %bail %soft])
  ;:  weld
    (expect-eq !>([[/behn [%wake ~]] ~]) !>(ova.res.r1))
    (expect-eq !>([[/behn [%wake ~]] ~]) !>(ova.res.r2))
    (expect-eq !>(~) !>(ova.res.r3))
    %+  expect-eq
      !>([[%slog "behn: timer failed; queue blocked"] [%bail ~] ~])
    !>(fx.res.r3)
  ==
::  +test-behn-exit: teardown closes the handle
::
++  test-behn-exit
  =/  r  (call:~(. sim-behn make) t0 [%exit ~])
  (expect-eq !>([%close 1]~) !>(fx.res.r))
::  +test-sim-io-monad: the sio builder threads state; pin sees it
::
++  test-sim-io-monad
  =/  sm  (sio:sim-io ,[log=(list @t) n=@ud])
  =/  m   (thread-form:sm ,@ud)
  =/  =form:m
    ;<  ~     bind:m  (jab:sm |=(s=[log=(list @t) n=@ud] s(n 5)))
    ;<  s=[log=(list @t) n=@ud]  bind:m  get:sm
    %+  (pin:m ,@ud)
      ((lift-eng:sm ,@ud) |=(s=[log=(list @t) n=@ud] [(mul 2 n.s) s(log ['x' log.s])]))
    |=  [v=@ud s=[log=(list @t) n=@ud]]
    (pure:m (add v (lent log.s)))
  =/  out  (form [~ 0])
  ;:  weld
    (expect-eq !>([%done 11]) !>(yil=-.out))
    (expect-eq !>([['x' ~] 5]) !>(+.out))
  ==
--
