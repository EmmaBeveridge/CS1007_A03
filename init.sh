#!/usr/bin/env bash
#called from cmdln, creates a testbed in a container
#testbed runs other program files in nested containers by running testbed.sh
volume_name="testbed_volume"
program_files_source_path="/cs/studres/CS1007/Coursework/A03/programs/"
#program_files_source_path="programs/"
podman volume create "$volume_name"
volume_mount_point=$(podman volume inspect "$volume_name" --format "{{.Mountpoint}}")
echo "testbed mount point : $volume_mount_point"
cp testbed.sh "$volume_mount_point"

#copy program files into testbed_volume/programs directory
cp -r $program_files_source_path $volume_mount_point
cp "program_containerfile" $volume_mount_point
echo $(ls $volume_mount_point)
podman build --file="testbed_containerfile" --tag="testbed.image"
podman run --rm --privileged --volume="$volume_name:/volume" "testbed.image"
#podman run -it --privileged --volume="$volume_name:/volume" "testbed.image"