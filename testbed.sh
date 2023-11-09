#!/usr/bin/env bash

#this file runs in testbed container and creates nested containers to run each program.

echo "in testbed!!"

file_to_modify_name="file_to_modify"
stats_dir_name="run_stats"

log_file_name="container_log"
result_dir_path="/results"
programs_dir_path="/volume/programs"

program_file_names=$(ls $programs_dir_path)
mkdir $result_dir_path

while IFS= read -r program_file_name; do

    mkdir $result_dir_path/$program_file_name
 
    podman volume create "$program_file_name" >>"$program_volume_mount_point/$log_file_name"
    program_volume_mount_point=$(podman volume inspect "$program_file_name" --format "{{.Mountpoint}}")
    mkdir $program_volume_mount_point/$stats_dir_name #Create folder to store stats output for container runs
    touch $program_volume_mount_point/$file_to_modify_name #Create file for program to modify, provided as CL argument to program
    touch $program_volume_mount_point/$log_file_name       #Create file to write container log output to
    podman build --build-arg=program_file_name="$program_file_name" --build-arg=file_to_modify_path="/volume/$file_to_modify_name" --file="/volume/program_containerfile" --tag="program.image" >>"$program_volume_mount_point/$log_file_name"
    container_name="$program_file_name.container"

    

    for ((i = 0; i < 20; i++)); do
        stats_file_path=$program_volume_mount_point/$stats_dir_name/run_$i.csv
        echo "AverageCPU,MemoryPercentageUsed" > $stats_file_path                                                                    #Create file to write container resource usage statistics to
        podman run -d --rm --volume="$program_volume_mount_point:/volume" --name=$container_name "program.image" >>"$program_volume_mount_point/$log_file_name" #Run container in background (-d)
        while [[ "$(podman ps -a | grep $container_name)" ]]; do                                                                                                #collect stats while container is running
            podman stats --format "{{.AVGCPU}},{{.MemPerc}}" --interval=1 "$container_name" 1>> "$stats_file_path" 2>/dev/null
        done
        echo "Completed $program_file_name run $i"
    done
    echo "Copying $program_volume_mount_point/{$stats_dir_name, $log_file_name}  ---> $result_dir_path/$program_file_name" >>"$program_volume_mount_point/$log_file_name"
    cp -rp $program_volume_mount_point/$stats_dir_name $result_dir_path/$program_file_name
    cp -p $program_volume_mount_point/$log_file_name $result_dir_path/$program_file_name
    echo "done $program_file_name"

done <<<"$program_file_names"

cp -rp $result_dir_path "/volume"
