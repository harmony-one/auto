#!/bin/bash
set -e

version="1.0.3"
SCRIPT_PATH=$(realpath -s "$0")
cached_release_info_path="/tmp/.$USER-autonode-version-cache"

# TODO: convert auto-node.sh into python3 click CLI since lib is in python3.
function yes_or_exit() {
  read -r reply
  if [[ ! $reply =~ ^[Yy]$ ]]; then
    exit 1
  fi
}

function verlte() {
  [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

function echoerr() {
  echo -e "$@" 1>&2;
}

function version_precheck(){
  got_cached=False

  if [ -f "$cached_release_info_path" ]; then
    tmp_release_info=$(cat "$cached_release_info_path")
    date_cached=$(echo "$tmp_release_info" | jq .time)
    if [ "$date_cached" != "null" ]; then
      diff_cache=$(expr "$(date +'%s')" - "$date_cached")
      if [ "$(expr "$diff_cache" \> 3600)" == "0" ]; then
        release_info=$(echo "$tmp_release_info" | jq .data)
        [ "$release_info" != "null" ] && got_cached=True
      fi
    fi
  fi

  if [ $got_cached != "True" ]; then
    release_info=$(curl --silent "https://api.github.com/repos/harmony-one/auto-node/releases/latest")
    echo "{\"time\": $(date +'%s'), \"data\": $release_info }" > "$cached_release_info_path"
  fi

  release_version=$(echo "$release_info" | jq ".tag_name" -r)
  if [ "$release_version" != "null" ]; then
    run_cmd="auto-node update"
    verlte "$release_version" "$version" || echoerr "[AutoNode] There is an update! Install with \e[38;5;0;48;5;255m$run_cmd\e[0m"
  fi
}

function _kill() {
  can_safe_stop="False"
  can_safe_stop=$(python3 -c "from AutoNode import validator; print(validator.can_safe_stop_node(safe=True))")
  if [ "$can_safe_stop" == "False" ]; then
    echo "[AutoNode] Validator is still elected and node is still signing."
    echo "[AutoNode] Continue to kill? (y/n)"
    yes_or_exit
  fi
  node_conf_path=$(python3 -u -c "from AutoNode import common; common.reset_node_config(); print(common.saved_node_config_path)")
  daemon_name=$(python3 -c "from AutoNode import daemon; print(daemon.name)")
  systemctl --user stop "$daemon_name"*
  rm -f "$node_conf_path"
  if ! pgrep harmony >/dev/null; then
    echo "[AutoNode] Successfully killed auto-node"
  else
    echo "[AutoNode] FAILED TO KILL! Check node and/or monitor status."
    exit 1
  fi
}

if ! systemctl --user > /dev/null; then
  export XDG_RUNTIME_DIR="/run/user/$UID"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

# Do not import python lib for performance, should change when converted to python3 click CLI.
if ! systemctl list-unit-files --user | grep autonode >/dev/null; then
  echo "[AutoNode] systemd services not found, maybe wrong user? exiting..."
  exit 1
fi

version_precheck

case "${1}" in
"run")
  harmony_dir=$(python3 -c "from AutoNode import common; print(common.harmony_dir)")
  python3 -u "$harmony_dir"/run.py "${@:2}"
  ;;
"auth-wallet")
  if [ ! "$(pgrep harmony)" ]; then echo "[AutoNode] Node must be running..." && exit 1; fi
  python3 -u -c "from AutoNode import initialize; initialize.setup_wallet_passphrase()"
  ;;
"node")
  harmony_dir=$(python3 -c "from AutoNode import common; print(common.harmony_dir)")
  bash "$harmony_dir"/node.sh "${@:2}"
  ;;
"monitor")
  harmony_dir=$(python3 -c "from AutoNode import common; print(common.harmony_dir)")
  bash "$harmony_dir"/monitor.sh "${@:2}"
  ;;
"tui")
  harmony_dir=$(python3 -c "from AutoNode import common; print(common.harmony_dir)")
  bash "$harmony_dir"/tui.sh "${@:2}"
  ;;
"tune")
  harmony_dir=$(python3 -c "from AutoNode import common; print(common.harmony_dir)")
  if echo "${@:2}" | grep "saved-sysctl-path" >/dev/null; then
    sudo python3 -u "$harmony_dir"/tune.py "${@:2}"
  else
    saved_sysctl_path="$harmony_dir/saved_sysctl.conf.p"
    sudo python3 -u "$harmony_dir"/tune.py "${@:2}" "--saved-sysctl-path=$saved_sysctl_path"
  fi
  ;;
"bls-shard")
  python3 -u -c "from AutoNode import util; print(util.shard_for_bls(\"$2\"))"
  ;;
"create-validator")
  python3 -u -c "from AutoNode import validator; validator.setup(hard_reset_recovery=False)"
  ;;
"activate")
  python3 -u -c "from AutoNode import validator; validator.activate_validator()"
  ;;
"deactivate")
  python3 -u -c "from AutoNode import validator; validator.deactivate_validator()"
  ;;
"info")
  python3 -u -c "from AutoNode import validator; import json; print(json.dumps(validator.get_validator_information(), indent=2))"
  ;;
"config")
  python3 -u -c "from AutoNode import common; import json; print(json.dumps(common.validator_config, indent=2))"
  ;;
"edit-config")
  nano "$(python3 -c "from AutoNode import common; print(common.saved_validator_path)")"
  echo "[AutoNode] Would you like to update your validator information on-chain (y/n)?"
  yes_or_exit
  python3 -u -c "from AutoNode import validator; validator.update_info(hard_reset_recovery=False)"
  ;;
"update-config")
  echo "[AutoNode] Would you like to update your validator information on-chain (y/n)?"
  yes_or_exit
  python3 -u -c "from AutoNode import validator; validator.update_info(hard_reset_recovery=False)"
  ;;
"cleanse-bls")
  harmony_dir=$(python3 -c "from AutoNode import common; print(common.harmony_dir)")
  python3 -u "$harmony_dir"/cleanse-bls.py "${@:2}"
  ;;
"remove-bls")
  python3 -u -c "from AutoNode import validator; validator.remove_bls_key(\"$2\")"
  ;;
"balances")
  python3 -u -c "from AutoNode import validator; import json; print(json.dumps(validator.get_balances(), indent=2))"
  ;;
"collect-rewards")
  python3 -u -c "from AutoNode import validator; validator.collect_reward()"
  ;;
"version")
  echo "AutoNode: $version"
  harmony_dir=$(python3 -c "from AutoNode import common; print(common.harmony_dir)")
  bash "$harmony_dir"/node.sh -v
  bash "$harmony_dir"/node.sh -V
  ;;
"header")
  python3 -u -c "from pyhmy import blockchain; import json; print(json.dumps(blockchain.get_latest_header(), indent=2))"
  ;;
"headers")
  python3 -u -c "from pyhmy import blockchain; import json; print(json.dumps(blockchain.get_latest_headers(), indent=2))"
  ;;
"clear-node-bls")
  daemon_name=$(python3 -c "from AutoNode import daemon; print(daemon.name)")
  if systemctl --type=service --all --state=active | grep -e ^"$daemon_name"; then
    echo "[AutoNode] AutoNode is still running. Kill with 'auto-node kill' before cleaning BLS keys."
    exit 4
  fi
  bls_key_dir=$(python3 -c "from AutoNode import common; print(common.bls_key_dir)")
  echo "[AutoNode] removing directory: $bls_key_dir"
  rm -rf "$bls_key_dir"
  ;;
"hmy")
  cli_bin=$(python3 -c "from AutoNode import common; print(common.cli_bin_path)")
  $cli_bin "${@:2}"
  ;;
"hmy-update")
  cli_bin=$(python3 -c "from AutoNode import common; print(common.cli_bin_path)")
  python3 -u -c "from pyhmy import cli; cli.download(\"$cli_bin\", replace=True, verbose=True)"
  ;;
"update")
  cmd_path=$(command -v auto-node)
  temp_instll_wrapper_script_path="/tmp/auto-node-temp-install-wrapper.$(date +'%s').sh"
  temp_install_script_path="/tmp/auto-node-temp-install.$(date +'%s').sh"
  if [ "$cmd_path" == "$SCRIPT_PATH" ]; then
    if verlte "$release_version" "$version"; then
      echo "[AutoNode] Running latest, no update needed!"
      echo "[AutoNode] Would you like to reinstall anyways?"
      yes_or_exit
    fi
    if pgrep harmony > /dev/null; then
      echo "[AutoNode] Must shutdown node to update, kill node and update now? (y/n)"
      yes_or_exit
    fi
    _kill
    cp "$cmd_path" "$temp_instll_wrapper_script_path"
    bash "$temp_instll_wrapper_script_path" "${1}"
  else
    install_script=$(echo "$release_info" | jq ".assets" | jq '[.[]|select(.name="install.sh")][0].browser_download_url' -r)
    wget "$install_script" -O "$temp_install_script_path"
    bash "$temp_install_script_path"
    echo -e "[AutoNode] Update Complete. \033[1;33mREMEMBER TO RESTART YOUR AUTONODE!\033[0m"
    echo ""
  fi
  ;;
"kill")
  _kill
  ;;
*)
  echo "
      == Harmony AutoNode help message ==
      Note that all sensitive files are saved with read only access for user $USER.

      Param:                Help:

      run <run params>      Main execution to run a node. If errors are given
                             for other params, this needs to be ran. Use '-h' param to view help msg
      auth-wallet           Re-auth wallet passphrase if AutoNode expires/invalidates stored passphrase.
      config                View the validator_config.json file used by AutoNode
      edit-config           Edit the validator_config.json file used by AutoNode and change validator info on-chain
      update-config         Update validator info on-chain with given validator_config.json
      cleanse-bls <opts>    Remove BLS keys from validator that are not earning. Use '-h' param to view help msg
      remove-bls <pub-key>  Remove a given public BLS key from validator
      monitor <cmd>         View/Command Harmony Node Monitor. Use '-h' param to view help msg
      node <cmd>            View/Command Harmony Node. Use '-h' params to view help msg
      tui <cmd>             Start the text-based user interface to monitor your node and validator.
                             Use '-h' param to view help msg
      create-validator      Run through the steps to setup your validator
      activate              Make validator associated with node eligible for election in next epoch
      deactivate            Make validator associated with node NOT eligible for election in next epoch.
                             Note that this may not work as intended if auto-active is enabled
      tune <tune params>    Optimize the OS for running a node. Use '-h' param to view help msg
      bls-shard <pub-key>   Get shard for given public BLS key
      info                  Display information for validator associated with node
      balances              Display balances for validator associated with node
      collect-rewards       Collect rewards for the associated validator
      version               Display the version of Autonode, node.sh, & harmony binary
      header                Display the latest header (shard chain) for the node
      headers               Display the latest headers (beacon and shard chain) for the node
      clear-node-bls        Remove the BLS key directory used by the node.
      hmy <command>         Execute the Harmony CLI with the given command.
                             Use '-h' param to view help msg
      hmy-update            Update the Harmony CLI used for AutoNode
      update                Update autonode (if possible)
      kill                  Safely kill AutoNode & its monitor (if alive)
    "
  exit
  ;;
esac
