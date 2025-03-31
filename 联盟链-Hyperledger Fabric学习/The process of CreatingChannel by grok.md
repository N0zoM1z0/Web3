```bash
web@web-virtual-machine:~/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network$ sudo ./network.sh createChannel -c channel1
Using docker and docker-compose
Creating channel 'channel1'.
If network is not up, starting nodes with CLI timeout of '5' tries and CLI delay of '3' seconds and using database 'leveldb 
Bringing up network
LOCAL_VERSION=v2.5.0
DOCKER_IMAGE_VERSION=v2.5.0
peer0.org2.example.com is up-to-date
peer0.org1.example.com is up-to-date
orderer.example.com is up-to-date
CONTAINER ID   IMAGE                               COMMAND             CREATED         STATUS         PORTS                                                                                                                             NAMES
00bb83dbfc7c   hyperledger/fabric-orderer:latest   "orderer"           9 minutes ago   Up 9 minutes   0.0.0.0:7050->7050/tcp, :::7050->7050/tcp, 0.0.0.0:7053->7053/tcp, :::7053->7053/tcp, 0.0.0.0:9443->9443/tcp, :::9443->9443/tcp   orderer.example.com
34075f56d3ea   hyperledger/fabric-peer:latest      "peer node start"   9 minutes ago   Up 9 minutes   0.0.0.0:9051->9051/tcp, :::9051->9051/tcp, 7051/tcp, 0.0.0.0:9445->9445/tcp, :::9445->9445/tcp                                    peer0.org2.example.com
97741c017729   hyperledger/fabric-peer:latest      "peer node start"   9 minutes ago   Up 9 minutes   0.0.0.0:7051->7051/tcp, :::7051->7051/tcp, 0.0.0.0:9444->9444/tcp, :::9444->9444/tcp                                              peer0.org1.example.com
Using docker and docker-compose
Generating channel genesis block 'channel1.block'
Using organization 1
/home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/../bin/configtxgen
+ '[' 0 -eq 1 ']'
+ configtxgen -profile ChannelUsingRaft -outputBlock ./channel-artifacts/channel1.block -channelID channel1
2025-03-27 10:57:24.945 CST 0001 INFO [common.tools.configtxgen] main -> Loading configuration
2025-03-27 10:57:24.954 CST 0002 INFO [common.tools.configtxgen.localconfig] completeInitialization -> orderer type: etcdraft
2025-03-27 10:57:24.954 CST 0003 INFO [common.tools.configtxgen.localconfig] completeInitialization -> Orderer.EtcdRaft.Options unset, setting to tick_interval:"500ms" election_tick:10 heartbeat_tick:1 max_inflight_blocks:5 snapshot_interval_size:16777216 
2025-03-27 10:57:24.954 CST 0004 INFO [common.tools.configtxgen.localconfig] Load -> Loaded configuration: /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/configtx/configtx.yaml
2025-03-27 10:57:24.960 CST 0005 INFO [common.tools.configtxgen] doOutputBlock -> Generating genesis block
2025-03-27 10:57:24.960 CST 0006 INFO [common.tools.configtxgen] doOutputBlock -> Creating application channel genesis block
2025-03-27 10:57:24.961 CST 0007 INFO [common.tools.configtxgen] doOutputBlock -> Writing genesis block
+ res=0
Creating channel channel1
Adding orderers
+ . scripts/orderer.sh channel1
+ '[' 0 -eq 1 ']'
+ res=0
2025-03-27 10:57:09.701 CST 0001 INFO [channelCmd] InitCmdFactory -> Endorser and orderer connections initialized
Error: proposal failed (err: bad proposal response 500: cannot create ledger from genesis block: ledger [mychannel] already exists with state [ACTIVE])
Status: 201
{
	"name": "channel1",
	"url": "/participation/v1/channels/channel1",
	"consensusRelation": "consenter",
	"status": "active",
	"height": 1
}

Channel 'channel1' created
Joining org1 peer to the channel...
Using organization 1
+ peer channel join -b ./channel-artifacts/channel1.block
+ res=0
2025-03-27 10:57:31.173 CST 0001 INFO [channelCmd] InitCmdFactory -> Endorser and orderer connections initialized
2025-03-27 10:57:31.215 CST 0002 INFO [channelCmd] executeJoin -> Successfully submitted proposal to join channel
Joining org2 peer to the channel...
Using organization 2
+ peer channel join -b ./channel-artifacts/channel1.block
+ res=0
2025-03-27 10:57:34.342 CST 0001 INFO [channelCmd] InitCmdFactory -> Endorser and orderer connections initialized
2025-03-27 10:57:34.393 CST 0002 INFO [channelCmd] executeJoin -> Successfully submitted proposal to join channel
Setting anchor peer for org1...
Using organization 1
Fetching channel config for channel channel1
Using organization 1
Fetching the most recent configuration block for the channel
++ peer channel fetch config /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c channel1 --tls --cafile /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
2025-03-27 10:57:34.512 CST 0001 INFO [channelCmd] InitCmdFactory -> Endorser and orderer connections initialized
2025-03-27 10:57:34.518 CST 0002 INFO [cli.common] readBlock -> Received block: 0
2025-03-27 10:57:34.518 CST 0003 INFO [channelCmd] fetch -> Retrieving last config block: 0
2025-03-27 10:57:34.521 CST 0004 INFO [cli.common] readBlock -> Received block: 0
Decoding config block to JSON and isolating config to /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org1MSPconfig.json
++ configtxlator proto_decode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_block.pb --type common.Block --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_block.json
++ jq '.data.data[0].payload.data.config' /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_block.json
++ res=0
Generating anchor peer update transaction for Org1 on channel channel1
++ jq '.channel_group.groups.Application.groups.Org1MSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.org1.example.com","port": 7051}]},"version": "0"}}' /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org1MSPconfig.json
++ res=0
++ configtxlator proto_encode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org1MSPconfig.json --type common.Config --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/original_config.pb
++ configtxlator proto_encode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org1MSPmodified_config.json --type common.Config --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/modified_config.pb
++ configtxlator compute_update --channel_id channel1 --original /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/original_config.pb --updated /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/modified_config.pb --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update.pb
++ configtxlator proto_decode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update.pb --type common.ConfigUpdate --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update.json
++ jq .
+++ cat /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update.json
++ echo '{"payload":{"header":{"channel_header":{"channel_id":"channel1", "type":2}},"data":{"config_update":{' '"channel_id":' '"channel1",' '"isolated_data":' '{},' '"read_set":' '{' '"groups":' '{' '"Application":' '{' '"groups":' '{' '"Org1MSP":' '{' '"groups":' '{},' '"mod_policy":' '"",' '"policies":' '{' '"Admins":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Endorsement":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Readers":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Writers":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '}' '},' '"values":' '{' '"MSP":' '{' '"mod_policy":' '"",' '"value":' null, '"version":' '"0"' '}' '},' '"version":' '"0"' '}' '},' '"mod_policy":' '"",' '"policies":' '{},' '"values":' '{},' '"version":' '"0"' '}' '},' '"mod_policy":' '"",' '"policies":' '{},' '"values":' '{},' '"version":' '"0"' '},' '"write_set":' '{' '"groups":' '{' '"Application":' '{' '"groups":' '{' '"Org1MSP":' '{' '"groups":' '{},' '"mod_policy":' '"Admins",' '"policies":' '{' '"Admins":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Endorsement":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Readers":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Writers":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '}' '},' '"values":' '{' '"AnchorPeers":' '{' '"mod_policy":' '"Admins",' '"value":' '{' '"anchor_peers":' '[' '{' '"host":' '"peer0.org1.example.com",' '"port":' 7051 '}' ']' '},' '"version":' '"0"' '},' '"MSP":' '{' '"mod_policy":' '"",' '"value":' null, '"version":' '"0"' '}' '},' '"version":' '"1"' '}' '},' '"mod_policy":' '"",' '"policies":' '{},' '"values":' '{},' '"version":' '"0"' '}' '},' '"mod_policy":' '"",' '"policies":' '{},' '"values":' '{},' '"version":' '"0"' '}' '}}}}'
++ configtxlator proto_encode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update_in_envelope.json --type common.Envelope --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org1MSPanchors.tx
2025-03-27 10:57:35.012 CST 0001 INFO [channelCmd] InitCmdFactory -> Endorser and orderer connections initialized
2025-03-27 10:57:35.036 CST 0002 INFO [channelCmd] update -> Successfully submitted channel update
Anchor peer set for org 'Org1MSP' on channel 'channel1'
Setting anchor peer for org2...
Using organization 2
Fetching channel config for channel channel1
Using organization 2
Fetching the most recent configuration block for the channel
++ peer channel fetch config /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c channel1 --tls --cafile /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
2025-03-27 10:57:35.184 CST 0001 INFO [channelCmd] InitCmdFactory -> Endorser and orderer connections initialized
2025-03-27 10:57:35.190 CST 0002 INFO [cli.common] readBlock -> Received block: 1
2025-03-27 10:57:35.191 CST 0003 INFO [channelCmd] fetch -> Retrieving last config block: 1
2025-03-27 10:57:35.193 CST 0004 INFO [cli.common] readBlock -> Received block: 1
Decoding config block to JSON and isolating config to /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org2MSPconfig.json
++ configtxlator proto_decode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_block.pb --type common.Block --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_block.json
++ jq '.data.data[0].payload.data.config' /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_block.json
++ res=0
Generating anchor peer update transaction for Org2 on channel channel1
++ jq '.channel_group.groups.Application.groups.Org2MSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.org2.example.com","port": 9051}]},"version": "0"}}' /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org2MSPconfig.json
++ res=0
++ configtxlator proto_encode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org2MSPconfig.json --type common.Config --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/original_config.pb
++ configtxlator proto_encode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org2MSPmodified_config.json --type common.Config --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/modified_config.pb
++ configtxlator compute_update --channel_id channel1 --original /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/original_config.pb --updated /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/modified_config.pb --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update.pb
++ configtxlator proto_decode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update.pb --type common.ConfigUpdate --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update.json
++ jq .
+++ cat /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update.json
++ echo '{"payload":{"header":{"channel_header":{"channel_id":"channel1", "type":2}},"data":{"config_update":{' '"channel_id":' '"channel1",' '"isolated_data":' '{},' '"read_set":' '{' '"groups":' '{' '"Application":' '{' '"groups":' '{' '"Org2MSP":' '{' '"groups":' '{},' '"mod_policy":' '"",' '"policies":' '{' '"Admins":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Endorsement":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Readers":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Writers":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '}' '},' '"values":' '{' '"MSP":' '{' '"mod_policy":' '"",' '"value":' null, '"version":' '"0"' '}' '},' '"version":' '"0"' '}' '},' '"mod_policy":' '"",' '"policies":' '{},' '"values":' '{},' '"version":' '"0"' '}' '},' '"mod_policy":' '"",' '"policies":' '{},' '"values":' '{},' '"version":' '"0"' '},' '"write_set":' '{' '"groups":' '{' '"Application":' '{' '"groups":' '{' '"Org2MSP":' '{' '"groups":' '{},' '"mod_policy":' '"Admins",' '"policies":' '{' '"Admins":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Endorsement":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Readers":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '},' '"Writers":' '{' '"mod_policy":' '"",' '"policy":' null, '"version":' '"0"' '}' '},' '"values":' '{' '"AnchorPeers":' '{' '"mod_policy":' '"Admins",' '"value":' '{' '"anchor_peers":' '[' '{' '"host":' '"peer0.org2.example.com",' '"port":' 9051 '}' ']' '},' '"version":' '"0"' '},' '"MSP":' '{' '"mod_policy":' '"",' '"value":' null, '"version":' '"0"' '}' '},' '"version":' '"1"' '}' '},' '"mod_policy":' '"",' '"policies":' '{},' '"values":' '{},' '"version":' '"0"' '}' '},' '"mod_policy":' '"",' '"policies":' '{},' '"values":' '{},' '"version":' '"0"' '}' '}}}}'
++ configtxlator proto_encode --input /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/config_update_in_envelope.json --type common.Envelope --output /home/web/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network/channel-artifacts/Org2MSPanchors.tx
2025-03-27 10:57:35.689 CST 0001 INFO [channelCmd] InitCmdFactory -> Endorser and orderer connections initialized
2025-03-27 10:57:35.717 CST 0002 INFO [channelCmd] update -> Successfully submitted channel update
Anchor peer set for org 'Org2MSP' on channel 'channel1'
Channel 'channel1' joined
web@web-virtual-machine:~/Desktop/Tmp/Web3-Project/Fabric/fabric-samples/test-network$ 

```



Creating a channel in Hyperledger Fabric involves defining a communication pathway between organizations on the blockchain network where transactions can occur securely. Your output shows the process executed via the `network.sh` script in the `test-network` sample of Hyperledger Fabric v2.5.0. Below, I’ll break down the entire process in detail, explaining each step, the tools involved, and the underlying mechanics based on your execution of `./network.sh createChannel -c channel1`.

---

### Overview of the Channel Creation Process
A channel in Hyperledger Fabric is a private subnet of communication between specific network members, isolated from other channels for privacy and scalability. The `createChannel` command in `network.sh` automates several steps:
1. **Generate the Channel Genesis Block**: Defines the channel’s initial configuration.
2. **Create the Channel on the Orderer**: Registers the channel with the ordering service.
3. **Join Peers to the Channel**: Connects peers from participating organizations to the channel.
4. **Set Anchor Peers**: Configures anchor peers for each organization to enable cross-org communication.

Let’s dive into each step with your output as context.

---

### Prerequisites (Already in Place)
From your output:
- **Network is Up**: Containers for `peer0.org1.example.com`, `peer0.org2.example.com`, and `orderer.example.com` are running (`docker ps -a` confirms this).
- **Tools Installed**: `configtxgen`, `peer`, `configtxlator`, and `jq` are available in `fabric-samples/bin/`.
- **Configuration Files**: `configtx.yaml` defines the network’s profiles (e.g., `ChannelUsingRaft`), and organization MSPs are set up in `organizations/`.

---

### Detailed Steps of Creating a Channel

#### Step 1: Generate the Channel Genesis Block
**Command Executed**:
```bash
configtxgen -profile ChannelUsingRaft -outputBlock ./channel-artifacts/channel1.block -channelID channel1
```

**What Happens**:
- **Tool**: `configtxgen` creates configuration transactions and genesis blocks.
- **Profile**: `ChannelUsingRaft` from `configtx.yaml` specifies a Raft-based ordering service with Org1 and Org2 in the application group.
- **Output**: Generates `channel1.block`, the genesis block for the `channel1` channel.
- **Logs**:
  - Loads `configtx.yaml`.
  - Sets Raft options (e.g., `tick_interval: "500ms"`).
  - Creates and writes the genesis block with policies, MSPs, and consortium details.

**Purpose**: The genesis block is the initial configuration of the channel, defining its members (Org1, Org2), policies (e.g., who can update the channel), and the Raft orderer.

**Output File**: `./channel-artifacts/channel1.block`.

---

#### Step 2: Create the Channel on the Orderer
**Command Executed** (via `scripts/orderer.sh`):
- Not explicitly shown but invoked as part of `createChannel`.

**What Happens**:
- **Tool**: `peer` CLI with `channel create`.
- **Process**:
  - The script uses the genesis block (`channel1.block`) to submit a channel creation request to the orderer (`orderer.example.com:7050`).
  - Environment variables set the orderer’s TLS certificates and Org1’s MSP for authentication.
- **Error in Output**: 
  ```
  Error: proposal failed (err: bad proposal response 500: cannot create ledger from genesis block: ledger [mychannel] already exists with state [ACTIVE])
  ```
  - This suggests a previous channel (likely `mychannel`, the default) exists, but the script still reports `channel1` created with status `active`. This might be a logging artifact or a prior run’s interference. For `channel1`, it proceeds correctly.

**Purpose**: Registers `channel1` with the orderer, initializing its ledger.

**Output**: Channel `channel1` is listed as active with height 1 on the orderer.

---

#### Step 3: Join Peers to the Channel
**Commands Executed**:
1. For Org1:
   ```bash
   peer channel join -b ./channel-artifacts/channel1.block
   ```
2. For Org2:
   ```bash
   peer channel join -b ./channel-artifacts/channel1.block
   ```

**What Happens**:
- **Tool**: `peer` CLI.
- **Process**:
  - **Org1**: Sets environment variables for `peer0.org1.example.com` (e.g., `CORE_PEER_LOCALMSPID=Org1MSP`, `CORE_PEER_ADDRESS=localhost:7051`) and joins using the genesis block.
  - **Org2**: Switches to `peer0.org2.example.com` (e.g., `CORE_PEER_LOCALMSPID=Org2MSP`, `CORE_PEER_ADDRESS=localhost:9051`) and joins.
- **Logs**:
  - Initializes endorser and orderer connections.
  - Submits the join proposal successfully for both peers.

**Purpose**: Connects the peers to `channel1`, enabling them to maintain a copy of the channel ledger and participate in transactions.

**Outcome**: Both `peer0.org1` and `peer0.org2` are now part of `channel1`.

---

#### Step 4: Set Anchor Peers
Anchor peers facilitate cross-organization communication via gossip protocol. This step updates the channel configuration for each org.

##### For Org1
**Sub-Steps**:
1. **Fetch Channel Config**:
   ```bash
   peer channel fetch config ./channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c channel1 --tls --cafile ...
   ```
   - Retrieves the latest config block (block 0 initially).

2. **Decode Config to JSON**:
   ```bash
   configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
   jq '.data.data[0].payload.data.config' config_block.json > Org1MSPconfig.json
   ```
   - Converts the protobuf block to JSON and isolates the config.

3. **Modify Config for Anchor Peer**:
   ```bash
   jq '.channel_group.groups.Application.groups.Org1MSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.org1.example.com","port": 7051}]},"version": "0"}}' Org1MSPconfig.json > Org1MSPmodified_config.json
   ```
   - Adds `peer0.org1.example.com:7051` as an anchor peer.

4. **Encode and Compute Update**:
   ```bash
   configtxlator proto_encode --input Org1MSPconfig.json --type common.Config --output original_config.pb
   configtxlator proto_encode --input Org1MSPmodified_config.json --type common.Config --output modified_config.pb
   configtxlator compute_update --channel_id channel1 --original original_config.pb --updated modified_config.pb --output config_update.pb
   ```
   - Encodes original and modified configs, computes the difference.

5. **Prepare and Submit Update**:
   ```bash
   configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
   echo '{"payload":{"header":{"channel_header":{"channel_id":"channel1", "type":2}},"data":{"config_update":...' > config_update_in_envelope.json
   configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output Org1MSPanchors.tx
   peer channel update -f Org1MSPanchors.tx -c channel1 -o localhost:7050 --tls --cafile ...
   ```
   - Wraps the update in an envelope and submits it to the orderer.

**Logs**:
- Successfully updates the channel config with Org1’s anchor peer.

##### For Org2
- Repeats the same process, replacing `Org1MSP` with `Org2MSP` and `peer0.org1.example.com:7051` with `peer0.org2.example.com:9051`.

**Purpose**: Ensures Org1 and Org2 can communicate via their anchor peers for gossip-based data dissemination.

**Outcome**: Anchor peers are set for both organizations on `channel1`.

---

### Full Process Summary
1. **Genesis Block Creation**: `configtxgen` generates `channel1.block`.
2. **Channel Creation**: Orderer accepts `channel1` via the genesis block.
3. **Peer Joining**: `peer0.org1` and `peer0.org2` join using `channel1.block`.
4. **Anchor Peer Setting**:
   - Fetch config, modify for anchor peers, compute update, and submit for Org1.
   - Repeat for Org2.

**Tools Used**:
- `configtxgen`: Creates genesis block.
- `peer`: Joins peers and updates channel.
- `configtxlator`: Converts between protobuf and JSON, computes updates.
- `jq`: Edits JSON configs.

**Files Generated**:
- `./channel-artifacts/channel1.block`
- Various `.pb` and `.json` files for config updates (e.g., `Org1MSPanchors.tx`).

---

### Verification
- Check channel membership:
  ```bash
  peer channel list
  ```
  - Should list `channel1` for both peers (run with Org1 and Org2 env vars).
- Inspect the ledger:
  ```bash
  peer channel getinfo -c channel1
  ```
  - Shows blockchain height (e.g., 2 after anchor updates).

---

### Notes
- **Raft Orderer**: Your network uses Raft for consensus, as seen in `ChannelUsingRaft`.
- **Error Handling**: The `mychannel` error suggests a prior run; clean up with `./network.sh down` if needed before retrying.
- **Manual Execution**: You can replicate this manually by running each command from the script (`scripts/createChannel.sh`) instead of using `network.sh`.

This detailed breakdown covers the entire process as executed in your test network. Let me know if you want to explore any step further or deploy chaincode next!