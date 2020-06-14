# AutoNode - Run a Harmony node with 1 command!

Documentation for most users can be found [here](https://docs.harmony.one/home/validators/autonode)

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
* AutoNode will save sensitive information with read only access for the user (and root).


## Project Layout
### `./AutoNode/`
This is the main python3 package for AutoNode. Each component is its own library within this package.
### `./scripts/`
* `auto-node.sh` is the main script that people will be interfacing with
* `autonode-service.py` is the daemon script
* `cleanse-bls.py` is a command script needed for `auto-node.sh`
* `tui.sh` is a command script needed for `auto-node.sh`
* `node.sh` is a command script needed for `auto-node.sh`
* `monitor.sh` is a command script needed for `auto-node.sh`
* `install.sh` is the main install script that people will be running to install AutoNode. This should handle most linux distros and common setups.
* `dev-install.sh` is the shell script to locally install auto-node. Any changes in the daemon installation needs to be done manually.
**Note that the version of AutoNode is hard-coded in this script and needs to be bumped if a new version is desired**
### `./setup.py`
This is the pypi setup script that is needed for distribution upload. 
**Note that the version needs to be bumped manually and the install script must be updated accordingly.**

