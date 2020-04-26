
module TrafficModel

# We need to figure out how long a car waits
# BUT we also need to have that time be 0 if traffic is flowing


# Cases to consider:
# 1) Traffic is flowing normally, all cars 0 wait time
# 2) Traffic is stopped, then light turns green, cars each wait at different times (accelerate by increasing sleep each time)
# 3) Light turns green, there were some cars waiting, the cars being spawned have a small wait time (to let the cars go through)


import Dates

mutable struct Car
  id::Int64
  time_entered_lane::Dates.DateTime
  time_exited_lane::Dates.DateTime
end

const traffic_lane_1 = Channel{Car}(32)
const traffic_lane_2 = Channel{Car}(32)

const lane_1_open = Condition()
const lane_2_open = Condition()

function take_from_lane_1()
  println("Starting lane 1 taking")
  while true
    wait(lane_1_open)
    car = take!(traffic_lane_1)
    println("Taking $(car.id) from traffic lane 1")
  end
end

function take_from_lane_2()
  while true  
    wait(lane_2_open)
    car = take!(traffic_lane_2)
    println("Taking $(car.id) from traffic lane 2")
  end
end

function toggle_red_light()
  cb_1(timer) = (notify(lane_1_open))
  cb_2(timer) = (notify(lane_2_open))
  
  active_lane_num = 1

  while true
    if active_lane_num == 1
      println("Traffic is now open to lane 1")
      t1 = Timer(cb_1, 5, interval=0.2)
      wait(t1)
      sleep(0.5)
      close(t1)
      active_lane_num = 2
    else
      println("Traffic is now open to lane 2")
      t2 = Timer(cb_2, 5, interval=0.2)
      wait(t2)
      sleep(0.5)
      close(t2)
      active_lane_num = 1
    end
  end
end

function populate_lane_1()
  car_id = 1
  while car_id < 21
    exec_time = rand()
    sleep(2)
    println("Putttng $(car_id) in lane 1")
    
    spawned_car = Car(car_id, Dates.now(), Dates.now())
    put!(traffic_lane_1, spawned_car)
    car_id += 2
  end
end

function populate_lane_2()
  car_id = 0
  while car_id < 21
    exec_time = rand()
    sleep(2)
    println("Putttng $(car_id) in lane 2")
    
    spawned_car = Car(car_id, Dates.now(), Dates.now())
    put!(traffic_lane_2, spawned_car)
    car_id += 2
  end
end

function main()
  @async toggle_red_light()
  
  @async populate_lane_1()
  @async populate_lane_2()

  @async take_from_lane_1()
  @async take_from_lane_2()
end

end
