#!/bin/bash
while getopts ":p:s:" opt; do
  case $opt in
    p)
      echo "Using desktop directory: $OPTARG"
      export DESKTOP_PROJECT_DIR=$OPTARG 
      ;;
    s)
      echo "Using desktop setting directory: $OPTARG"
      export DESKTOP_SETTINGS_DIR=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

ansible-playbook -v -i "localhost," -c local provdesktop.yml 
