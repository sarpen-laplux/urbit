::  sim-io: stateful strandio-style monad builder for io simulation
::
::    modeled directly on the lia script monad
::    (sur/wasm/lia.hoon, +script): a state monad whose form is
::    $-(state [yield state]), with state threaded through form
::    application rather than stored in the yield.
::
::    usage:
::      =/  sm  (sio state-mold)
::      =/  m   (thread-form:sm result-mold)
::      ;<  x=res  bind:m  action  ...
::
::    deviation from the design doc: no %emit suspension arm yet.
::    effects accumulate in the state (the fleet state carries an
::    effect log); revisit with a lia-%1-style call-out arm if a C
::    host ever needs to interleave with a running script.
::
|%
++  sio
  |*  sat=mold
  |%
  ::  +thread-form: monad instance over a result mold
  ::
  ++  thread-form
    |*  a=mold
    |%
    ++  yild
      $%  [%done p=a]
          [%fail p=tang]
      ==
    ++  output  (pair yild sat)
    ++  form    $-(sat output)
    ::  +pure: %done
    ::
    ++  pure
      |=  arg=a
      ^-  form
      |=  s=sat
      [done+arg s]
    ::  +fail
    ::
    ++  fail
      |=  err=tang
      ^-  form
      |=  s=sat
      [fail+err s]
    ::  +bind: thread state through mon, then con on success
    ::
    ++  bind
      |*  b=mold
      |=  [mon=(sio-form b) con=$-(b form)]
      ^-  form
      |=  s=sat
      =^  yil=(sio-yild b)  s  (mon s)
      ?.  ?=(%done -.yil)  [yil s]
      ((con p.yil) s)
    ::  +pin: bind, continuation also receives the threaded state
    ::
    ::    the rune-free spelling of ;^ (%mckt).  the continuation's
    ::    sample is [result state]; state writes made by the action
    ::    are visible, and the continuation may itself read state
    ::    without a separate +get step.
    ::
    ++  pin
      |*  b=mold
      |=  [mon=(sio-form b) con=$-([b sat] form)]
      ^-  form
      |=  s=sat
      =^  yil=(sio-yild b)  s  (mon s)
      ?.  ?=(%done -.yil)  [yil s]
      ((con [p.yil s]) s)
    --
  ::  raw shapes for cross-mold binds (lia's script-raw-form pattern)
  ::
  ++  sio-yild  |*  a=mold  $%([%done p=a] [%fail p=tang])
  ++  sio-form  |*  a=mold  $-(sat (pair (sio-yild a) sat))
  ::  state primitives (all typecheck as raw-form of their result)
  ::
  ++  get                                       ::  read state
    |=  s=sat
    [done+s s]
  ++  put                                       ::  replace state
    |=  n=sat
    |=  s=sat
    [done+~ n]
  ++  jab                                       ::  modify state
    |=  f=$-(sat sat)
    |=  s=sat
    [done+~ (f s)]
  ::  +lift-eng: wrap an =^-style engine arm into the monad
  ::
  ::    for door arms shaped $-(sat [res sat]): the classic
  ::    =^  res  state  (arm state)  pattern, lifted.
  ::
  ++  lift-eng
    |*  r=mold
    |=  g=$-(sat [r sat])
    |=  s=sat
    =^  v=r  s  (g s)
    [done+v s]
  --
--
