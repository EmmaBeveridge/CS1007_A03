#!/usr/bin/env bash

#this file runs in testbed container and creates nested containers to run each program.

function usage () {
  echo "usage: $0 [-t] [-p cpu-upper] [-m cpu-lower] [-c cpu-increment] [-s RAM-upper] [-r RAM-lower] [-i RAM-increment]"
  echo "-t  : Generate time-series statistics"
  echo "-p  : Upper limit for CPU allocated to containers"
  echo "-m  : Lower limit for CPU allocated to containers"
  echo "-c  : CPU limit increment, defaults to 0.05"
  echo "-s  : Upper limit for memory allocated to containers"
  echo "-r  : Lower limit for memory allocated to containers"
  echo "-i  : Memory limit increment, defaults to 100MB"
  exit 1;

}



#PROCESS OPTIONS
time_series=0
peak_cpu=-1
mean_cpu=1
cpu_increment=0.05
ram_lower=-1
ram_upper=-1
ram_increment=100


while getopts 'tp:m:c:r:s:i:' flag; do
  case "${flag}" in
    p) peak_cpu="${OPTARG}" ;;
    m) mean_cpu="${OPTARG}"  ;;
    c) cpu_increment="${OPTARG}" ;;
    r) ram_lower="${OPTARG}" ;;
    s) ram_upper="${OPTARG}" ;;
    i) ram_increment="${OPTARG}" ;;
    t) time_series=1 ;;
    *) usage ;;
  esac
done


#DIRECTORY/LOG MANAGEMENT
file_to_modify_name="file_to_modify"
stats_dir_name="run_stats"

log_file_name="container_log"
result_dir_path="/results"
mkdir $result_dir_path
programs_dir_path="/volume/programs"
program_file_names=$(ls $programs_dir_path)


#ITERATE OVER PROGRAMS TO TEST
while IFS= read -r program_file_name; do

    mkdir $result_dir_path/$program_file_name
 
    #CREATE VOLUME
    podman volume create "$program_file_name" >>"$program_volume_mount_point/$log_file_name"
    program_volume_mount_point=$(podman volume inspect "$program_file_name" --format "{{.Mountpoint}}")
    
    mkdir $program_volume_mount_point/$stats_dir_name #Create folder to store stats output for container runs
    touch $program_volume_mount_point/$file_to_modify_name #Create file for program to modify, provided as CL argument to program
    touch $program_volume_mount_point/$log_file_name       #Create file to write container log output to
    
    #BUILD CONTAINER
    podman build --build-arg=program_file_name="$program_file_name" --build-arg=file_to_modify_path="/volume/$file_to_modify_name" --file="/volume/program_containerfile" --tag="program.image" >>"$program_volume_mount_point/$log_file_name"
    container_name="$program_file_name.container"

    #WRITE HOST MACHINE STATS TO FILE
    echo "Host Machine Stats" >> $program_volume_mount_point/$stats_dir_name/host_stats.txt
    lscpu >> $program_volume_mount_point/$stats_dir_name/host_stats.txt #get host device stats
    
    if [[ $time_series == 1 ]]; then
        
        #MAKE STATS DIRECTORY
        mkdir $program_volume_mount_point/$stats_dir_name/time_series_stats
        #RUN CONTAINER MULTIPLE TIMES
        for ((i = 0; i < 20; i++)); do
            stats_file_path=$program_volume_mount_point/$stats_dir_name/time_series_stats/run_$i.csv
            echo "CPU,MemUsage" > $stats_file_path #Create file to write container resource usage statistics to
            podman run -d --rm --volume="$program_volume_mount_point:/volume" --name=$container_name "program.image" >>"$program_volume_mount_point/$log_file_name" #Run container in background (-d)
            podman stats --format "{{.CPU}},{{.MemUsage}}" --interval=1 "$container_name" 2>/dev/null | sed -e 's;/.*;;g' -e 's;kB;e+03;g' -e 's;MB;e+06;g' -e 's;GB;e+09;g' -e 's;B;;g' 1>> "$stats_file_path"
            echo "Completed $program_file_name run $i" | tee -a "$program_volume_mount_point/$log_file_name"
        done
    fi
    if [[ $peak_cpu != -1 ]]; then
        #MAKE STATS DIRECTORY
        mkdir $program_volume_mount_point/$stats_dir_name/execution_times_CPU_limited

        #RUN FOR DIFFERENT CPU LIMITS
        for cpu_limit in `seq $mean_cpu $cpu_increment $peak_cpu`; do         
            
            echo "Limit $cpu_limit"
            
            execution_time_stats_file_path=$program_volume_mount_point/$stats_dir_name/execution_times_CPU_limited/CPUPerc_$cpu_limit.csv
            echo "ExecutionTime,CPULimit" > $execution_time_stats_file_path #Create file to write container resource usage statistics to        
            echo "NA,$cpu_limit" >> $execution_time_stats_file_path
            

            #REPEATS
            for ((i = 0; i < 3; i++)); do

                #RUN WITH CPU LIMITS
                podman run --cpus=$cpu_limit --volume="$program_volume_mount_point:/volume" --name=$container_name "program.image" >>"$program_volume_mount_point/$log_file_name" #Run container in background (-d)               
                
                
                #CALCULATE EXECUTION TIME
                start=$(podman inspect $container_name --type container --format "{{.State.StartedAt}}")
                start_seconds=$(date --date "$(echo $start | sed 's;[A-Z];;g')" +"%s.%3N")
                finish=$(podman inspect $container_name --type container --format "{{.State.FinishedAt}}")
                finish_seconds=$(date --date "$(echo $finish | sed 's;[A-Z];;g')" +"%s.%3N")
                echo "Start: $start_seconds, Finish $finish_seconds"
                execution_time=$(echo "$finish_seconds-$start_seconds"|bc)
                
                echo "$execution_time" >> $execution_time_stats_file_path
                #REMOVE CONTAINER
                podman rm $container_name
                echo "Completed $program_file_name run $i at $cpu_limit" | tee -a "$program_volume_mount_point/$log_file_name"
            done
        done

    fi  
    if [[ $ram_lower != -1 ]]; then
        mkdir $program_volume_mount_point/$stats_dir_name/execution_times_memory_limited
        
        #RUN FOR DIFFERENT RAM LIMITS
        for ram_limit in `seq $ram_lower $ram_increment $ram_upper`; do       
            echo "Limit $ram_limit"
            
            execution_time_stats_file_path=$program_volume_mount_point/$stats_dir_name/execution_times_memory_limited/memorylimit_$ram_limit.csv
            echo "ExecutionTime,MemoryLimit" > $execution_time_stats_file_path #Create file to write container resource usage statistics to        
            echo "NA,$ram_limit" >> $execution_time_stats_file_path
            
            #REPEATS
            for ((i = 0; i < 3; i++)); do

                #RUN WITH RAM LIMITS
                podman run --memory="${ram_limit}M" --memory-swap=-1 --volume="$program_volume_mount_point:/volume" --name=$container_name "program.image" >>"$program_volume_mount_point/$log_file_name" #Run container in background (-d)               
                
                
                #CALCULATE EXECUTION TIME
                start=$(podman inspect $container_name --type container --format "{{.State.StartedAt}}")
                start_seconds=$(date --date "$(echo $start | sed 's;[A-Z];;g')" +"%s.%3N")
                finish=$(podman inspect $container_name --type container --format "{{.State.FinishedAt}}")
                finish_seconds=$(date --date "$(echo $finish | sed 's;[A-Z];;g')" +"%s.%3N")
                execution_time=$(echo "$finish_seconds-$start_seconds"|bc)               
                echo "Time: $execution_time"
                
                echo "$execution_time" >> $execution_time_stats_file_path
                #REMOVE CONTAINER
                podman rm $container_name
                echo "Completed $program_file_name run $i at $ram_limit" | tee -a "$program_volume_mount_point/$log_file_name"
            done
        done
    fi  
        
    
    echo "Copying $program_volume_mount_point/{$stats_dir_name, $log_file_name}  ---> $result_dir_path/$program_file_name" >>"$program_volume_mount_point/$log_file_name"
    cp -rp $program_volume_mount_point/$stats_dir_name $result_dir_path/$program_file_name
    cp -p $program_volume_mount_point/$log_file_name $result_dir_path/$program_file_name

done <<<"$program_file_names"

#COPY FILES TO TESTBED PERSISTENT VOLUME
cp -rp $result_dir_path "/volume"