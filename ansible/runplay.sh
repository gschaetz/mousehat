#!/bin/bash
verbosity="v"
while getopts ":p:s:v:" opt; do
  case $opt in
    v)
      echo "verbosity being set to: $OPTARG"
      verbosity="$OPTARG" 
      ;; 
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

ansible-playbook -$verbosity -i "localhost," -c local provdesktop.yml 
