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

if [ -z $pull_secret_file ];then
  pull_secret_file="/tmp/ocp_pullsecret.json"
fi

if [ ! -e $pull_secret_file ];then
  echo "Pull secret file $pull_secret_file does not exist, please create the file or set the pull_secret_file environment variable to point to the file that holds the pull secret."
  exit 1
fi

if [ -z $ocp_admin_password ];then
  echo 'OpenShift ocadmin administrator password (ocp_admin_password):'
  read -s ocp_admin_password
  if [ -z $ocp_admin_password ];then
    echo "Error: OpenShift administrator password. OpenShift administrator password environment variable ocp_admin_password or entered at prompt"
    exit 1
  fi
fi

if [ -z $root_password ];then
  echo 'Root password, leave blank if password-less SSH has already been configured (root_password):'
  read -s root_password
  if [ -z $root_password ];then
    echo "Assuming password-less SSH has been configured on all nodes in the cluster and that inventory file has been adjusted accordingly."
  fi
fi

# Echo extra parameters (if any)
[[ ! -z "$@" ]] && echo "Extra parameters passed to ansible-playbook: $@"

pushd $SCRIPT_DIR > /dev/null

# Run ansible playbook
inventory_file=$(realpath $INVENTORY_FILE_PARAM)

ansible-playbook -i $inventory_file playbooks/ocp4.yaml \
  -e ansible_ssh_pass=$root_password \
  -e ocp_admin_password=$ocp_admin_password \
  -e pull_secret_file=$pull_secret_file \
  -e script_dir=$SCRIPT_DIR \
  -e inventory_file=$inventory_file \
  "$@"

ANSIBLE_EXIT_CODE=$?

popd > /dev/null

exit $ANSIBLE_EXIT_CODE
