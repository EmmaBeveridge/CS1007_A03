#!/usr/bin/env bash
#called from cmdln, creates a testbed in a container
#testbed runs other program files in nested containers by running testbed.sh


function usage () {
  echo "usage: $0 [-t] [-p cpu-upper] [-m cpu-lower] [-c cpu-increment] [-s RAM-upper] [-r RAM-lower] [-i RAM-increment] [-n program-name]"
  echo "-t  : Generate time-series statistics"
  echo "-p  : Upper limit for CPU allocated to containers"
  echo "-m  : Lower limit for CPU allocated to containers"
  echo "-c  : CPU limit increment, defaults to 0.05"
  echo "-s  : Upper limit for memory allocated to containers"
  echo "-r  : Lower limit for memory allocated to containers"
  echo "-i  : Memory limit increment, defaults to 100MB"
  echo "-n  : Name of program to test, defaults to all programs in /cs/studres/CS1007/Coursework/A03/programs/ directory"
  exit 1;

}




#PROCESS OPTIONS
time_series="" 
cpu_upper=""
cpu_lower=""
cpu_increment=""
program_to_test=""
ram_upper="" #RAM IN MB
ram_lower=""
ram_increment=""
while getopts 'tp:m:c:s:r:i:n:' flag; do
  case "${flag}" in
    p) cpu_upper="-p ${OPTARG} " ;;
    m) cpu_lower="-m ${OPTARG} " ;;
    c) cpu_increment="-c ${OPTARG} " ;;
    s) ram_upper="-s ${OPTARG} " ;;
    r) ram_lower="-r ${OPTARG} " ;;
    i) ram_increment="-i ${OPTARG} " ;;
    n) program_to_test="${OPTARG}" ;;
    t) time_series="-t " ;;
    *) usage ;;
  esac
done


podman system reset

#CREATE VOLUMES
volume_name="testbed_volume"
program_files_source_path="/cs/studres/CS1007/Coursework/A03/programs/"
podman volume create "$volume_name"
volume_mount_point=$(podman volume inspect "$volume_name" --format "{{.Mountpoint}}")
echo "testbed mount point : $volume_mount_point"
cp testbed.sh "$volume_mount_point"
touch $volume_mount_point/testbed_log
touch $volume_mount_point/host_processes_log


#copy program files into testbed_volume/programs directory
if [[ "$program_to_test" != "" ]]; then
    
    if [ -f "$program_files_source_path$program_to_test" ]; then
      echo "Testing $program_files_source_path$program_to_test"
      mkdir $volume_mount_point/programs
      cp $program_files_source_path$program_to_test $volume_mount_point/programs    
    else
        echo "Error: program $program_files_source_path$program_to_test does not exist"
        usage
    fi
else
    echo "Testing all programs in $program_files_source_path"
    cp -r $program_files_source_path $volume_mount_point
fi




cp "program_containerfile" $volume_mount_point

#BUILD AND RUN TESTBED CONTAINER
podman build --file="testbed_containerfile" --tag="testbed.image" --build-arg=time_series="$time_series" --build-arg=cpu_upper="$cpu_upper" --build-arg=cpu_lower="$cpu_lower" --build-arg=cpu_increment="$cpu_increment" --build-arg=ram_lower="$ram_lower" --build-arg=ram_upper="$ram_upper" --build-arg=ram_increment="$ram_increment" >> $volume_mount_point/testbed_log
podman run --rm --privileged --name="testbed.container" --volume="$volume_name:/volume" "testbed.image"


