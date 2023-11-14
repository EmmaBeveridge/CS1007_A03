#!/usr/bin/env bash
#called from cmdln, creates a testbed in a container
#testbed runs other program files in nested containers by running testbed.sh

while getopts 'm:d:' flag; do
  case "${flag}" in
    m) commit_message="${OPTARG}" ;;
    d) pull_to_dir="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done


podman rm -f "testbed.container"
podman system prune --volumes
volume_name="testbed_volume"
program_files_source_path="/cs/studres/CS1007/Coursework/A03/programs/"
podman volume create "$volume_name"
volume_mount_point=$(podman volume inspect "$volume_name" --format "{{.Mountpoint}}")
echo "testbed mount point : $volume_mount_point"
cp testbed.sh "$volume_mount_point"
touch $volume_mount_point/testbed_log
touch $volume_mount_point/host_processes_log
#copy program files into testbed_volume/programs directory
cp -r $program_files_source_path $volume_mount_point
cp "program_containerfile" $volume_mount_point


podman build --file="testbed_containerfile" --tag="testbed.image" >> $volume_mount_point/testbed_log
podman run --rm --privileged --name="testbed.container" --volume="$volume_name:/volume" "testbed.image"


