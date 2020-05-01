
module TrafficModel

import Dates
import DataFrames

mutable struct Car
  id::Int64
  lane_direction::String
  time_entered_lane::Float64
end

# Use data frame channels so that async
# functions can read and write data to them.
# NOTE: While the async functions could share one 
# dataframe channel, when one is reading/writing to it
# any other readers/writers are blocked. Therefore,
# seperate channels are used to minimize latency/blocking
const east_lane_data_channel = Channel{DataFrames.DataFrame}(1)
const west_lane_data_channel = Channel{DataFrames.DataFrame}(1)

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
const SIMULATION_DURATION = 20

# How long between red light switched
# should no traffic be going through
# the intersection in seconds
const RED_LIGHT_LATENCY = 2

# When the light turns green, how long should
# it take for each car to accelerate and make
# it through tht intersection
const TIME_BETWEEN_CARS = 0.2

function east_lane_taker()
  println("[East Lane Taker]: Started")
  starttime = time()

  while time() < starttime + SIMULATION_DURATION
    # Wait until a green light for lane
    wait(east_lane_open)

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
    wait(west_lane_open)

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
      t1 = Timer(cb_1, 3, interval=TIME_BETWEEN_CARS)
      wait(t1)
      println("[Red Light Toggler]: East Lane Open")
      sleep(5)
      
      close(t1)
      active_lane_num = 2
    else
      t2 = Timer(cb_2, 3, interval=TIME_BETWEEN_CARS)
      wait(t2)
      println("[Red Light Toggler]: West Lane Open")

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
  east_lane_data = DataFrames.DataFrame(car_id = Int64[], duration_in_lane = Float64[])
  west_lane_data = DataFrames.DataFrame(car_id = Int64[], duration_in_lane = Float64[])

  # Initialize the data frame channels with
  # an empty dataframe so it may be populated
  # when cars make it through the intersection
  put!(east_lane_data_channel, east_lane_data)
  put!(west_lane_data_channel, west_lane_data)

  sim_runner = @async simulation_runner()
end

end
