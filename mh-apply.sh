#!/bin/bash
verbosity="v"
WSL_LINUX="FALSE"
ASK_BECOME_PASS=""
ROLE_TAGS=""
while getopts ":p:s:d:v:r:wK" opt; do
  case $opt in
    K)
      ASK_BECOME_PASS="--ask-become-pass"
      ;;
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
    r)
      echo "Running only role: $OPTARG"
      ROLE_TAGS="--tags $OPTARG"
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

# Fall back to previously saved settings dir if -s was not provided
if [ -z "$DESKTOP_SETTINGS_DIR" ] && [ -f ~/.config/mousehat/settings_dir ]; then
  export DESKTOP_SETTINGS_DIR="$(cat ~/.config/mousehat/settings_dir)"
  echo "Using saved settings directory: $DESKTOP_SETTINGS_DIR"
fi

# Persist settings dir for future runs
if [ -n "$DESKTOP_SETTINGS_DIR" ]; then
  mkdir -p ~/.config/mousehat
  echo "$DESKTOP_SETTINGS_DIR" > ~/.config/mousehat/settings_dir
fi

# No settings dir at all — require -s on first run
if [ -z "$DESKTOP_SETTINGS_DIR" ]; then
  echo "Error: No settings directory found. Use -s on first run to set it." >&2
  echo "  ./mh-apply.sh -s /path/to/settings" >&2
  exit 1
fi

ansible-playbook $ASK_BECOME_PASS -$verbosity -i "localhost," -c local ansible/provdesktop.yml --extra-vars "WSL_LINUX=$WSL_LINUX" $ROLE_TAGS