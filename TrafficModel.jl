
module TrafficModel

import Dates
import DataFrames

mutable struct Car
  id::Int64
  lane_direction::String
  time_entered_lane::Dates.DateTime
end

# Use data frame channels so that async
# functions can read and write data to them.
const data_frame_channel = Channel{DataFrames.DataFrame}(1)

# Use channels to store the cars in the traffic lane
# waiting to get through the intersection.
# Channels were used so a populator and taker can
# both asynschronously can add/remove Cars.
const east_lane = Channel{Car}(1000)
const west_lane = Channel{Car}(1000)

# Conditions used for telling if a lane direction
# has the green light (allowing traffic in)
const east_lane_open = Condition()
const west_lane_open = Condition()

# Durations of simulation in seconds
const SIMULATION_DURATION = 60

# How long between red light switched
# should no traffic be going through
# the intersection in seconds
const RED_LIGHT_LATENCY = 2

function east_lane_taker()
  println("[East Lane Taker]: Started")
  starttime = time()

  while time() < starttime + SIMULATION_DURATION
    # Wait until a green light for lane
    wait(east_lane_open)

    # Remove the car 
    car = take!(east_lane)
    println("[East Lane Taker]: Taking $(car.id)")

    # In order to read data asynschronously,
    # we make an atomic transic by taking the dataframe
    # from the channel, writing to it, and putting it
    # back in the channel
    df = take!(data_frame_channel)
    push!(df, car.id)
    put!(data_frame_channel, df)
  end

  println("[East Lane Taker]: Ended")
end

function west_lane_taker()
  println("[West Lane Taker]: Started")
  
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    # Wait until a green light for lane
    wait(west_lane_open)

    # Remove the car
    car = take!(west_lane)
    println("[West Lane Taker]: Taking $(car.id)")

    # In order to read data asynschronously,
    # we make an atomic transic by taking the dataframe
    # from the channel, writing to it, and putting it
    # back in the channel
    # df = take!(data_frame_channel)
    # push!(df, car.id)
    # put!(data_frame_channel, df)
  end

  println("[West Lane Taker]: Ended")
end

function toggle_red_light()
  println("[Red Light Toggler]: Started")

  # Callback functions to let the lane takers
  # the lane is open / light is green
  cb_1(timer) = (notify(east_lane_open))
  cb_2(timer) = (notify(west_lane_open))
  
  # Which direction of traffic is open
  active_lane_num = 1

  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    if active_lane_num == 1
      t1 = Timer(cb_1, 3, interval=0.2)
      wait(t1)
      println("[Red Light Toggler]: East Lane Open")
      sleep(5)
      
      close(t1)
      active_lane_num = 2
    else
      t2 = Timer(cb_2, 3, interval=0.2)
      wait(t2)
      println("[Red Light Toggler]: West Lane Open")

      sleep(5)
      close(t2)
      active_lane_num = 1
    end
  end
  println("[Red Light Toggler]: Ended")
end

function east_lane_populator()
  println("[East Lane Populator]: Started")
  car_num = 1
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    exec_time = rand()
    sleep(2)
    println("[East Lane Populator]: Spawning Car #$(car_num)")
    
    spawned_car = Car(car_num, "East", Dates.now())
    put!(east_lane, spawned_car)
    car_num += 1
  end
  println("[East Lane Populator]: Ended")
end

function west_lane_populator()
  println("[West Lane Populator]: Started")
  car_num = 1
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    exec_time = rand()
    sleep(2)
    println("[West Lane Populator]: Spawning Car #$(car_num)")
    
    spawned_car = Car(car_num, "West", Dates.now())
    put!(west_lane, spawned_car)
    car_num += 1
  end
  println("[West Lane Populator]: Ended")
end

# Function to start all async workers
# Each async worker is set to run for
# SIMULATION_DURATION seconds
function simulation_runner()
  @async toggle_red_light()
  
  @async east_lane_populator()
  @async west_lane_populator()

  @async east_lane_taker()
  @async west_lane_taker()
end

function main()
  data = DataFrames.DataFrame(car_id = Int64[])

  # Initialize the data_frame_channel with
  # an empty dataframe so it may be populated
  # when cars make it through the intersection
  put!(data_frame_channel, data)

  sim_runner = @async simulation_runner()
end

end
