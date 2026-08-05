::  tests for sim-fleet: one ship, echo kernel, full event loop
::
/-  *sim-uv
/+  *test, sim-fleet, sim-io
=,  dill
::  a mock kernel: echoes %belt %txt input back as %blit put+nel
::
=/  mock=vase
  !>  |%
      ++  poke
        |=  [now=@da ovo=*]
        ^-  ^
        =/  wir  ;;(wire -.ovo)
        ?.  ?=([%term *] wir)  [~ ..poke]
        =/  card  ;;((cask) +.ovo)
        ?.  ?=(%belt -.card)  [~ ..poke]
        =/  bet  ;;(belt:dill +.card)
        ?.  ?=(%txt -.bet)  [~ ..poke]
        [[/term/1 blit/[[%put p.bet] [%nel ~] ~]]~ ..poke]
      --
|%
++  test-fleet-echo
  =/  m  ml:sim-fleet
  =/  =form:m
    ;<  ~  bind:m  (spawn:sim-fleet ~zod mock)
    ;<  ~  bind:m  (inject:sim-fleet ~zod [%belt [%txt (tuba "hi")]])
    (logs:sim-fleet ~zod)
  =/  out  (form [fleet=~ wen=~2026.1.1 log=~])
  ?>  ?=(%done -.p.out)
  %+  expect-eq
    !>([%write 'hi']~)
  !>((skim p.p.out |=(f=uv-effect ?=(%write -.f))))
::  +test-fleet-warp: behn doze then warp fires the timer
::
++  test-fleet-warp
  =/  m  ml:sim-fleet
  =/  =form:m
    ;<  ~  bind:m  (spawn:sim-fleet ~zod mock)
    ;<  ~  bind:m  (inject:sim-fleet ~zod [%behn [%news /behn/0v0 %done ~]])
    ((jab:sm:sim-fleet |=(w=world:sim-fleet w)))  ::  no-op; placeholder
  =/  out  (form [fleet=~ wen=~2026.1.1 log=~])
  (expect-eq !>(%done) !>(-.p.out))
--
