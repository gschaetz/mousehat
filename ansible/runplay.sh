#!/bin/bash
verbosity="v"
while getopts ":d:p:s:v:" opt; do
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
      if [ $OPTARG == "default" ]
      then 
      export DESKTOP_SETTINGS_DIR=defaults
      else
      export DESKTOP_SETTINGS_DIR=$OPTARG
      fi
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
