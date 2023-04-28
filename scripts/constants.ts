// Fantom address list.
const fantomDepAddressList = {
  "woo": "0x6626c47c00F1D87902fc13EECfaC3ed06D5E8D8a",
  "wooPP": "0x286ab107c5E9083dBed35A2B5fb0242538F4f9bf",
  "usdc": "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75",
  "weth": "0x74b23882a30290451A17c44f4F05243b6b58C76d",
};

// WooPP address doc: https://learn.woo.org/v/woofi-dev-docs/references/readme
// Arbitrum address list.
export const depAddressList = {
  "woo": "0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b",
  "usdc": "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
  "weth": "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  "wooPP": "0xeFF23B4bE1091b53205E35f3AfCD9C7182bf3062"
}

// LayerZero chain ids.
// Doc: https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids
const lz_fantom_chainid = 112;
const lz_fantom_endpoint = "0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7";
const lz_arbitrum_endpoint = "0x3c2269811836af69497E5F486A85D7316753cf62";
const lz_arbitrum_chainid = 110;

export const lz_chainid = lz_arbitrum_chainid;
export const lz_endpoint = lz_arbitrum_endpoint;

export const user1 = "0xA113d3B08df49D442fA1c0b47A82Ad95aD19c0Fb";
export const user2 = "0xea02DCC6fe3eC1F2a433fF8718677556a3bb3618";
export const user3 = "0x7C8A5d20b22Ce9b369C043A3E0091b5575B732d9";

export const stakingContractsFile = "./staking_contracts.json";
export const sleepSeconds = 10000; // 10 seconds