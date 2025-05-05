在看Sherlock的一次audit时学习到了这个，记录下。 再次说明，找到missing check这种，一定要brainstorm出具体的危害性！才可能valid。
直接上实例：
存在问题的代码：
```solidity
    /**
        @notice Allows any address which is an alias of a KYC address to claim tokens across multiple rounds which provide that token
        @param _params A ClaimParams struct describing the desired claim(s)
     */
    function claim(ClaimParams memory _params) public { // missing check for msg.sender!!! ACL!!!
    // 可导致抢跑攻击 Front-running!
    /*
    Exploit Scenario:
    攻击者监控内存池 (mempool)。
    发现一个合法的、即将被执行的 claim 交易（由用户 A 发起，或者由一个可信的中继器 R 代表用户 A 发起）。
    攻击者复制该交易的 calldata，其中包含了所有有效的 ClaimParams（包括用户 A 的 kycAddress 和 signer 的有效签名）。
    攻击者使用相同的 calldata，但以自己的地址作为 msg.sender，并设置更高的 Gas Price 发起一个新的交易。
    由于 Gas Price 更高，矿工优先打包攻击者的交易。
    攻击者的交易执行 claim 函数。因为签名和参数对于 kycAddress 是有效的，检查通过。代币被发送到 msg.sender，也就是攻击者的地址。同时，与 kycAddress 关联的 nonce 被更新。
    当用户 A 或中继器 R 的原始交易最终被尝试执行时，会因为 nonce 无效而失败 (revert InvalidNonce)。
    */
        if (claimIsPaused) {
            revert ClaimIsPaused();
        }

        if (_params.projectTokenProxyWallets.length != _params.tokenAmountsToClaim.length) {
            revert ArrayLengthMismatch();
        }

        if (_params.nonce <= nonces[_params.kycAddress]) {
            revert InvalidNonce();
        }

        if (!_isSignatureValid(_params)) {
            revert InvalidSignature();
        }

        // update nonce
        nonces[_params.kycAddress] = _params.nonce;

        // define token to transfer
        IERC20 projectToken = IERC20(_params.projectTokenAddress);

        // transfer tokens from each wallet to the caller
        for (uint256 i = 0; i < _params.projectTokenProxyWallets.length; i++) {
            projectToken.safeTransferFrom(
                _params.projectTokenProxyWallets[i],
                msg.sender,
                _params.tokenAmountsToClaim[i]
            );
        }

        emit VCClaim(
            _params.kycAddress,
            _params.projectTokenAddress,
            _params.projectTokenProxyWallets,
            _params.tokenAmountsToClaim,
            _params.nonce
        );
    }
```

report:
Token Claim Hijacking Due to Missing Validation
Summary
The VVVVCTokenDistributor contract is vulnerable to a frontrunning attack due to missing validation of the msg.sender during the claim process. An attacker can exploit this by observing pending valid transactions and preemptively executing them with a higher gas price, thus claiming tokens intended for other users.

Root Cause
Lack of msg.sender Validation:

The claim function directly transfers tokens to msg.sender without checking if this address is the same as the kycAddress. This oversight allows any arbitrary address to execute the claim given access to a valid signature and calldata.

https://github.com/sherlock-audit/2024-11-vvv-exchange-update/blob/1791f41b310489aaa66de349ef1b9e4bd331f14b/vvv-platform-smart-contracts/contracts/vc/VVVVCTokenDistributor.sol#L106C4-L136C10
```solidity
function claim(ClaimParams memory _params) public {  
    if (claimIsPaused) {  
        revert ClaimIsPaused();  
    }  

    if (_params.projectTokenProxyWallets.length != _params.tokenAmountsToClaim.length) {  
        revert ArrayLengthMismatch();  
    }  

    if (_params.nonce <= nonces[_params.kycAddress]) {  
        revert InvalidNonce();  
    }  

    if (!_isSignatureValid(_params)) {  
        revert InvalidSignature();  
    }  

    // update nonce  
    nonces[_params.kycAddress] = _params.nonce;  

    // define token to transfer  
    IERC20 projectToken = IERC20(_params.projectTokenAddress);  

    // transfer tokens from each wallet to the caller  
    for (uint256 i = 0; i < _params.projectTokenProxyWallets.length; i++) {  
        projectToken.safeTransferFrom(  
            _params.projectTokenProxyWallets[i],  
            msg.sender,  
            _params.tokenAmountsToClaim[i]  
        );  
    }
```
Internal pre-conditions
none

External pre-conditions
none

**Attack Path**
An attacker can exploit this vulnerability through the following steps:

Monitoring Transactions:

The attacker continuously monitors the Ethereum network for pending transactions targeting the VVVVCTokenDistributor contract, specifically those invoking the claim function.
Identifying Valid Claims:

The attacker identifies a pending transaction with valid ClaimParams and a correctly generated signature, submitted by a legitimate user intending to claim their tokens.
Replicating Transaction Data:

The attacker copies the calldata from the pending transaction. This calldata contains all necessary details, including the signature proving the claim’s validity.
Executing Frontrunning Attack:

The attacker creates a new transaction using the copied calldata, setting themselves as the msg.sender.
They submit this new transaction with a higher gas price, incentivizing miners to prioritize it over the original pending transaction.
Claiming Tokens:

Once mined, the attacker’s transaction executes before the original one, allowing them to receive the tokens intended for the legitimate claimant.

Impact
The ability to front-run valid claims effectively nullifies the security guarantees provided by the cryptographic signature process, allowing attackers to exploit the system for illicit gain.

PoC
Setup:

A legitimate user intends to execute a claim for tokens using the claim function, constructing valid ClaimParams with a correct signature.

Transaction Broadcast:

The user broadcasts their transaction on the Ethereum network, intending to receive tokens from specified proxy wallets into their own address.

Attacker Monitoring:

An attacker monitors pending transactions on the network, focusing on those interacting with the VVVVCTokenDistributor contract.

Data Replication:

Upon identifying the legitimate transaction, the attacker copies the calldata, including the ClaimParams and signature, retaining all necessary details.

Frontrunning Execution:

The attacker submits their own transaction using the duplicated calldata but specifies themselves as msg.sender.
The attacker sets a higher gas price to prioritize their transaction over the original.

Successful Claim Theft:

The attacker’s transaction gets mined before the original, claiming the tokens intended for the legitimate user.
The original user’s transaction fails due to the incremented nonce, rendering their claim invalid.

Mitigation
Modify the claim function to include a check ensuring that msg.sender matches the kycAddress specified in the ClaimParams. This alignment verifies that the account executing the claim is the same account authorized to receive the tokens.
```solidity
function claim(ClaimParams memory _params) public {  
    require(msg.sender == _params.kycAddress, "Sender not authorized to claim on behalf of KYC address");  
    // ... existing claim logic ...  
}
```
