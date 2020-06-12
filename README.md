# AutoNode - Run a Harmony node with 1 command!

Documentation for most users can be found [here](https://docs.harmony.one/home/validators/autonode)

## Setup

**1) Install AutoNode with the following command:**
```bash
curl -O https://raw.githubusercontent.com/harmony-one/auto-node/master/scripts/install.sh && chmod +x ./install.sh && ./install.sh && rm ./install.sh
```

**2) Create and/or import you validator wallet with the included CLI:**

Create Validator
```bash
~/hmy keys add validator
```

Import wallet from Keystore file
```bash
~/hmy keys import-ks <path-to-keystore-file>
```

Import wallet from private-key (not recommended)
```bash
~/hmy keys import-private-key <private-key-string>
``` 

**3) Edit the config**
```bash
~/auto_node.sh edit-config
```
> Set your one1... address. Note that it has to be in quotes. 
>
> Save and exit by pressing **Ctrl+X**, then **`Y`**, then **enter**.

**4) Run you validator node**
```bash
~/auto_node.sh run --auto-active --auto-reset --clean
```
> Answer the prompts with `Y` or `N`, **make sure to fund your validator before creating the validator**.
>
> Once you see a looping print of header information, feel free to exit with **Ctrl+Z**
>
> You can also close your SSH session.

## Dev Setup
**Note that you must be in a linux machine to test most things, though some dev can be done on a mac machine.**

### Installation (after cloning this repo):
```bash
make install
```

### Release:
1) Bump the AutoNode version in `./setup.py`
2) Bump the AutoNode version in `./scripts/install.py`
3) Release AutoNode to pypi with `make release`
4) If any scripts are needed for the install, they won't take effect until changes are merged to master. 


## Importing notes and assumptions

* AutoNode assumes that you are not root.
* Your node (db files, harmony binary, logs, etc...) will be saved in `~/harmony_node`.
* For the `--auto-reset` option (which is what enables the auto-reset of hard refreshes) your user needs
to have access to sudo without a passphrase. This is needed as the monitor will need to stop and start services.
* AutoNode will save sensitive information with read only access for the user (and root).

## Common Usages

### 1) AutoNode help message:
```bash
~/auto_node.sh -h
```

For reference here is the help message:
```
== Harmony AutoNode help message ==
Note that all sensitive files are saved with read only access for user $USER.

To auto-reset your node during hard refreshes (for testnets), user $USER must have sudo access
with no passphrase since services must be stopped and started by a monitor.


Param:              Help:

run <run params>    Main execution to run a node. If errors are given
                   for other params, this needs to be ran. Use '-h' param to view help msg
auth-wallet         Re-auth wallet passphrase if AutoNode expires/invalidates stored passphrase.
config              View the validator_config.json file used by AutoNode
edit-config         Edit the validator_config.json file used by AutoNode and change validator info on-chain
update-config       Update validator info on-chain with given validator_config.json
monitor <cmd>       View/Command Harmony Node Monitor. Use '-h' param to view help msg
node <cmd>          View/Command Harmony Node. Use '-h' params to view help msg
tui <cmd>           Start the text-based user interface to monitor your node and validator.
                   Use '-h' param to view help msg
create-validator    Run through the steps to setup your validator
activate            Make validator associated with node eligible for election in next epoch
deactivate          Make validator associated with node NOT eligible for election in next epoch.
                   Note that this may not work as intended if auto-active was enabled
info                Fetch information for validator associated with node
cleanse-bls <opts>  Remove BLS keys from validator that are not earning. Use '-h' param to view help msg
balances            Fetch balances for validator associated with node
collect-rewards     Collect rewards for the associated validator
version             Fetch the version of the node
header              Fetch the latest header (shard chain) for the node
headers             Fetch the latest headers (beacon and shard chain) for the node
clear-node-bls      Remove the BLS key directory used by the node.
hmy <command>       Execute the Harmony CLI with the given command.
                   Use '-h' param to view help msg
hmy-update          Update the Harmony CLI used for AutoNode
kill                Safely kill AutoNode & its monitor (if alive)
```

### 2) Run AutoNode:
```bash
~/auto_node.sh run <options>
```

For reference here is the run help msg for `<options>`:
```
usage: auto_node.sh run [OPTIONS]

== Run a Harmony node & validator automagically ==

optional arguments:
  -h, --help            Show this help message and exit
  --auto-active         Always try to set active when EPOS status is inactive.
  --auto-reset          Automatically reset node during hard resets.
  --no-validator        Disable validator automation.
  --archival            Run node with archival mode.
  --update-cli          Toggle upgrading the Harmony CLI used by AutoNode
  --clean               Clean shared node directory before starting node.
  --shard SHARD         Specify shard of generated bls key.
                          Only used if no BLS keys are not provided.
  --network NETWORK     Network to connect to (staking, partner, stress).
                          Default: 'staking'.
  --beacon-endpoint ENDPOINT
                        Beacon chain (shard 0) endpoint for staking transactions.
                          Default is https://api.s0.os.hmny.io/
```

### 3) (Re)initialize AutoNode without running it 
```bash
~/auto_node.sh init
```

### 4) Node information & status:
```bash
~/auto_node.sh node <cmd>
```

For reference here is the node help msg for `<cmd>`:
```
== AutoNode node command help ==

Usage: auto_node.sh node <cmd>

Cmd:                  Help:

log                   View the current log of your Harmony Node
status [init]         View the status of your current Harmony Node daemon
journal [init] <opts> View the journal of your current Harmony Node daemon
restart [init]        Manually restart your current Harmony Node daemon
name [init]           Get the name of your current Harmony Node deamon
info                  Get the node's current metadata

'init' is a special option for the inital node daemon, may be needed for debugging.
Otherwise not needed.
```

### 5) Monitor information & status:
```bash
~/auto_node.sh monitor <cmd>
```
  
For reference here is the monitor help msg for `<cmd>`:
```
== AutoNode node monitor command help ==

Usage: auto_node.sh monitor <cmd>

Cmd:            Help:

log             View the log of your Harmony Monitor
status          View the status of your Harmony Monitor daemon
journal <opts>  View the journal of your Harmony Monitor daemon
restart         Manually restart your Harmony Monitor daemon
name            Get the name of your Harmony Monitor deamon
```

### 6) Start the TUI
```bash
~/auto_node.sh tui run
```

![](https://github.com/harmony-one/harmony-tui/blob/master/doc/images/staking-tui-sample.png?raw=true&s=800)


### 7) See validator information for associated AutoNode
```bash
~/auto_node.sh info
```

### 8) See node latest header (for quick view of node activity)
```bash
~/auto_node.sh headers
```

### 9) See AutoNode validator config
```bash
~/auto_node.sh config
```

### 10) Edit AutNode validator config
```bash
~/auto_node.sh edit-config
```

### 11) Aliased Harmony CLI commands:

Send a edit-validator transaction to activate your associated validator
```bash
~/auto_node.sh activate
```

Send a edit-validator transaction to deactivate your associated validator
```bash
~/auto_node.sh deactivate
```
> Note that this may not work as desired with `--auto-active` option

Get the balances of the associated validator wallet
```bash
~/auto_node.sh balances
```

### 12) Kill AutoNode
```bash
~/auto_node.sh kill
```

## Project Layout
### `./AutoNode/`
This is the main python3 package for AutoNode. Each component is its own library within this package.
### `./scripts/`
* `auto_node.sh` is the main script that people will be interfacing with
* `autonode_service.py` is the daemon script
* `cleanse-bls.py` is a command script needed for `auto_node.sh`
* `tui.sh` is a command script needed for `auto_node.sh`
* `node.sh` is a command script needed for `auto_node.sh`
* `monitor.sh` is a command script needed for `auto_node.sh`
* `install.sh` is the main install script that people will be running to install AutoNode. This should handle most linux distros and common setups.
**Note that the version of AutoNode is hard-coded in this script and needs to be bumped if a new version is desired**
### `./setup.py`
This is the pypi setup script that is needed for distribution upload. 
**Note that the version needs to be bumped manually and the install script must be updated accordingly.**

