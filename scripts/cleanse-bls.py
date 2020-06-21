#!/usr/bin/env python3
import argparse
import time
import json
from argparse import RawTextHelpFormatter

from pyhmy import (
    blockchain,
    cli,
    json_load,
    Typgpy
)
from AutoNode import (
    common,
    util,
    node,
    validator
)

validator_addr = common.validator_config['validator-addr']
endpoint = common.node_config['endpoint']
bls_keys = common.node_config['public-bls-keys']
removed_keys = []


def parse_args():
    parser = argparse.ArgumentParser(description="Cleanse BLS keys associated with this node's validator",
                                     usage="auto-node cleanse-bls [OPTIONS]",
                                     formatter_class=RawTextHelpFormatter, add_help=False)
    parser.add_argument('-h', '--help', action='help', default=argparse.SUPPRESS,
                        help='Show this help message and exit')
    parser.add_argument("--hard", action="store_true",
                        help="Remove ALL BLS keys that are not this node's BLS key")
    parser.add_argument("--keep-shard", action="store_true",
                        help="Remove ALL BLS keys that are not this node's SHARD")
    parser.add_argument("--yes", action="store_true",
                        help="Answer yes to all interaction")
    return parser.parse_args()


def hard_cleanse(yes=False):
    """
    Only keep BLS keys for current running node.
    """
    # WARNING: Assumption that chain BLS keys are not 0x strings
    keys_on_chain = validator.get_validator_information()['validator']['bls-public-keys']
    for key in keys_on_chain:
        if key not in bls_keys:
            prompt = f"{Typgpy.HEADER}Remove BLS key that is not use by this node: " \
                     f"{Typgpy.OKGREEN}{key}{Typgpy.HEADER}?{Typgpy.ENDC} [Y]/n\n> "
            if not yes and util.input_with_print(prompt).lower() not in {'y', 'yes'}:
                continue
            validator.remove_bls_key(key)
            removed_keys.append(key)


def shard_cleanse(yes=False):
    """
    Only keep BLS keys on same shard as current running node.
    """
    # WARNING: Assumption that chain BLS keys are not 0x strings
    keys_on_chain = validator.get_validator_information()['validator']['bls-public-keys']
    shard = json_load(cli.single_call(['hmy', 'utility', 'shard-for-bls', list(bls_keys)[0],
                                       '--node', endpoint]))['shard-id']
    for key in keys_on_chain:
        key_shard = json_load(cli.single_call(['hmy', 'utility', 'shard-for-bls', key,
                                               '--node', endpoint]))['shard-id']
        if key_shard != shard and key not in bls_keys:
            prompt = f"{Typgpy.HEADER}Remove BLS key not for shard {shard}: " \
                     f"{Typgpy.OKGREEN}{key}{Typgpy.HEADER}?{Typgpy.ENDC} [Y]/n\n> "
            if not yes and util.input_with_print(prompt).lower() not in {'y', 'yes'}:
                continue
            validator.remove_bls_key(key)
            removed_keys.append(key)


def reward_cleanse(yes=False):
    """
    Only keep BLS keys that have earned something in the current epoch
    """
    val_metrics = validator.get_validator_information()['metrics']
    if val_metrics is None:
        common.log(f"{Typgpy.WARNING}Can not get current BLS key performance, "
                   f"validator ({validator_addr}) is not elected.{Typgpy.ENDC}")
        if args.yes or util.input_with_print(f"Wait for election? [Y]/n\n> ").lower() in {'y', 'yes'}:
            while val_metrics is None:
                time.sleep(8)
                val_metrics = validator.get_validator_information()['metrics']
        else:
            exit()
    block_per_epoch = blockchain.get_node_metadata(endpoint=endpoint)['blocks-per-epoch']
    # WARNING: Assumption that epochs are greater than 6 blocks
    while 0 <= blockchain.get_latest_header()['blockNumber'] % block_per_epoch <= 5:
        pass
    bls_metrics = validator.get_validator_information()['metrics']['by-bls-key']
    common.log(f"{Typgpy.OKBLUE}BLS key metrics: {Typgpy.OKGREEN}{json.dumps(bls_metrics, indent=2)}{Typgpy.ENDC}")
    keys_on_chain = validator.get_validator_information()['validator']['bls-public-keys']
    for metric in bls_metrics:
        if metric['earned-reward'] == 0:
            key = metric['key']['bls-public-key']
            if key not in bls_keys and key in keys_on_chain:
                prompt = f"{Typgpy.HEADER}Remove BLS key who earned zero rewards: " \
                         f"{Typgpy.OKGREEN}{key}{Typgpy.HEADER}?{Typgpy.ENDC} [Y]/n\n> "
                if not yes and util.input_with_print(prompt).lower() not in {'y', 'yes'}:
                    continue
                validator.remove_bls_key(key)
                removed_keys.append(key)


if __name__ == "__main__":
    args = parse_args()
    all_val = json_load(cli.single_call(['hmy', 'blockchain', 'validator', 'all', '--node', endpoint]))['result']
    old_logging_handlers = common.logging.getLogger('AutoNode').handlers.copy()
    common.logging.getLogger('AutoNode').addHandler(util.get_simple_rotating_log_handler(node.log_path))
    if validator_addr not in all_val:
        common.log(f"{Typgpy.FAIL}{validator_addr} is not a validator on {endpoint}.{Typgpy.ENDC}")
        exit(-1)
    keys_on_chain = validator.get_validator_information()['validator']['bls-public-keys']
    common.log(f"{Typgpy.OKBLUE}Keys of validator {Typgpy.OKGREEN}{validator_addr}{Typgpy.OKBLUE} "
               f"on chain (before cleanse): {Typgpy.OKGREEN}{keys_on_chain}{Typgpy.ENDC}")
    common.log(f"{Typgpy.OKBLUE}This node's BLS key(s): "
               f"{Typgpy.OKGREEN}{common.node_config['public-bls-keys']}{Typgpy.ENDC}")
    if args.hard:
        hard_cleanse(yes=args.yes)
    elif args.keep_shard:
        shard_cleanse(yes=args.yes)
    else:
        reward_cleanse(yes=args.yes)
    keys_on_chain = validator.get_validator_information()['validator']['bls-public-keys']
    common.log(f"{Typgpy.OKBLUE}Cleansed following BLS keys: {Typgpy.OKGREEN}{removed_keys}{Typgpy.ENDC}")
    common.log(
        f"{Typgpy.OKBLUE}Keys on validator {Typgpy.OKGREEN}{validator_addr}{Typgpy.OKBLUE} (after cleanse): "
        f"{Typgpy.OKGREEN}{keys_on_chain}{Typgpy.ENDC}")
