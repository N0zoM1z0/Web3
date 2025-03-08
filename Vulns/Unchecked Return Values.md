#### 未检查返回值（Unchecked Return Values）

 这类漏洞背后的主要原因是无法正确处理外部函数调用的返回值，这可能产生严重的后果，包括资产损失和合约逻辑的意外行为。

 在solidity中，开发者可能通过.send()、.call()、.transfer()来执行外部调用。

 .call()没有gas限制，最为灵活，是最提倡的方法；.transfer()有2300gas限制，但是发送失败**会自动[revert](https://so.csdn.net/so/search?q=revert&spm=1001.2101.3001.7020)交易**，是次优选择；.send()有2300gas限制，而且发送失败不会自动revert交易，几乎没人使用。

 每种方法在发生异常处理时会有不同的行为。.call()和.send()在调用成功或失败是会返回一个bool值，所以这两种方法执行失败后不会revert，而是返回bool值false。

 这样当没有检查返回值是，会出现一个常见的陷阱，因为开发人员希望失败是自动revert交易，但实际并没有。比如如果一个合约使用.send()而没有检查返回值，调用失败后仍会执行交易，这样会导致意想不到的行为。合约如下所示：

```solidity
/// INSECURE
//奖金发放
contract Lotto {
    bool public paidOut = false;   //用来跟踪奖金是否发放
    address payable public winner;  //接收奖金的地址
    uint256 public winAmount;   //赢家应获得的金额
 
    /// extra functionality here
    //将奖金发送给赢家
    function sendToWinner() public {
        require(!paidOut, "Lotto: Already Paid Out");   //确保奖金没有被重复发放
        winner.send(winAmount);   
        paidOut = true;
    }
 
    //在奖金发放后提取合约中剩余的ETH
    function withdrawLeftOver() public {
        require(paidOut, "Lotto: Not Paid Out Yet");
        // Assuming the caller is authorized to withdraw, e.g., contract owner
        payable(msg.sender).transfer(address(this).balance);
    }
}
```

上述合约是一个奖金发放合约，获胜者获得'winAmount'ETH，在奖金发放后提取合约中剩余的ETH。这里存在一个bug，.send()被使用但是没有检查返回值。

 在这个例子中，如果winner的交易失败，'paidOut'仍会被设置为'true'。因此，在这种情况下，任何人都可以使用withdrawLeftOver()函数提取赢家的奖金。

#### 预防技术：

 为了减轻这个漏洞，开发人员应该始终检查对外部合约的任何调用的返回值，可以使用'require'函数来检查。