#! /bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

# Check number of parameters
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 -i <inventory file> [other ansible-playbook parameters]"
    exit 1
fi

# Parse parameters
PARAMS=""
while (( "$#" )); do
  case "$1" in
    -i)
      INVENTORY_FILE_PARAM=$2
      shift 2
      ;;
    *) # preserve remaining arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

# Set remaining parameters
eval set -- "$PARAMS"

if [ ! -e $INVENTORY_FILE_PARAM ]; then
  echo "Usage: $0 -i <inventory file> [other ansible-playbook parameters]"
  echo "Available inventory files are:"
  find ./inventory/ -name "*.inv"
  exit 1
fi

if [ -z "$vc_user" ];then
  echo
  echo 'vCenter user:'
  read vc_user
  if [ -z "$vc_user" ];then
    echo "Error: vCenter user. vCenter user environment variable vc_user not set or entered at prompt"
    exit 1
  fi
fi

if [ -z "$vc_password" ];then
  echo
  echo 'vCenter password:'
  read -s vc_password
  if [ -z "$vc_password" ];then
    echo "Error: vCenter password. vCenter password environment variable vc_password not set or entered at prompt"
    exit 1
  fi
fi

# Echo extra parameters (if any)
[[ ! -z "$@" ]] && echo "Extra parameters passed to ansible-playbook: $@"

# Run ansible playbook
inventory_file=$(realpath $INVENTORY_FILE_PARAM)

ansible-playbook -i $inventory_file playbooks/ocp4_vm_create.yaml \
  -e vc_user="$vc_user" \
  -e vc_password="$vc_password" \
  -e inventory_file=$inventory_file \
  "$@"
