def read_data
  global_time = 0
  global_cars = 0
  num_data_files = 0

  data_file_names = Dir.entries('.')
  data_file_names.each do |fname|
    if fname.start_with? "s"
      f = File.open(fname)
      data_string = f.read
      data_arr = data_string.split(", ")
      avg_time = data_arr[0].to_f
      num_cars = data_arr[1].to_f
      global_time += avg_time
      global_cars += num_cars
      num_data_files += 1
    end
  end

  puts "Average Time: #{global_time / num_data_files}"
  puts "Average Cars: #{global_cars / num_data_files}"
end

read_data