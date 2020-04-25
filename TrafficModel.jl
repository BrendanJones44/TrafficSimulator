
module TrafficModel

const jobs = Channel{Int}(32)

const traffic_lane_active = Channel{Int}(1)

const traffic_lane_1 = Channel{Int}(32)
const traffic_lane_2 = Channel{Int}(32)

const lane_1_open = Condition()
const lane_2_open = Condition()


function take_from_lane_1()
  println("Starting lane 1 taking")
  while true
    wait(lane_1_open)
    job_id = take!(traffic_lane_1)
    println("Taking $(job_id) from traffic lane 1")
  end
end

function take_from_lane_2()
  println("Starting lane 1 taking")
  while true  
    wait(lane_2_open)
    job_id = take!(traffic_lane_2)
    println("Taking $(job_id) from traffic lane 2")
  end
end

function toggle_red_light()
  cb_1(timer) = (notify(lane_1_open))
  

  cb_2(timer) = (notify(lane_2_open))
  t2 = Timer(cb_2, 2, interval=0.2)
  
  active_lane_num = 1

  while true
    if active_lane_num == 1
      t1 = Timer(cb_1, 2, interval=0.2)
      wait(t1)
      sleep(0.5)
      close(t1)
      active_lane_num = 2
    else
      t2 = Timer(cb_2, 2, interval=0.2)
      wait(t2)
      sleep(0.5)
      close(t2)
      active_lane_num = 1
    end
  end
end

function populate_traffic_lanes_1()
  for job_id in jobs
    exec_time = rand()
    sleep(exec_time)
    
    if job_id % 2 == 0
      println("Putttng $(job_id) in lane 1")
      put!(traffic_lane_1, job_id)
    else
      println("Putttng $(job_id) in lane 2")
      put!(traffic_lane_2, job_id)
    end
  end
end

function make_jobs(n)
  for i in 1:n
      put!(jobs, i)
  end
end

function main()
  @async toggle_red_light()
  @async make_jobs(10)

  for i in 1:2
    @async populate_traffic_lanes()
  end

  @async take_from_lane_1()
  @async take_from_lane_2()
end

end
