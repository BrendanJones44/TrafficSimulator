
module TrafficModel

import CSV
import Dates
import DataFrames

# Data structure used to represent Cars
# being in the various lanes.
mutable struct Car
  id::Int64
  lane_direction::String
  time_entered_lane::Float64
end

# Data structure used to modify the parameters
# to the model's traffic.
struct ModelParams
  rseed::Int64
  east_lane_population_coefficient::Float64
  west_lane_population_coefficient::Float64
  south_lane_population_coefficient::Float64
  east_west_lane_green_light_time::Float64
  south_lane_green_light_time::Float64
end

# Use data frame channels so that async
# functions can read and write data to them.
# NOTE: While the async functions could share one 
# dataframe channel, when one is reading/writing to it
# any other readers/writers are blocked. Therefore,
# seperate channels are used to minimize latency/blocking
const east_lane_data_channel = Channel{DataFrames.DataFrame}(1)
const west_lane_data_channel = Channel{DataFrames.DataFrame}(1)
const south_lane_data_channel = Channel{DataFrames.DataFrame}(1)

# Use channels to store the cars in the traffic lane
# waiting to get through the intersection.
# Channels were used so a populator and taker can
# both asynschronously can add/remove Cars.
const east_lane = Channel{Car}(1000)
const west_lane = Channel{Car}(1000)
const south_lane = Channel{Car}(1000)

# Conditions used for telling if a lane direction
# has the green light (allowing traffic in)
const east_west_lanes_open = Condition()
const south_lane_open = Condition()

# Durations of simulation in seconds
const SIMULATION_DURATION = 20

# How long between red light switched
# should no traffic be going through
# the intersection in seconds
const RED_LIGHT_LATENCY = 2

# When the light turns green, how long should
# it take for each car to accelerate and make
# it through tht intersection
const TIME_BETWEEN_CARS = 0.5

function east_lane_taker()
  println("[East Lane Taker]: Started")
  starttime = time()

  while time() < starttime + SIMULATION_DURATION
    # Wait until a green light for lane
    wait(east_west_lanes_open)

    # Remove the car and calculate time in lane
    car = take!(east_lane)
    time_car_was_taken = time()
    elapsed_seconds = time_car_was_taken - car.time_entered_lane
    println("[East Lane Taker]: Taking $(car.id). Elapsed time: $(elapsed_seconds)")

    # In order to read data asynschronously,
    # we make an atomic transic by taking the dataframe
    # from the channel, writing to it, and putting it
    # back in the channel
    df = take!(east_lane_data_channel)
    push!(df, [car.id, elapsed_seconds])
    put!(east_lane_data_channel, df)
  end

  println("[East Lane Taker]: Ended")
end

function west_lane_taker()
  println("[West Lane Taker]: Started")
  
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    # Wait until a green light for lane
    wait(east_west_lanes_open)

    # Remove the car and calculate time in lane
    car = take!(west_lane)
    time_car_was_taken = time()
    elapsed_seconds = time_car_was_taken - car.time_entered_lane
    println("[West Lane Taker]: Taking $(car.id). Elapsed time: $(elapsed_seconds)")

    # In order to read data asynschronously,
    # we make an atomic transic by taking the dataframe
    # from the channel, writing to it, and putting it
    # back in the channel
    df = take!(west_lane_data_channel)
    push!(df, [car.id, elapsed_seconds])
    put!(west_lane_data_channel, df)
  end

  println("[West Lane Taker]: Ended")
end

function south_lane_taker()
  println("[South Lane Taker]: Started")
  
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    # Wait until a green light for lane
    wait(south_lane_open)

    # Remove the car and calculate time in lane
    car = take!(south_lane)
    time_car_was_taken = time()
    elapsed_seconds = time_car_was_taken - car.time_entered_lane
    println("[South Lane Taker]: Taking $(car.id). Elapsed time: $(elapsed_seconds)")

    # In order to read data asynschronously,
    # we make an atomic transic by taking the dataframe
    # from the channel, writing to it, and putting it
    # back in the channel
    df = take!(south_lane_data_channel)
    push!(df, [car.id, elapsed_seconds])
    put!(south_lane_data_channel, df)
  end

  println("[South Lane Taker]: Ended")
end

function red_light_toggler()
  println("[Red Light Toggler]: Started")

  # Callback functions to let the lane takers
  # the lane is open / light is green
  cb_1(timer) = (notify(east_west_lanes_open))
  cb_2(timer) = (notify(south_lane_open))
  
  # Which direction of traffic is open
  active_lane_num = 1

  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    if active_lane_num == 1
      t1 = Timer(cb_1, 3, interval=TIME_BETWEEN_CARS)
      wait(t1)
      println("[Red Light Toggler]: East/West Lane Open")
      sleep(5)
      
      close(t1)
      active_lane_num = 2
    else
      t2 = Timer(cb_2, 3, interval=TIME_BETWEEN_CARS)
      wait(t2)
      println("[Red Light Toggler]: South Lane Open")

      sleep(5)
      close(t2)
      active_lane_num = 1
    end
  end
  println("[Red Light Toggler]: Ended")

  # Give other functions 3 seconds to complete
  sleep(3)

  println("#### East Lane Data ####")
  east_df = take!(east_lane_data_channel)
  println(east_df)

  println("#### West Lane Data ####")
  west_df = take!(west_lane_data_channel)
  println(west_df)

  println("#### South Lane Data ####")
  south_df = take!(south_lane_data_channel)
  println(south_df)
end

function east_lane_populator()
  println("[East Lane Populator]: Started")
  car_num = 1
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    exec_time = rand() * 2
    sleep(exec_time)
    println("[East Lane Populator]: Spawning Car #$(car_num)")
    
    spawned_car = Car(car_num, "East", time())
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
    exec_time = rand() * 2
    sleep(exec_time)
    println("[West Lane Populator]: Spawning Car #$(car_num)")
    
    spawned_car = Car(car_num, "West", time())
    put!(west_lane, spawned_car)
    car_num += 1
  end
  println("[West Lane Populator]: Ended")
end

function south_lane_populator()
  println("[South Lane Populator]: Started")
  car_num = 1
  starttime = time()
  while time() < starttime + SIMULATION_DURATION
    exec_time = rand() * 2
    sleep(exec_time)
    println("[South Lane Populator]: Spawning Car #$(car_num)")
    
    spawned_car = Car(car_num, "South", time())
    put!(south_lane, spawned_car)
    car_num += 1
  end
  println("[South Lane Populator]: Ended")
end

# Function to start all async workers
# Each async worker is set to run for
# SIMULATION_DURATION seconds
function simulation_runner()
  model_params = init_model_params()

  @async red_light_toggler()
  
  @async south_lane_populator()
  @async east_lane_populator()
  @async west_lane_populator()

  @async south_lane_taker()
  @async east_lane_taker()
  @async west_lane_taker()
end

# Modify this function to modify the parameters
# given to the model.
function init_model_params()
  ModelParams(
    1, # rseed
    2, # east_lane_population_coefficient
    2, # west_lane_population_coefficient
    2, # south_lane_population_coefficient
    5, # east_west_lane_green_light_time,
    5  # south_lane_green_light_time
  )
end

function main()
  east_lane_data = DataFrames.DataFrame(car_id = Int64[], duration_in_lane = Float64[])
  west_lane_data = DataFrames.DataFrame(car_id = Int64[], duration_in_lane = Float64[])
  south_lane_data = DataFrames.DataFrame(car_id = Int64[], duration_in_lane = Float64[])

  # Initialize the data frame channels with
  # an empty dataframe so it may be populated
  # when cars make it through the intersection
  put!(east_lane_data_channel, east_lane_data)
  put!(west_lane_data_channel, west_lane_data)
  put!(south_lane_data_channel, south_lane_data)

  sim_runner = @async simulation_runner()
end

end
