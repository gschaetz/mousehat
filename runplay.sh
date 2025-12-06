#!/bin/bash
verbosity="v"
WSL_LINUX="FALSE"
while getopts ":p:s:d:v:w" opt; do
  case $opt in
    w) 
      echo "Setting wsl setup to true."
      WSL_LINUX="TRUE"
      ;;
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
    d) 
      echo "Desktop location for .desktop: $OPTARG"
      export HOME_DESKTOP_DIR=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo $WSL_LINUX
      if [[ $OPTARG == "w" ]]; then
        continue
      else 
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
      fi
      ;;
  esac
done

# Check if settings directory was specified, if not ask for confirmation
if [ -z "$DESKTOP_SETTINGS_DIR" ]; then
  echo ""
  echo "WARNING: No custom settings directory specified (-s flag not used)."
  echo "This will use the default sample settings from ansible/sample-desktop-setup/"
  echo ""
  read -p "Are you sure you want to continue? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

ansible-playbook --ask-become-pass -$verbosity -i "localhost," -c local ansible/provdesktop.yml --extra-vars "WSL_LINUX=$WSL_LINUX"