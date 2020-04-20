#!/bin/bash

set -e

# TODO: convert auto_node.sh into python3 click CLI since lib is in python3.

sudo -n true
if [ "$?" -ne 0 ]; then
  echo "[AutoNode] user $USER needs sudo privaliges without a passphrase to run AutoNode correctly, continue (y/n)?"
  read -r answer
  if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo "[AutoNode] AutoNode monitor will not function correctly."
  else
    exit
  fi
fi

case "${1}" in
  "run")
    harmony_dir=$(python3 -c "from AutoNode import common; print(common.harmony_dir)")
    python3 -u "$harmony_dir"/init.py "${@:2}"
    echo "[AutoNode] Initilized service..."
    daemon_name=$(python3 -c "from AutoNode.daemon import Daemon; print(Daemon.name)")
    sudo systemctl start "$daemon_name"@node.service
    sudo systemctl start "$daemon_name"@monitor.service
    python3 -u -c "from AutoNode import validator; validator.setup(recover_interaction=False)" || true
    monitor_log_path=$(python3 -c "from AutoNode import monitor; print(monitor.log_path)")
    if [ -f "$monitor_log_path" ]; then
      tail -f "$monitor_log_path"
    else
      echo "[AutoNode] Monitor failed to start..."
      systemctl status "$daemon_name"@monitor.service || true
    fi
    ;;
  "init")
    harmony_dir=$(python3 -c "from AutoNode import common; print(common.harmony_dir)")
    python3 -u "$harmony_dir"/init.py "${@:2}"
    ;;
  "node")
    daemon_name=$(python3 -c "from AutoNode.daemon import Daemon; print(Daemon.name)")
    if systemctl --type=service --state=active | grep -e ^"$daemon_name"@node.service; then
      node_daemon="$daemon_name"@node.service
    else
      node_daemon="$daemon_name"@node_recovered.service
    fi
    case "${2}" in
      "status")
      systemctl status "$node_daemon"
      ;;
      "log")
      tail -f "$(python3 -c "from AutoNode import node; print(node.log_path)")"
      ;;
      "journal")
      journalctl -u "$node_daemon" "${@:3}"
      ;;
      "restart")
      sudo systemctl restart "$node_daemon"
      ;;
      "name")
      echo "$node_daemon"
      ;;
      "info")
      curl --location --request POST 'http://localhost:9500/' \
      --header 'Content-Type: application/json' \
      --data-raw '{
          "jsonrpc": "2.0",
          "method": "hmy_getNodeMetadata",
          "params": [],
          "id": 1
      }' | jq
      ;;
      *)
        echo "
      == AutoNode node command help ==

      Usage: auto_node.sh node <cmd>

      Cmd:           Help:

      log            View the current log of your Harmony Node
      status         View the status of your current Harmony Node daemon
      journal <opts> View the journal of your current Harmony Node daemon
      restart        Manually restart your current Harmony Node daemon
      name           Get the name of your current Harmony Node deamon
      info           Get the node's current metadata
        "
        exit
    esac
    ;;
  "monitor")
    daemon_name=$(python3 -c "from AutoNode.daemon import Daemon; print(Daemon.name)")
    monitor_daemon="$daemon_name"@monitor.service
    case "${2}" in
      "status")
      systemctl status "$monitor_daemon"
      ;;
      "log")
      tail -f "$(python3 -c "from AutoNode import monitor; print(monitor.log_path)")"
      ;;
      "journal")
      journalctl -u "$monitor_daemon" "${@:3}"
      ;;
      "restart")
      sudo systemctl restart "$monitor_daemon"
      ;;
      "name")
      echo "$monitor_daemon"
      ;;
      *)
        echo "
      == AutoNode node monitor command help ==

      Usage: auto_node.sh monitor <cmd>

      Cmd:            Help:

      log             View the log of your Harmony Monitor
      status          View the status of your Harmony Monitor daemon
      journal <opts>  View the journal of your Harmony Monitor daemon
      restart         Manually restart your Harmony Monitor daemon
      name            Get the name of your Harmony Monitor deamon
        "
        exit
    esac
    ;;
  "create-validator")
    # TODO in python for simplicity
    ;;
  "activate")
    val_config=$(python3 -c "from AutoNode import common; import json; print(json.dumps(common.validator_config))")
    node_config=$(python3 -c "from AutoNode import common; import json; print(json.dumps(common.node_config))")
    addr=$(echo "$val_config" | jq -r '.["validator-addr"]')
    endpoint=$(echo "$node_config" | jq -r ".endpoint")
    pw_file=$(python3 -c "from AutoNode import common; print(common.saved_wallet_pass_path)")
    if [ -f "$HOME"/hmy ]; then
      "$HOME"/hmy staking edit-validator --validator-addr "$addr" --active true --passphrase-file "$pw_file" -n "$endpoint" | jq
    else
      echo "[AutoNode] Harmony CLI has been moved. Reinitlize AutoNode."
    fi
    ;;
  "deactivate")
    val_config=$(python3 -c "from AutoNode import common; import json; print(json.dumps(common.validator_config))")
    node_config=$(python3 -c "from AutoNode import common; import json; print(json.dumps(common.node_config))")
    addr=$(echo "$val_config" | jq -r '.["validator-addr"]')
    endpoint=$(echo "$node_config" | jq -r ".endpoint")
    pw_file=$(python3 -c "from AutoNode import common; print(common.saved_wallet_pass_path)")
    if [ -f "$HOME"/hmy ]; then
      "$HOME"/hmy staking edit-validator --validator-addr "$addr" --active false --passphrase-file "$pw_file" -n "$endpoint" | jq
    else
      echo "[AutoNode] Harmony CLI has been moved. Reinitlize AutoNode."
    fi
    ;;
  "info")
    val_config=$(python3 -c "from AutoNode import common; import json; print(json.dumps(common.validator_config))")
    node_config=$(python3 -c "from AutoNode import common; import json; print(json.dumps(common.node_config))")
    addr=$(echo "$val_config" | jq -r '.["validator-addr"]')
    endpoint=$(echo "$node_config" | jq -r ".endpoint")
    if [ -f "$HOME"/hmy ]; then
      "$HOME"/hmy blockchain validator information "$addr" -n "$endpoint" | jq
    else
      echo "[AutoNode] Harmony CLI has been moved. Reinitlize AutoNode."
    fi
    ;;
  "config")
    python3 -c "from AutoNode import common; import json; print(json.dumps(common.validator_config))" | jq
    ;;
  "edit-config")
    nano "$(python3 -c "from AutoNode import common; print(common.saved_validator_path)")"
    ;;
  "cleanse-bls")
    # TODO in python for simplitcy
    ;;
  "balances")
    val_config=$(python3 -c "from AutoNode import common; import json; print(json.dumps(common.validator_config))")
    node_config=$(python3 -c "from AutoNode import common; import json; print(json.dumps(common.node_config))")
    addr=$(echo "$val_config" | jq -r '.["validator-addr"]')
    endpoint=$(echo "$node_config" | jq -r ".endpoint")
    if [ -f "$HOME"/hmy ]; then
      "$HOME"/hmy balances "$addr" -n "$endpoint" | jq
    else
      echo "[AutoNode] Harmony CLI has been moved. Reinitlize AutoNode."
    fi
    ;;
  "collect-rewards")
    val_config=$(python3 -c "from AutoNode import common; import json; print(json.dumps(common.validator_config))")
    addr=$(echo "$val_config" | jq -r '.["validator-addr"]')
    if [ -f "$HOME"/hmy ]; then
      "$HOME"/hmy staking collect-rewards --delegator-addr "$addr" -n "$endpoint" | jq
    else
      echo "[AutoNode] Harmony CLI has been moved. Reinitlize AutoNode."
    fi
    ;;
  "version")
    node_dir=$(python3 -c "from AutoNode import common; print(common.node_dir)")
    owd=$(pwd)
    cd "$node_dir" && ./node.sh -V && ./node.sh -v && cd "$owd" || echo "[AutoNode] Node files not found..."
    ;;
  "header")
    if [ -f "$HOME"/hmy ]; then
      "$HOME"/hmy blockchain latest-header | jq
    else
      echo "[AutoNode] Harmony CLI has been moved. Reinitlize AutoNode."
    fi
    ;;
  "headers")
    if [ -f "$HOME"/hmy ]; then
      "$HOME"/hmy blockchain latest-headers | jq
    else
      echo "[AutoNode] Harmony CLI has been moved. Reinitlize AutoNode."
    fi
    ;;
  "kill")
    daemon_name=$(python3 -c "from AutoNode.daemon import Daemon; print(Daemon.name)")
    sudo systemctl stop "$daemon_name"* || true
    ;;
  *)
    echo "
      == Harmony AutoNode help message ==
      Note that all sensitive files are saved with read only access for user $USER.
      Moreover, user $USER must have sudo access with no passphrase, contact your administrator for such access.

      Param:              Help:

      run <run params>    Main execution to run a node. If errors are given
                           for other params, this needs to be ran. Use '-h' param for run param msg
      init                Initlize AutoNode config. First fallback if any errors
      monitor <cmd>       View/Command Harmony Node Monitor. Use '-h' cmd for node monitor cmd help msg
      node <cmd>          View/Command Harmony Node. Use '-h' cmd for node cmd help msg
      create-validator    Send a create validator transaction with the given config
      activate            Make validator associated with node elegable for election in next epoch
      deactivate          Make validator associated with node NOT elegable for election in next epoch
      info                Fetch information for validator associated with node
      cleanse-bls <opts>  Remove BLS keys from validaor that are not earning. Use '-h' opts for opts help msg
      balances            Fetch balances for validator associated with node
      collect-rewards     Collect rewards for the associated validator
      version             Fetch the version of the node
      header              Fetch the latest header (shard chain) for the node
      headers             Fetch the latest headers (beacon and shard chain) for the node
      kill                Safely kill AutoNode & its monitor (if alive)
    "
    exit
    ;;
esac
