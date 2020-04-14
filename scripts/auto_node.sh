#!/bin/bash

if [ "$EUID" = 0 ]
  then echo "Do not run as root, exiting..."
  exit
fi

validator_config_path="./validator_config.json"
bls_passphrase_dir="./harmony_bls_pass"
wallet_passphrase_dir="./harmony_wallet_pass"
hmy_dir="${HOME}/.hmy"
bls_keys_path="${hmy_dir}/blskeys"
node_path="${hmy_dir}/node"
docker_img="harmonyone/sentry:test" # TODO: change back
container_name="AutoNode"

case $1 in
  --container=*)
    container_name="${1#*=}"
    shift;;
esac

node_shared_dir="$node_path/$container_name"

function setup() {
  if [ ! -f "$validator_config_path" ]; then
    echo '{
  "validator-addr": null,
  "name": "harmony autonode",
  "website": "harmony.one",
  "security-contact": "Daniel-VDM",
  "identity": "auto-node",
  "amount": 10100,
  "min-self-delegation": 10000,
  "rate": 0.1,
  "max-rate": 0.75,
  "max-change-rate": 0.05,
  "max-total-delegation": 100000000.0,
  "details": "None"
}' > $validator_config_path
  fi
  docker pull harmonyone/sentry
  mkdir -p "$hmy_dir"
  mkdir -p "$bls_keys_path"
  mkdir -p "$node_path"
  mkdir -p "$bls_passphrase_dir"
  mkdir -p "$wallet_passphrase_dir"
  echo "
      Setup for Harmony auto node is complete.

      1. Docker image for node has been installed.
      2. Default validator config has been created at $validator_config_path (if it does not exist)
      3. BLS key directory for node has been created at $bls_keys_path
      4. BLS passphrase file direcotry has been created at $bls_passphrase_dir
      5. Wallet passphrase file directory has been created at $wallet_passphrase_dir
      6. Shared directory for all AutoNode node files has been created at $node_path
  "
}

case "${1}" in
  "run")
    if [ ! -f "$validator_config_path" ]; then
      echo "Validator config not found at ${validator_config_path}. Run setup with \`./auto_node.sh setup\` to create directory."
      exit
    fi
    if [ ! -d "$node_path" ]; then
      echo "Node directory not found at ${node_path}. Run setup with \`./auto_node.sh setup\` to create directory."
      exit
    fi
    if [ ! -d "$bls_keys_path" ]; then
      echo "BLS key file directory not found at ${bls_keys_path}. Run setup with \`./auto_node.sh setup\` to create directory."
      exit
    fi
    if [ ! -d "$bls_passphrase_dir" ]; then
      echo "BLS passphrase file directory not found at ${bls_passphrase_dir}. Run setup with \`./auto_node.sh setup\` to create directory."
      exit
    fi
    if [ ! -d "$wallet_passphrase_dir" ]; then
      echo "Wallet passphrase file directory not found at ${wallet_passphrase_dir}. Run setup with \`./auto_node.sh setup\` to create directory."
      exit
    fi
    if [ ! -d "${HOME}/.hmy_cli" ]; then
      echo "CLI keystore not found at ~/.hmy_cli. Create or import a wallet using the CLI before running auto_node.sh"
      exit
    fi

    if [ "$(docker inspect -f '{{.State.Running}}' "$container_name")" = "true" ]; then
      echo "[AutoNode] Killing existing docker container with name: $container_name"
      docker kill "${container_name}"
    fi
    if docker ps -a | grep "$container_name" ; then
      echo "[AutoNode] Removing existing docker container with name: $container_name"
      docker rm "${container_name}"
    fi

    mkdir -p "$node_shared_dir"
    cp $validator_config_path "${node_shared_dir}/validator_config.json"

    echo "[AutoNode] Using validator config at: $validator_config_path"
    echo "[AutoNode] Sharing node files on host machine at: ${node_shared_dir}"
    echo "[AutoNode] Sharing CLI files on host machine at: ${HOME}/.hmy_cli"
    echo "[AutoNode] Initializing..."

    # Warning: Assumption about BLS key files, might have to cahnge in the future...
    # Warning: Assumption about CLI files, might have to change in the future...
    eval docker run --name "${container_name}" -v "${node_shared_dir}:/root/node" \
     -v "${HOME}/.hmy_cli/:/root/.hmy_cli" -v "${bls_keys_path}:/root/imported_bls_keys" \
     -v "${bls_passphrase_dir}:/root/imported_bls_pass" -v "${wallet_passphrase_dir}:/root/imported_wallet_pass" \
     --user root -p 9000:9000 -p 6000:6000 $docker_img "${@:2}" &

    until docker ps | grep "${container_name}"
      do
          sleep 1
      done
      docker exec -it "${container_name}" /root/attach.sh
    ;;
  "create-validator")
    docker exec -it "${container_name}" /root/create_validator.sh
    ;;
  "activate")
    docker exec -it "${container_name}" /root/activate.sh
    ;;
  "deactivate")
    docker exec -it "${container_name}" /root/deactivate.sh
    ;;
  "info")
    docker exec -it "${container_name}" /root/info.sh
    ;;
  "cleanse-bls")
    docker exec -it "${container_name}" /root/cleanse-bls.py "${@:2}"
    ;;
  "balances")
    docker exec -it "${container_name}" /root/balances.sh
    ;;
  "node-version")
    docker exec -it "${container_name}" /root/version.sh
    ;;
  "version")
   docker images --format "table {{.ID}}\t{{.CreatedAt}}" --no-trunc $docker_img | head -n2
    ;;
  "header")
    docker exec -it "${container_name}" /root/header.sh
    ;;
  "headers")
    docker exec -it "${container_name}" /root/headers.sh
    ;;
  "export")
    docker exec -it "${container_name}" /root/export.sh
    ;;
  "attach")
    docker exec --user root -it "${container_name}" /root/attach.sh
    ;;
  "attach-machine")
    docker exec --user root -it "${container_name}" /bin/bash
    ;;
  "kill")
    docker exec --user root -it "${container_name}" /bin/bash -c "killall harmony"
    docker kill "${container_name}"
    ;;
  "export-bls")
    if [ ! -d "${2}" ]; then
      echo "${2}" is not a directory.
      exit
    fi
    cp -r "${node_shared_dir}/bls_keys" "${2}"
    echo "Exported BLS keys to ${2}/bls_keys"
    ;;
  "export-logs")
    if [ ! -d "${2}" ]; then
      echo "${2}" is not a directory.
      exit
    fi
    export_dir="${2}/logs"
    mkdir -p "${export_dir}"
    cp -r "${node_shared_dir}/node_sh_logs" "${export_dir}"
    cp -r "${node_shared_dir}/backups" "${export_dir}"
    cp -r "${node_shared_dir}/latest" "${export_dir}"
    cp "${node_shared_dir}/auto_node_errors.log" "${export_dir}"
    echo "Exported node.sh logs to ${export_dir}"
    ;;
  "hmy")
    docker exec -it "${container_name}" /root/bin/hmy "${@:2}"
    ;;
  "setup")
    setup
    ;;
  "clean")
    docker kill "${container_name}"
    docker rm "${container_name}"
    rm -rf ./."${container_name}"
    ;;
  *)
    echo "
      == Harmony auto-node deployment help message ==

      Optional:            Param:              Help:

      [--container=<name>] run <run params>    Main execution to run a node. If errors are given
                                                for other params, this needs to be ran. Use '-h' for run help msg
      [--container=<name>] create-validator    Send a create validator transaction with the given config
      [--container=<name>] activate            Make validator associated with node elegable for election in next epoch
      [--container=<name>] deactivate          Make validator associated with node NOT elegable for election in next epoch
      [--container=<name>] cleanse-bls <opts>  Remove BLS keys from validaor that are not earning. Use '-h' for help msg
      [--container=<name>] info                Fetch information for validator associated with node
      [--container=<name>] balances            Fetch balances for validator associated with node
      [--container=<name>] node-version        Fetch the version for the harmony node binary and node.sh
      [--container=<name>] version             Fetch the of the Docker image.
      [--container=<name>] header              Fetch the latest header (shard chain) for the node
      [--container=<name>] headers             Fetch the latest headers (beacon and shard chain) for the node
      [--container=<name>] attach              Attach to the running node
      [--container=<name>] attach-machine      Attach to the docker image that containes the node
      [--container=<name>] export              Export the private keys associated with this node
      [--container=<name>] export-bls <path>   Export all BLS keys used by the node
      [--container=<name>] export-logs <path>  Export all node logs to the given path
      [--container=<name>] hmy <CLI params>    Call the CLI where the localhost is the current node
      [--container=<name>] clean               Kills and remove the node's docker container and shared directory
      [--container=<name>] kill                Safely kill the node
      [--container=<name>] setup               Setup auto_node
    "
    exit
    ;;
esac