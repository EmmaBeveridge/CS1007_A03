#!/usr/bin/env bash

#this file runs in container and creates nested containers to run each program.




#pod_ID=$(podman pod create) #Create pod to run containers in
#podman volume create program_file_volume #Create volume to store program files
#can we associate volume with this pod??

#volume_name="testbed_volume"
#podman volume create "$volume_name"
#volume_mount_point=$(podman volume inspect "$volume_name" --format "{{.Mountpoint}}")

echo "in testbed!!"

#program_files_source_path="/cs/studres/CS1007/Coursework/A03/programs/"
#program_file_names=$(ls "$program_files_source_path")

#run container for each program
#TODO: 
#create a new image for each of the programs which will run that specific program 
#create a volume for each of the programs (name it with name of program+volume?) in a specified directory so can access later
#create and copy file for program to work on into container
#copy program file into container in containerfile from program_files_source_path
#run the program with the 




#give each program its own volume within testbed /var/lib/containers/storage/volume/$program_name :  record file path of volume created
#copy modfile into of program's volume 
#let program run give path to modfile in volume as arg
#then copy programs modfile back into a folder in testbed container
#analyse 
#write a summary file to volume folder in testbed container

file_to_modify_name="file_to_modify"
result_dir_path="/results"
programs_dir_path="/volume/programs"

program_file_names=$(ls $programs_dir_path)
mkdir $result_dir_path


while IFS= read -r program_file_name; do
    mkdir $result_dir_path/$program_file_name

    podman volume create "$program_file_name"
    program_volume_mount_point=$(podman volume inspect "$program_file_name" --format "{{.Mountpoint}}")
    
    touch -d "2 hours ago" $program_volume_mount_point/$file_to_modify_name
    echo "Created $program_volume_mount_point/$file_to_modify_name"
    
    podman build --build-arg=program_file_name="$program_file_name" --build-arg=file_to_modify_path="/volume/$file_to_modify_name" --file="/volume/program_containerfile" --tag="program.image"
    echo "Built image"
    #podman run --volume="$program_file_name:/volume" "program.image"
    
    container_name="$program_file_name.container"

    podman run -d --rm --volume="$program_volume_mount_point:/volume" --name=$container_name "program.image" 
    #container_ID=$(podman inspect "$container_name" --format "{{.Id}}")
    while [[ "$(podman ps -a | grep $container_name)" ]]; do
        podman stats "$container_name";
    done
    echo "Copying $program_volume_mount_point/$file_to_modify_name ---> $result_dir_path/$program_file_name"
    cp -p $program_volume_mount_point/$file_to_modify_name $result_dir_path/$program_file_name
    echo "done $program_file_name"
done <<< "$program_file_names"

cp -rp $result_dir_path "/volume"


