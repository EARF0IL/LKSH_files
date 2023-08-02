function set_thrust_limit_to_engine_group {
  parameter limit.
  parameter engine_group.

  for part in engine_group {
    set part:THRUSTLIMIT to limit.
  }
}


function get_vertical_speed{
  return VDOT(SHIP:UP:VECTOR, SHIP:ORBIT:VELOCITY:ORBIT).
}


function get_horizontal_speed{
  return VXCL(SHIP:UP:VECTOR, SHIP:ORBIT:VELOCITY:ORBIT):MAG.
}


function calc_gravity_force{
  return (CONSTANT:G * BODY:MASS * SHIP:MASS) / ((BODY:RADIUS + SHIP:ALTITUDE) ^ 2). 
}


function calc_centrifugal_force{
  return (SHIP:MASS * (SHIP:GROUNDSPEED ^ 2)) / (BODY:RADIUS + SHIP:ALTITUDE).
}

function calc_summary_thrust{
  set engines_thrust to 0.

  for engine in ENGINES{
    if engine:ignition = true and engine:flameout = false{
      set engines_thrust to engines_thrust + engine:availablethrust.
    }
  }

  if ens_thrust < 0.01 {
    return -1.
  }
  return engines_thrust.
}


function calc_delta_orbital_speed{
  return BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE).
}


function calc_angle_to_horizont{
  if ens_thrust = -1{
    return -1.
  }
  set thrust_force to calc_summary_thrust() * THROTTLE
  return arcsin((calc_gravity_force() - calc_centrifugal_force()) / thrust_force) - max(min(get_vertical_speed * 3, 2), -2).
}


SAS off.
RCS off.

set target_pitch to 90.
set target_roll to 45.
set azimuth to 90.

set urm_first_pair_engines to SHIP:PARTSDUBBED("URMengine1").
set urm_second_pair_engines to SHIP:PARTSDUBBED("URMengine2").
set urm_third_pair_engines to SHIP:PARTSDUBBED("URMengine3").

set urm_first_pair_tanks to SHIP:PARTSDUBBED("URMtank1").
set urm_second_pair_tanks to SHIP:PARTSDUBBED("URMtank2").
set urm_third_pair_tanks to SHIP:PARTSDUBBED("URMtank3").

set first_stage_engine to SHIP:PARTSDUBBED("FirstStageEngine")[0].
set first_stage_tank to SHIP:PARTSDUBBED("FirstStageTank")[0].

lock urm_first_pair_fuel to urm_first_pair_tanks[0]:RESOURCES[1]:Amount + urm_first_pair_tanks[1]:RESOURCES[1]:Amount.
lock urm_second_pair_fuel to urm_second_pair_tanks[0]:RESOURCES[1]:Amount + urm_second_pair_tanks[1]:RESOURCES[1]:Amount.
lock urm_third_pair_fuel to urm_third_pair_tanks[0]:RESOURCES[1]:Amount + urm_third_pair_tanks[1]:RESOURCES[1]:Amount.
lock first_stage_tank_current_fuel to first_stage_tank:RESOURCES[1]:Amount.

set_thrust_limit_to_engine_group(100, urm_first_pair_engines).
set_thrust_limit_to_engine_group(75, urm_second_pair_engines).
set_thrust_limit_to_engine_group(50, urm_third_pair_engines).

set mysteer to SHIP:facing.
lock STEERING to mysteer.
lock mysteer to HEADING(azimuth, target_pitch, target_roll).

//triggers
when urm_first_pair_fuel < 5000 then{
  print "First urm pair decouple.".
  set_thrust_limit_to_engine_group(100, urm_second_pair_engines).
  set_thrust_limit_to_engine_group(75, urm_third_pair_engines).
  stage.
  wait 5.
  set target_roll to target_roll - 60. 
}

when urm_second_pair_fuel < 5000 then{
  print "Second urm pair decouple.".
  set_thrust_limit_to_engine_group(100, urm_third_pair_engines).
  stage.
  wait 5.
  set target_roll to target_roll - 60.
}

when urm_third_pair_fuel < 5000 then{
  print "Third urm pair decouple.".
  stage.
  set target_roll to 0.
}

when first_stage_tank_current_fuel < 5000 then{
  print "Second Stage Separation.".
  stage.
  lock THROTTLE to 1.
}

clearscreen.

print "Counting down:".
from {local countdown is 5.} until countdown = 0 step {SET countdown to countdown - 1.} do {
    print "..." + countdown.
    wait 1. // pauses the script here for 1 second.
}

lock THROTTLE to 1.0.

stage.
print "Engine startup".
print "Wait for maximum thrust".
wait 4.

stage.
print "Lift Off".

print "Vertical ascent".
//set mysteer to HEADING(90, target_pitch, target_roll).
wait until SHIP:VERTICALSPEED > 50.

//set first_stage_tank_max_fuel to first_stage_tank:RESOURCES[1]:Amount.
wait 1.

print "Begin gravity turn".
set turnStartTime to TIME:SECONDS.
set turnDuration to 195. // 210 is work //best work with low gravity loss 190 // 
set turnPitch to 90.
set turnSpeed to turnPitch / turnDuration.

until TIME:SECONDS - turnStartTime > turnDuration {
    set elapsedTime to TIME:SECONDS - turnStartTime.
    set target_pitch to 90 - turnSpeed * elapsedTime.
    //set mysteer TO HEADING(90, target_pitch, target_roll).
    
    print "Pitching to " + ROUND(target_pitch,0) + " degrees                 " AT(0,31).
    wait 0.1.
}

print "End gravity turn.".

print "Wait for apoapsis.".
wait until ETA:APOAPSIS < 1.

print "Begin circularization.".
RCS on.
until calc_delta_orbital_speed() < 0{
  set angle to calc_angle_to_horizont().
  if not angle = -1{
    set target_pitch to angle.
    if calc_angle_to_horizont() > 20{
      wait 0.1.
    }
  }
}

lock THROTTLE to 0.
wait 3.
SAS on.
stage.
print "Complete.".
