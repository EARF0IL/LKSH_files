function set_thrust_limit_to_engine_group {
  parameter limit.
  parameter engine_group.

  for part in engine_group {
    set part:THRUSTLIMIT to limit.
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
  set engines_isp to 0.

  for engine in ENGINES{
    if engine:ignition = true and engine:flameout = false{
      set engines_thrust to engines_thrust + engine:availablethrust.
      set engines_isp to engines_isp + engine:isp * engine:availablethrust.
    }
  }

  if ens_thrust < 0.01 {
    return list(-1, -1).
  }
  return list(engines_thrust, engines_isp / engines_thrust).
}


function calc_orbital_speed{
  return BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE).
}


function calc_g{
  return (constant:G * BODY:MASS) / ((BODY:RADIUS + SHIP:ALTITUDE) ^ 2)
}


function f_Fi{
  set horizontal_speed to get_horizontal_speed(). //горизонтальная скорость
  set vertical_speed to get_vertical_speed(). //вертикальная скорость
  set g to calc_g.//g на данной высоте
  set dV_to_orbit to calc_orbital_speed - SHIP:ORBIT:VELOCITY:ORBIT:MAG. // дельта V до первой космической (здесь еще учитывались грав. потери, но без них тоже работает)
  set thrust_isp to calc_summary_thrust. // получаем суммарную тягу и средний удельный импульс по движкам второй ступени
  if thrust_isp[0] = -1{
    return -1.
  }
  set t to f_TfV(dV2, ThrIsp[1]*9.806, ThrIsp[0]*1000). // время, потребнное для набора первой космической
  if t = -1{
    return -1.
  }
  set dVh to f_Vorb - Vh. //недостаток горизонтальной скорости до первой космической
  set sinFi to (g*(dVh/f_Vorb)*t2-Vz)/dV2. //а вот это сам расчет угла. 
  if sinFi > 1 {set sinFi to 1.}
  if sinFi < -1 {set sinFi to -1.}
  return arcsin(sinFi). 
}.



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

print "Begin circularization.".
RCS on.
set eccOld to Orbit:ECCENTRICITY+10.
wait 1.
set Fi to 0.
//lock STEERING to HEADING(90, -5).
set target_pitch to -5.
lock THROTTLE to 1.
wait 2.
until (Orbit:ECCENTRICITY > eccOld)
{
  set Fi to f_Fi.
  if not (Fi = -1){
    // lock STEERING to HEADING(90, MAX(MIN(Fi,90),-10)).
    set target_pitch to MAX(MIN(Fi,90),-20).
    set eccOld to Orbit:ECCENTRICITY.   
  }  
  wait 0.01.
}
lock THROTTLE to 0.
wait 3.
SAS on.
stage.
print "Complete.".
