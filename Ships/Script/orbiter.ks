function set_thrust_limit_to_engine_group {
  parameter limit.
  parameter engine_group.

  for part in engine_group {
    set part:THRUSTLIMIT to limit.
  }
}


function EngThrustIsp
{
  //создаем пустой лист ens
  set ens to list().
  ens:clear.
  set ens_thrust to 0.
  set ens_isp to 0.
  //запихиваем все движки в лист myengines
  list engines in myengines.
  
  //забираем все активные движки из myengines в ens.
  for en in myengines {
    if en:ignition = true and en:flameout = false {
      ens:add(en).
    }
  }
  //собираем суммарную тягу и Isp по всем активным движкам
  for en in ens {
    set ens_thrust to ens_thrust + en:availablethrust.
    set ens_isp to ens_isp + en:isp*en:availablethrust.
  }
  //Тягу возвращаем суммарную, а Isp средний.
  if ens_thrust < 0.01 {
    return list(-1, -1).
  }
  RETURN LIST(ens_thrust, ens_isp/ens_thrust).
}


// Вычисление азимута прогрейда в орбитальной плоскости.
function f_Orbit_PA{

  declare local east to vcrs(ship:up:vector, ship:north:vector).
  declare local trig_x to vdot(ship:north:vector, ship:prograde:vector).
  declare local trig_y to vdot(east, ship:prograde:vector).
  declare local Orbit_PA to arctan2(trig_y, trig_x).
  if Orbit_PA < 0 { set Orbit_PA to Orbit_PA + 360.}
  
  return Orbit_PA.
}.


// Вычисление времени из дэльты.
function f_TfV {

  declare local parameter Vel.
  declare local parameter J.
  declare local parameter Rad.
  if J = 0{
    return -1.
  }
  return J*ship:mass*1000*(1-constant():e^(-Vel/J))/Rad.
}.


// Вычисление дэльты из времени.
function f_VfT {
  declare local parameter T.
  declare local parameter J.
  declare local parameter Rad.

  return -J*ln(1-(Rad*T)/(ship:mass*1000*J)).
}.


// Вычисление конечной массы из дэльты.
function f_mfV {
  declare local parameter Vel.
  declare local parameter J.

  return ship:mass*1000/constant():e^(Vel/J).
}.


// Вычисление орбитальной скорости.
function f_V0 {
  
  return orbit:velocity:orbit:mag.
}.  


// Вычисление 1-й космической скорости на текущей высоте.
function f_Vorb {
  
  return sqrt((constant():G * body:mass) / (body:radius+ship:altitude)).
}.  


//Вычисление угла к горизонту.
function f_Fi{
  set Vh to VXCL(Ship:UP:vector, ship:velocity:orbit):mag. //горизонтальная скорость
  set Vz to VDOT(Ship:UP:vector, ship:velocity:orbit). //вертикальная скорость
  set g to (constant():G * body:mass) / ((body:radius+ship:altitude)^2).//g на данной высоте
  set dV2 to f_Vorb - f_V0. // дельта V до первой космической (здесь еще учитывались грав. потери, но без них тоже работает)
  set ThrIsp to EngThrustIsp. // получаем суммарную тягу и средний Isp по движкам второй ступени
  if EngThrustIsp[0] = -1{
    return -1.
  }
  set t2 to f_TfV(dV2, ThrIsp[1]*9.806, ThrIsp[0]*1000). // время, потребнное для набора первой космической
  if t2 = -1{
    return -1.
  }
  set dVh to f_Vorb - Vh. //недостаток горизонтальной скорости до первой космической
  set sinFi to (g*(dVh/f_Vorb)*t2-Vz)/dV2. //а вот это сам расчет угла. 
  if sinFi > 1 {set sinFi to 1.}
  if sinFi < -1 {set sinFi to -1.}
  return arcsin(sinFi). 
}.

SET TARGET_PITCH TO 90.

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

//triggers
when urm_first_pair_fuel < 5000 then{
  print "First urm pair decouple.".
  set_thrust_limit_to_engine_group(100, urm_second_pair_engines).
  set_thrust_limit_to_engine_group(75, urm_third_pair_engines).
  stage.
}

when urm_second_pair_fuel < 5000 then{
  print "Second urm pair decouple.".
  set_thrust_limit_to_engine_group(100, urm_third_pair_engines).
  stage.
}

when urm_third_pair_fuel < 5000 then{
  print "Third urm pair decouple.".
  stage.
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
lock STEERING to HEADING(90, 90).
wait until SHIP:VERTICALSPEED > 30.

//set first_stage_tank_max_fuel to first_stage_tank:RESOURCES[1]:Amount.
wait 1.
set mysteer to SHIP:facing.
lock STEERING to mysteer.

print "Begin gravity turn".
set turnStartTime to TIME:SECONDS.
set turnDuration to 210. // 210 is work
set turnPitch to 90.
set turnSpeed to turnPitch / turnDuration.

until TIME:SECONDS - turnStartTime > turnDuration {
    set elapsedTime to TIME:SECONDS - turnStartTime.
    set TARGET_PITCH to 90 - turnSpeed * elapsedTime.
    set mysteer TO HEADING(90, TARGET_PITCH).
    
    print "Pitching to " + ROUND(TARGET_PITCH,0) + " degrees                 " AT(0,31).
    wait 0.1.
}

print "End gravity turn.".

print "Begin circularization.".
RCS on.
set eccOld to Orbit:ECCENTRICITY+10.
wait 1.
set Fi to 0.
lock STEERING to HEADING(90, -5).
lock THROTTLE to 1.
wait 2.
until (Orbit:ECCENTRICITY > eccOld)
{
  set Fi to f_Fi.
  if not (Fi = -1){
    lock STEERING to HEADING(90, MAX(MIN(Fi,90),-10)). 
    set eccOld to Orbit:ECCENTRICITY.   
  }  
  wait 0.01.
}

stage.
print "Complete.".
