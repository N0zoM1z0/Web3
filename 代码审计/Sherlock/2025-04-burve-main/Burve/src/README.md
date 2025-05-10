There are four token balances to consider
- Value: This balance of the token which is swapped 1 to 1 with a value token.
- Reserve: The amount of tokens in a cid that can't be swapped in or out directly and are used to support slippage.
- Fees: The amount of tokens distributed as fee earnings to assets.
- Amount: The literal amount of tokens swapped in or out which is the sum of value, reserve, and fees.

Liquidity is about the value in a cid. Adding liquidity moves the value in each token up.
This involves changing the actual the amount of tokens. So for example, if you say the person needs to remove 10 token amounts from
a current amount of 100, the pool will say it you've removed 10.1 units of value due to slippage.
Without slippage, the person would have removed 10.1 token amounts, with slippage, they remove 10 and 0.1 goes to the reserve.


