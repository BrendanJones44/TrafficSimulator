
module TrafficModel

import Dates
import DataFrames

mutable struct Car
  id::String
  time_entered_lane::Dates.DateTime
end

# Use data frame channels so that async
# functions can read and write data to them.
const data_frame_channel = Channel{DataFrames.DataFrame}(1)

# Use channels to store the cars in the traffic lane
# waiting to get through the intersection.
# Channels were used so a populator and taker can
# both asynschronously can add/remove Cars.
const traffic_lane_1 = Channel{Car}(32)
const traffic_lane_2 = Channel{Car}(32)

const lane_1_open = Condition()
const lane_2_open = Condition()

# Durations of simulation in seconds
const SIMULATION_DURATION = 60

# How long between red light switched
# should no traffic be going through
# the intersection in seconds
const RED_LIGHT_LATENCY = 2

function take_from_lane_1()
  println("Lane 1 Traffic Taker Started")
  starttime = time()

  while time() < starttime + SIMULATION_DURATION
    # Wait until a green light for lane
    wait(lane_1_open)

    # Remove the car 
    car = take!(traffic_lane_1)
    println("Taking $(car.id) from traffic lane 1")

    # In order to read data asynschronously,
    # we make an atomic transic by taking the dataframe
    # from the channel, writing to it, and putting it
    # back in the channel
    # df = take!(data_frame_channel)
    # push!(df, car.id)
    # put!(data_frame_channel, df)
  end

  println("Lane 1 Traffic Taker Ended")
end

function take_from_lane_2()
  println("Lane 2 Traffic Taker Started")
  
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    # Wait until a green light for lane
    wait(lane_2_open)

    # Remove the car
    car = take!(traffic_lane_2)
    println("Taking $(car.id) from traffic lane 2")

    # In order to read data asynschronously,
    # we make an atomic transic by taking the dataframe
    # from the channel, writing to it, and putting it
    # back in the channel
    # df = take!(data_frame_channel)
    # push!(df, car.id)
    # put!(data_frame_channel, df)
  end

  println("Lane 2 Traffic Taker Ended")
end

function toggle_red_light()
  println("Red Light Toggler Started")

  # Callback functions to let the lane takers
  # the lane is open / light is green
  cb_1(timer) = (notify(lane_1_open))
  cb_2(timer) = (notify(lane_2_open))
  
  # Which direction of traffic is open
  active_lane_num = 1

  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    if active_lane_num == 1
      t1 = Timer(cb_1, 3, interval=0.2)
      wait(t1)
      println("Traffic is now open to lane 1")
      sleep(5)
      
      close(t1)
      active_lane_num = 2
    else
      t2 = Timer(cb_2, 3, interval=0.2)
      wait(t2)
      println("Traffic is now open to lane 2")

      sleep(5)
      close(t2)
      active_lane_num = 1
    end
  end
  println("Red Light Toggler Ended")
end

function populate_lane_1()
  println("Lane 1 Populator Started")
  car_num = 1
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    car_id = "E-$(car_num)"
    exec_time = rand()
    sleep(2)
    println("Putting $(car_id) in lane 1")
    
    spawned_car = Car(car_id, Dates.now())
    put!(traffic_lane_1, spawned_car)
    car_num += 1
  end
  println("Lane 1 Populator Ended")
end

function populate_lane_2()
  println("Lane 2 Populator Started")
  car_num = 0
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    car_id = "W-$(car_num)"
    exec_time = rand()
    sleep(2)
    println("Putting $(car_id) in lane 2")
    
    spawned_car = Car(car_id, Dates.now())
    put!(traffic_lane_2, spawned_car)
    car_num += 1
  end
  println("Lane 2 Populator Ended")
end

# Function to start all async workers
# Each async worker is set to run for
# SIMULATION_DURATION seconds
function simulation_runner()
  @async toggle_red_light()
  
  @async populate_lane_1()
  @async populate_lane_2()

  @async take_from_lane_1()
  @async take_from_lane_2()
end

function main()
  data = DataFrames.DataFrame(car_id = String[])

  # Initialize the data_frame_channel with
  # an empty dataframe so it may be populated
  # when cars make it through the intersection
  put!(data_frame_channel, data)

  sim_runner = @async simulation_runner()
end

end
