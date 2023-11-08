#!/usr/bin/env bash

#this file runs in container and creates nested containers to run each program.

echo "in testbed!!"

file_to_modify_name="file_to_modify"
stats_file_name="stats.csv"
log_file_name="container_log"
result_dir_path="/results"
programs_dir_path="/volume/programs"

program_file_names=$(ls $programs_dir_path)
mkdir $result_dir_path


while IFS= read -r program_file_name; do
    mkdir $result_dir_path/$program_file_name

    podman volume create "$program_file_name" >> "$program_volume_mount_point/$log_file_name"
    program_volume_mount_point=$(podman volume inspect "$program_file_name" --format "{{.Mountpoint}}")
    
    touch -d "2 hours ago" $program_volume_mount_point/$file_to_modify_name #Create file for program to modify, provided as CL argument to program
    echo "AverageCPU,MemoryPercentageUsed">$program_volume_mount_point/$stats_file_name #Create file to write container resource usage statistics to
    touch $program_volume_mount_point/$log_file_name #Create file to write container log output to
    
    
    podman build --build-arg=program_file_name="$program_file_name" --build-arg=file_to_modify_path="/volume/$file_to_modify_name" --file="/volume/program_containerfile" --tag="program.image" >> "$program_volume_mount_point/$log_file_name"
    #echo "Built image"
    #podman run --volume="$program_file_name:/volume" "program.image"
    
    container_name="$program_file_name.container"
    podman run -d --rm --volume="$program_volume_mount_point:/volume" --name=$container_name "program.image" >> "$program_volume_mount_point/$log_file_name"

    while [[ "$(podman ps -a | grep $container_name)" ]]; do
        podman stats --format "{{.AVGCPU}},{{.MemPerc}}" --interval=1 "$container_name" 1>> "$program_volume_mount_point/$stats_file_name" 2>/dev/null
    done
    echo "Copying $program_volume_mount_point/{$stats_file_name, $log_file_name}  ---> $result_dir_path/$program_file_name" >> "$program_volume_mount_point/$log_file_name"
    cp -p $program_volume_mount_point/$stats_file_name $result_dir_path/$program_file_name
    cp -p $program_volume_mount_point/$log_file_name $result_dir_path/$program_file_name

    echo "done $program_file_name"
    
done <<< "$program_file_names"

cp -rp $result_dir_path "/volume"


