import os
import subprocess
from dataclasses import dataclass
from typing import Dict, List, NotRequired, Optional

import requests
from eth_account import Account
from eth_account.account import LocalAccount
from eth_account.hdaccount import key_from_seed, seed_from_mnemonic
from typing_extensions import TypedDict
from web3 import Web3

DEFAULT_IMAGE = "ghcr.io/foundry-rs/foundry:latest"
DEFAULT_DERIVATION_PATH = "m/44'/60'/0'/0/"
DEFAULT_ACCOUNTS = 10
DEFAULT_BALANCE = 1000
DEFAULT_MNEMONIC = "test test test test test test test test test test test junk"

PUBLIC_HOST = os.getenv("PUBLIC_HOST", f"http://{requests.get('https://ifconfig.me/').text}:8545")


class LaunchAnvilInstanceArgs(TypedDict):
    image: NotRequired[Optional[str]]
    accounts: NotRequired[Optional[int]]
    balance: NotRequired[Optional[float]]
    derivation_path: NotRequired[Optional[str]]
    mnemonic: NotRequired[Optional[str]]
    fork_url: NotRequired[Optional[str]]
    fork_block_num: NotRequired[Optional[int]]
    fork_chain_id: NotRequired[Optional[int]]
    no_rate_limit: NotRequired[Optional[bool]]
    chain_id: NotRequired[Optional[int]]
    code_size_limit: NotRequired[Optional[int]]
    block_time: NotRequired[Optional[str]]
    hardfork: NotRequired[Optional[str]]


def format_anvil_args(args: LaunchAnvilInstanceArgs, anvil_id: str, port: int = 8545) -> List[str]:
    cmd_args = []
    cmd_args += ["--host", "0.0.0.0"]
    cmd_args += ["--port", str(port)]
    cmd_args += ["--accounts", "0"]
    cmd_args += ["--state", f"/data/{anvil_id}-state.json"]
    cmd_args += ["--state-interval", "5"]
    cmd_args += ["--disable-code-size-limit"]

    if args.get("hardfork") is not None:
        cmd_args += ["--hardfork", args["hardfork"]]

    if args.get("fork_url") is not None:
        cmd_args += ["--fork-url", args["fork_url"]]

    if args.get("fork_chain_id") is not None:
        cmd_args += ["--fork-chain-id", str(args["fork_chain_id"])]

    if args.get("fork_block_num") is not None:
        cmd_args += ["--fork-block-number", str(args["fork_block_num"])]

    if args.get("no_rate_limit") == True:
        cmd_args += ["--no-rate-limit"]

    if args.get("chain_id") is not None:
        cmd_args += ["--chain-id", str(args["chain_id"])]

    if args.get("code_size_limit") is not None:
        cmd_args += ["--code-size-limit", str(args["code_size_limit"])]

    if args.get("block_time") is not None:
        cmd_args += ["--block-time", str(args["block_time"])]

    return cmd_args


class DaemonInstanceArgs(TypedDict):
    image: str


class CreateInstanceRequest(TypedDict):
    instance_id: str
    timeout: int
    anvil_instances: NotRequired[Dict[str, LaunchAnvilInstanceArgs]]
    daemon_instances: NotRequired[Dict[str, DaemonInstanceArgs]]


class InstanceInfo(TypedDict):
    id: str
    ip: str
    port: int


@dataclass
class AnvilInstance:
    proc: subprocess.Popen
    id: str

    ip: str
    port: int


class UserData(TypedDict):
    instance_id: str
    external_id: str
    created_at: float
    expires_at: float
    # launch_args: Dict[str, LaunchAnvilInstanceArgs]
    anvil_instances: Dict[str, InstanceInfo]
    daemon_instances: Dict[str, InstanceInfo]
    metadata: Dict

    # def get_privileged_account(self, offset: int) -> LocalAccount:
    #     seed = seed_from_mnemonic(self.mnemonic, "")
    #     private_key = key_from_seed(seed, f"m/44'/60'/0'/0/{offset}")

    #     return Account.from_key(private_key)

    # def get_player_account(self) -> LocalAccount:
    #     return self.get_privileged_account(0)

    # def get_system_account(self) -> LocalAccount:
    #     return self.get_privileged_account(1)

    # def get_additional_account(self, offset: int) -> LocalAccount:
    #     return self.get_privileged_account(offset + 2)

    # def get_privileged_web3(self, id: str) -> Web3:
    #     return Web3(Web3.HTTPProvider(f"http://127.0.0.1:{self.instances[id].port}"))

    # def get_unprivileged_web3(self, id: str) -> Web3:
    #     return Web3(
    #         Web3.HTTPProvider(
    #             f"http://127.0.0.1:8545/{self.internal_id}/{id}",
    #             request_kwargs={"timeout": 60},
    #         )
    #     )


def get_account(mnemonic: str, offset: int) -> LocalAccount:
    seed = seed_from_mnemonic(mnemonic, "")
    private_key = key_from_seed(seed, f"{DEFAULT_DERIVATION_PATH}{offset}")

    return Account.from_key(private_key)


def get_player_account(mnemonic: str) -> LocalAccount:
    return get_account(mnemonic, 0)


def get_system_account(mnemonic: str) -> LocalAccount:
    return get_account(mnemonic, 1)


def get_additional_account(mnemonic: str, offset: int) -> LocalAccount:
    return get_account(mnemonic, offset + 2)

def get_privileged_web3(user_data: UserData, anvil_id: str) -> Web3:
    anvil_instance = user_data["anvil_instances"][anvil_id]
    return Web3(
        Web3.HTTPProvider(f"http://{anvil_instance['ip']}:{anvil_instance['port']}")
    )


def get_unprivileged_web3(user_data: UserData, anvil_id: str) -> Web3:
    return Web3(
        Web3.HTTPProvider(
            f"http://anvil-proxy:8545/{user_data['external_id']}/{anvil_id}"
        )
    )
