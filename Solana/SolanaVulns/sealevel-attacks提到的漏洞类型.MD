# 前置知识

## AccountInfo

```rust
/// Account information
#[derive(Clone)]
pub struct AccountInfo<'a> {
    /// Public key of the account
    pub key: &'a Pubkey,
    /// Was the transaction signed by this account's public key?
    pub is_signer: bool,
    /// Is the account writable?
    pub is_writable: bool,
    /// The lamports in the account.  Modifiable by programs.
    pub lamports: Rc<RefCell<&'a mut u64>>,
    /// The data held in this account.  Modifiable by programs.
    pub data: Rc<RefCell<&'a mut [u8]>>,
    /// Program that owns this account
    pub owner: &'a Pubkey,
    /// This account's data contains a loaded program (and is now read-only)
    pub executable: bool,
    /// The epoch at which this account will next owe rent
    pub rent_epoch: Epoch,
}
```

## TokenAccount

```rust
/// Account data.
#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Account {
    /// The mint associated with this account
    pub mint: Pubkey,
    /// The owner of this account.
    pub owner: Pubkey,
    /// The amount of tokens this account holds.
    pub amount: u64,
    /// If `delegate` is `Some` then `delegated_amount` represents
    /// the amount authorized by the delegate
    pub delegate: COption<Pubkey>,
    /// The account's state
    pub state: AccountState,
    /// If is_some, this is a native token, and the value logs the rent-exempt reserve. An Account
    /// is required to be rent-exempt, so the value is used by the Processor to ensure that wrapped
    /// SOL accounts do not drop below this threshold.
    pub is_native: COption<u64>,
    /// The amount delegated
    pub delegated_amount: u64,
    /// Optional authority to close the account.
    pub close_authority: COption<Pubkey>,
}
```



## PDA in Solana

> ### Solana 中的 PDA（Program Derived Address）
>
> #### 概念
>
> **PDA（Program Derived Address，程序派生地址）** 是 Solana 中一种特殊的账户地址，由程序的 ID 和一组自定义的 `seeds`（种子数据）通过哈希算法生成。其核心特性是：
>
> - **无对应私钥**：PDA 地址不在椭圆曲线 Ed25519 上，无法被外部用户通过私钥签名控制。
> - **程序自主控制**：只有生成该 PDA 的程序（通过 `program_id`）可以操作其关联的账户，如签名跨程序调用（CPI）。
>
> #### 生成方式
>
> 通过 `find_program_address` 函数生成，包含以下步骤：
>
> 1. **输入参数**：`seeds`（自定义数据） + `program_id`（程序 ID）。
> 2. **哈希计算**：使用 SHA-256 对 `seeds + program_id` 进行哈希。
> 3. **验证曲线**：若结果在 Ed25519 曲线上，调整 `bump` 值（从 255 递减）重新计算，直到找到有效的 PDA。
>
> #### 重要性
>
> 1. **安全状态管理** PDA 允许程序自主管理链上状态（如存储数据或代币），无需依赖外部账户的签名，避免私钥泄露风险。
> 2. **权限隔离**
>    - **程序专属操作**：只有生成 PDA 的程序能对其签名（通过 CPI），确保权限边界清晰。
>    - **防篡改**：外部用户无法伪造 PDA 的签名，保障合约逻辑安全。
> 3. **灵活的资源控制**
>    - **动态生成**：通过不同 `seeds` 为每个用户或场景生成独立 PDA（如每个用户的托管账户）。
>    - **跨程序交互**：程序可通过 PDA 安全调用其他程序（如代币转账），无需用户逐笔签名。
> 4. **典型应用场景**
>    - **代币托管**：每个用户的代币账户由程序通过 PDA 管理。
>    - **流动性池**：DEX 的交易对资金池地址通过 PDA 生成。
>    - **权限委托**：程序通过 PDA 代表用户执行批量操作（如 NFT 批量上架）。
>
> #### 代码示例
>
> ```rust
> // 生成 PDA
> let (pda, bump) = Pubkey::find_program_address(
>     &[b"vault", user.key.as_ref()], // seeds: 固定字符 + 用户地址
>     program_id
> );
> 
> // 使用 PDA 签名 CPI
> invoke_signed(
>     &transfer_instruction,
>     &[source, destination, pda],
>     &[&[b"vault", user.key.as_ref(), &[bump]]] // 签名所需的 seeds
> );
> ```
>
> ### 总结
>
> PDA 是 Solana 智能合约设计的核心机制，通过**程序自主控制资源和权限**，解决了**去中心化**应用中状态管理、安全交互和权限隔离的关键问题，是构建复杂 DApp 的基础设施。

# 0. signer authorization

insecure:

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");
#[program]
pub mod signer_authorization_insecure {
    use super::*;

    pub fn log_message(ctx: Context<LogMessage>) -> ProgramResult {
        msg!("GM {}", ctx.accounts.authority.key().to_string());
        Ok(())
    }
}

#[derive(Accounts)]
pub struct LogMessage<'info> {
    authority: AccountInfo<'info>,
}

```

意思是，这个地方：

```rust
pub struct LogMessage<'info> {
    authority: AccountInfo<'info>,
}
```

给authority的是AccountInfo，而没有校验 authority 的身份。

---

对比看下recommend的写法：

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod signer_authorization_recommended {
    use super::*;

    pub fn log_message(ctx: Context<LogMessage>) -> ProgramResult {
        msg!("GM {}", ctx.accounts.authority.key().to_string());
        Ok(())
    }
}

#[derive(Accounts)]
pub struct LogMessage<'info> {
    authority: Signer<'info>, // <======
}
```

recommend是把最common的AccountInfo改为了Signer

---

secure的写法，是不依赖authority的那个级别，而是在log_message函数内进行权限check：

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod signer_authorization_secure {
    use super::*;

    pub fn log_message(ctx: Context<LogMessage>) -> ProgramResult {
        if !ctx.accounts.authority.is_signer { // <=====
            return Err(ProgramError::MissingRequiredSignature);
        }
        msg!("GM {}", ctx.accounts.authority.key().to_string());
        Ok(())
    }
}

#[derive(Accounts)]
pub struct LogMessage<'info> {
    authority: AccountInfo<'info>,
}

```



---

哦，recommend是最安全的写法，secure只是没大的安全隐患，但是也不推荐。。

比如ds给的可能的漏洞点：

- **验证时机滞后**：检查发生在指令逻辑内部，攻击者可能通过构造恶意输入绕过某些前置条件。

之前看Solana也会看到一些“指令间会被插入恶意指令”的这种情况，🤔



# 1. account data matching

insecure:

```rust
use anchor_lang::prelude::*;
use anchor_lang::solana_program::program_pack::Pack;
use spl_token::state::Account as SplTokenAccount;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod account_data_matching_insecure {
    use super::*;

    pub fn log_message(ctx: Context<LogMessage>) -> ProgramResult {
        let token = SplTokenAccount::unpack(&ctx.accounts.token.data.borrow())?;
        msg!("Your account balance is: {}", token.amount);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct LogMessage<'info> {
    token: AccountInfo<'info>,
    authority: Signer<'info>,
}

```

这里是没有验证账户的真实性，看recommend的修复就懂了：也就是验证调用者是不是token的owner

类比solidity：

```solidity
require(msg.sender==token.owner)
// or
modifier onlyOwner()
```

---

```rust
use anchor_lang::prelude::*;
use anchor_spl::token::TokenAccount;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod account_data_matching_recommended {
    use super::*;

    pub fn log_message(ctx: Context<LogMessage>) -> ProgramResult {
        msg!("Your account balance is: {}", ctx.accounts.token.amount);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct LogMessage<'info> {
    #[account(constraint = authority.key == &token.owner)] // <====
    token: Account<'info, TokenAccount>,
    authority: Signer<'info>,
}

```

注意这里要取地址

---

secure的写法：

```rust
use anchor_lang::prelude::*;
use anchor_lang::solana_program::program_pack::Pack;
use spl_token::state::Account as SplTokenAccount;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod account_data_matching_secure {
    use super::*;

    pub fn log_message(ctx: Context<LogMessage>) -> ProgramResult {
        let token = SplTokenAccount::unpack(&ctx.accounts.token.data.borrow())?;
        if ctx.accounts.authority.key != &token.owner {
            return Err(ProgramError::InvalidAccountData);
        }
        msg!("Your acocunt balance is: {}", token.amount);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct LogMessage<'info> {
    token: AccountInfo<'info>,
    authority: Signer<'info>,
}

```



# 2. owner checks

感觉就是说1的secure的修复并不完善。

还需要检查这个：即这个token是不是一个合法的token，避免后续对spl_token的操作出现问题。

```rust
ctx.accounts.token.owner != &spl_token::ID
```

所以最好的做法就是在struct那儿把constraint写好



insecure:

```rust
use anchor_lang::prelude::*;
use anchor_lang::solana_program::program_error::ProgramError;
use anchor_lang::solana_program::program_pack::Pack;
use spl_token::state::Account as SplTokenAccount;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod owner_checks_insecure {
    use super::*;

    pub fn log_message(ctx: Context<LogMessage>) -> ProgramResult {
        let token = SplTokenAccount::unpack(&ctx.accounts.token.data.borrow())?;
        if ctx.accounts.authority.key != &token.owner {
            return Err(ProgramError::InvalidAccountData);
        }
        msg!("Your account balance is: {}", token.amount);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct LogMessage<'info> {
    token: AccountInfo<'info>,
    authority: Signer<'info>,
}

```



---

recommend:

```rust
use anchor_lang::prelude::*;
use anchor_spl::token::TokenAccount;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod owner_checks_recommended {
    use super::*;

    pub fn log_message(ctx: Context<LogMessage>) -> ProgramResult {
        msg!("Your account balance is: {}", ctx.accounts.token.amount);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct LogMessage<'info> {
    #[account(constraint = authority.key == &token.owner)]
    token: Account<'info, TokenAccount>,
    authority: Signer<'info>,
}

```





---

secure:

```rust
use anchor_lang::prelude::*;
use anchor_lang::solana_program::program_error::ProgramError;
use anchor_lang::solana_program::program_pack::Pack;
use spl_token::state::Account as SplTokenAccount;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod owner_checks_secure {
    use super::*;

    pub fn log_message(ctx: Context<LogMessage>) -> ProgramResult {
        let token = SplTokenAccount::unpack(&ctx.accounts.token.data.borrow())?;
        if ctx.accounts.token.owner != &spl_token::ID {
            return Err(ProgramError::InvalidAccountData);
        }
        if ctx.accounts.authority.key != &token.owner {
            return Err(ProgramError::InvalidAccountData);
        }
        msg!("Your account balance is: {}", token.amount);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct LogMessage<'info> {
    token: AccountInfo<'info>,
    authority: Signer<'info>,
}

```

> ### 1. 第一个 `if`：验证 Token 账户的程序所有者
>
> ```rust
> if ctx.accounts.token.owner != &spl_token::ID {
>     return Err(ProgramError::InvalidAccountData);
> }
> ```
>
> #### 🔍 检查目的
>
> - **确保 `token` 账户是合法的 SPL 代币账户** 验证账户的 `owner` 字段（即账户的所属程序）必须是 `spl_token::ID`（SPL 代币程序 ID）。 // <==================
>
> #### 🛡️ 防御的漏洞
>
> - **伪造代币账户攻击** 防止攻击者传入一个非 SPL 代币账户（如普通系统账户或其他程序的账户），导致后续解析数据时出现错误或恶意数据泄露。
>
> ### 2. 第二个 `if`：验证调用者权限
>
> ```rust
> if ctx.accounts.authority.key != &token.owner {
>     return Err(ProgramError::InvalidAccountData);
> }
> ```
>
> #### 🔍 检查目的
>
> - **确保调用者（`authority`）是代币账户的合法拥有者** 比较签名者地址（`authority.key`）与代币账户数据中记录的拥有者地址（`token.owner`），确保两者一致。
>
> #### 🛡️ 防御的漏洞
>
> - **越权访问攻击** 防止非代币账户拥有者（例如其他用户）通过伪造签名非法查看他人余额。



# 3. type cosplay

insecure:

类型混淆漏洞：？ 类比Java不安全的反序列化就可以理解了）

> #### 1. **数据结构定义**
>
> ```rust
> #[derive(BorshSerialize, BorshDeserialize)]
> pub struct User { authority: Pubkey }
> 
> #[derive(BorshSerialize, BorshDeserialize)]
> pub struct Metadata { account: Pubkey }
> ```
>
> - `User` 和 `Metadata` 结构体都包含一个 `Pubkey` 类型字段，但语义不同。
> - Borsh 反序列化时按**字段顺序**而非名称解析数据。
>
> #### 2. **攻击场景**
>
> - 攻击者创建一个Metadata 账户，数据为：
>
>   ```rust
>   Metadata { account: attacker_key }
>   ```
>
> - 将此账户作为 `user` 参数传入 `update_user` 函数。
>
> - 程序调用 `User::try_from_slice` 反序列化时，`Metadata.account` 会被错误解析为 `User.authority`。
>
> - 此时 `user.authority == attacker_key`，而 `authority` 签名为攻击者，**绕过检查**。
>
> #### 3. **漏洞核心**
>
> - **缺少类型标识符**：未在数据中存储类型标记（如 `discriminator`），无法区分 `User` 和 `Metadata`。
> - **依赖字段顺序而非语义**：Borsh 反序列化时仅按字段顺序匹配，导致类型混淆。

```rust
use anchor_lang::prelude::*;
use borsh::{BorshDeserialize, BorshSerialize};

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod type_cosplay_insecure {
    use super::*;

    pub fn update_user(ctx: Context<UpdateUser>) -> ProgramResult {
        let user = User::try_from_slice(&ctx.accounts.user.data.borrow()).unwrap(); // 反序列化
        if ctx.accounts.user.owner != ctx.program_id {
            return Err(ProgramError::IllegalOwner);
        }
        if user.authority != ctx.accounts.authority.key() {
            return Err(ProgramError::InvalidAccountData);
        }
        msg!("GM {}", user.authority);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct UpdateUser<'info> {
    user: AccountInfo<'info>,
    authority: Signer<'info>,
}

#[derive(BorshSerialize, BorshDeserialize)]
pub struct User {
    authority: Pubkey,
}

#[derive(BorshSerialize, BorshDeserialize)]
pub struct Metadata {
    account: Pubkey,
}

```



---

recommend: 不用Borsh反序列化

```rust
use anchor_lang::prelude::*;
use borsh::{BorshDeserialize, BorshSerialize};

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod type_cosplay_recommended {
    use super::*;

    pub fn update_user(ctx: Context<UpdateUser>) -> ProgramResult {
        msg!("GM {}", ctx.accounts.user.authority);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct UpdateUser<'info> {
    #[account(has_one = authority)]
    user: Account<'info, User>,
    authority: Signer<'info>,
}

#[account]
pub struct User {
    authority: Pubkey,
}

#[account]
pub struct Metadata {
    account: Pubkey,
}

```

---

secure:

check discriminant

```rust
use anchor_lang::prelude::*;
use borsh::{BorshDeserialize, BorshSerialize};

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod type_cosplay_secure {
    use super::*;

    pub fn update_user(ctx: Context<UpdateUser>) -> ProgramResult {
        let user = User::try_from_slice(&ctx.accounts.user.data.borrow()).unwrap();
        if ctx.accounts.user.owner != ctx.program_id {
            return Err(ProgramError::IllegalOwner);
        }
        if user.authority != ctx.accounts.authority.key() {
            return Err(ProgramError::InvalidAccountData);
        }
        if user.discriminant != AccountDiscriminant::User {
            return Err(ProgramError::InvalidAccountData);
        }
        msg!("GM {}", user.authority);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct UpdateUser<'info> {
    user: AccountInfo<'info>,
    authority: Signer<'info>,
}

#[derive(BorshSerialize, BorshDeserialize)]
pub struct User {
    discriminant: AccountDiscriminant,
    authority: Pubkey,
}

#[derive(BorshSerialize, BorshDeserialize)]
pub struct Metadata {
    discriminant: AccountDiscriminant,
    account: Pubkey,
}

#[derive(BorshSerialize, BorshDeserialize, PartialEq)]
pub enum AccountDiscriminant {
    User,
    Metadata,
}

```



# 4. initialization

insecure:

> ####  **未检查账户初始化状态**
>
> ```rust
> pub fn initialize(ctx: Context<Initialize>) -> ProgramResult {
>     let mut user = User::try_from_slice(&ctx.accounts.user.data.borrow()).unwrap(); // 假设账户已初始化
>     user.authority = ctx.accounts.authority.key();
>     // ...
> }
> ```
>
> - **问题**：直接解析 `user` 账户数据，假设该账户已初始化。攻击者可传入 **已初始化账户**，导致数据被意外覆盖。
> - **风险**：恶意用户可通过重复调用此指令篡改他人账户权限。

```rust
use anchor_lang::prelude::*;
use borsh::{BorshDeserialize, BorshSerialize};
use std::ops::DerefMut;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod initialization_insecure {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> ProgramResult {
        let mut user = User::try_from_slice(&ctx.accounts.user.data.borrow()).unwrap();

        user.authority = ctx.accounts.authority.key();

        let mut storage = ctx.accounts.user.try_borrow_mut_data()?;
        user.serialize(storage.deref_mut()).unwrap();
        Ok(())
    }
}

/*
- reinitialize
- create and dont initialize
- passing previously initialzed accounts from other programs
  (e.g. token program => need to check delegate and authority)
*/

#[derive(Accounts)]
pub struct Initialize<'info> {
    user: AccountInfo<'info>,
    authority: Signer<'info>,
}

#[derive(BorshSerialize, BorshDeserialize)]
pub struct User {
    authority: Pubkey,
}

```



---

recommend:

在结构体那儿加

```rust
#[account(init, payer = authority, space = 8+32)]
```



```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod reinitialization_4 {
    use super::*;

    pub fn init(_ctx: Context<Init>) -> ProgramResult {
        msg!("GM");
        Ok(())
    }
}


#[derive(Accounts)]
pub struct Init<'info> {
    #[account(init, payer = authority, space = 8+32)]
    user: Account<'info, User>,
    #[account(mut)]
    authority: Signer<'info>,
    system_program: Program<'info, System>,
}

#[account]
pub struct User {
    authority: Pubkey,
}

```



# 5. arbitary cpi

**未经验证的跨程序调用（Arbitrary CPI）**

insecure:

> #### 1. **未验证 `authority` 的签名权限**
>
> ```rust
> authority: AccountInfo<'info>, // 未标记为 Signer
> ```
>
> - **风险**：攻击者可传入任意 `authority` 账户（无需签名），伪造转账授权。
> - **后果**：任意用户可盗取 `source` 账户中的代币。
>
> #### 2. **未验证 `token_program` 身份**
>
> ```rust
> token_program: AccountInfo<'info>, // 未验证是否为 spl_token::ID
> ```
>
> - **风险**：攻击者可替换恶意代币程序，篡改转账逻辑。
> - **后果**：资金可能转入攻击者控制的合约。
>
> #### 3. **未验证代币账户关系**
>
> ```rust
> source: AccountInfo<'info>,
> destination: AccountInfo<'info>,
> ```
>
> - 风险：
>   - `source` 可能非 SPL 代币账户。
>   - `destination` 可能属于其他代币类型（mint 不匹配）。
> - **后果**：数据解析错误或资产错误转移。

```rust
use anchor_lang::prelude::*;
use anchor_lang::solana_program;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod arbitrary_cpi_insecure {
    use super::*;

    pub fn cpi(ctx: Context<Cpi>, amount: u64) -> ProgramResult {
        solana_program::program::invoke(
            &spl_token::instruction::transfer(
                ctx.accounts.token_program.key,
                ctx.accounts.source.key,
                ctx.accounts.destination.key,
                ctx.accounts.authority.key,
                &[],
                amount,
            )?,
            &[
                ctx.accounts.source.clone(),
                ctx.accounts.destination.clone(),
                ctx.accounts.authority.clone(),
            ],
        )
    }
}

#[derive(Accounts)]
pub struct Cpi<'info> {
    source: AccountInfo<'info>,
    destination: AccountInfo<'info>,
    authority: AccountInfo<'info>,
    token_program: AccountInfo<'info>,
}

```



---

recommend:

```rust
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount};

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod arbitrary_cpi_recommended {
    use super::*;

    pub fn cpi(ctx: Context<Cpi>, amount: u64) -> ProgramResult {
        token::transfer(ctx.accounts.transfer_ctx(), amount)
    }
}

#[derive(Accounts)]
pub struct Cpi<'info> {
    source: Account<'info, TokenAccount>,
    destination: Account<'info, TokenAccount>,
    authority: Signer<'info>, // <=== authority一定要是Signer！！！
    token_program: Program<'info, Token>,
}

impl<'info> Cpi<'info> {
    pub fn transfer_ctx(&self) -> CpiContext<'_, '_, '_, 'info, token::Transfer<'info>> {
        let program = self.token_program.to_account_info();
        let accounts = token::Transfer {
            from: self.source.to_account_info(),
            to: self.destination.to_account_info(),
            authority: self.authority.to_account_info(),
        };
        CpiContext::new(program, accounts) // 使用 Anchor 的安全 CPI 方法
    }
}

```



# 6. duplicate mutable accounts

insecure:

存在 **重复可变账户引用** 和 **未验证账户唯一性** 的漏洞，

主要是账户唯一性的问题会导致Solana交易失败

> #### 1. **未标记可变性约束**
>
> ```rust
> #[derive(Accounts)]
> pub struct Update<'info> {
>     user_a: Account<'info, User>, // 未标记 #[account(mut)]
>     user_b: Account<'info, User>,
> }
> ```
>
> - **问题**：`user_a` 和 `user_b` 未被明确标记为 `mut`，但函数内尝试修改其数据。
> - **Anchor 行为**：若未标记 `mut`，Anchor 框架会自动拒绝修改操作（运行时错误）。
>
> #### 2. **未验证账户唯一性**
>
> ```rust
> pub fn update(ctx: Context<Update>, a: u64, b: u64) -> ProgramResult {
>     let user_a = &mut ctx.accounts.user_a; // 可能指向同一账户
>     let user_b = &mut ctx.accounts.user_b;
> 
>     user_a.data = a;
>     user_b.data = b; // 若 user_a == user_b，导致重复修改冲突
> }
> ```
>
> - **风险**：若攻击者传入 `user_a` 和 `user_b` 为同一账户，会触发 Solana 运行时对 **同一账户多次可变引用** 的禁止，导致交易失败。

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod duplicate_mutable_accounts_insecure {
    use super::*;

    pub fn update(ctx: Context<Update>, a: u64, b: u64) -> ProgramResult {
        let user_a = &mut ctx.accounts.user_a;
        let user_b = &mut ctx.accounts.user_b;

        user_a.data = a;
        user_b.data = b;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Update<'info> {
    user_a: Account<'info, User>,
    user_b: Account<'info, User>,
}

#[account]
pub struct User {
    data: u64,
}

```



---

recommend:

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod duplicate_mutable_accounts_recommended {
    use super::*;

    pub fn update(ctx: Context<Update>, a: u64, b: u64) -> ProgramResult {
        let user_a = &mut ctx.accounts.user_a;
        let user_b = &mut ctx.accounts.user_b;

        user_a.data = a;
        user_b.data = b;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Update<'info> {
    #[account(constraint = user_a.key() != user_b.key())] // <=== avoid duplicated
    user_a: Account<'info, User>,
    user_b: Account<'info, User>,
}

#[account]
pub struct User {
    data: u64,
}

```





# 7. bump seed canonicalization

insecure:

漏洞点在于允许用户传入自定义的bump生成PDA！

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod bump_seed_canonicalization_insecure {
    use super::*;

    pub fn set_value(ctx: Context<BumpSeed>, key: u64, new_value: u64, bump: u8) -> ProgramResult {
        let address =
            Pubkey::create_program_address(&[key.to_le_bytes().as_ref(), &[bump]], ctx.program_id)?;
        if address != ctx.accounts.data.key() {
            return Err(ProgramError::InvalidArgument);
        }

        ctx.accounts.data.value = new_value;

        Ok(())
    }
}

#[derive(Accounts)]
pub struct BumpSeed<'info> {
    data: Account<'info, Data>,
}

#[account]
pub struct Data {
    value: u64,
}

```



---

recommend:

正确的写法应该是将bump和用户的账户绑定

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod bump_seed_canonicalization_recommended {
    use super::*;

    pub fn set_value(ctx: Context<BumpSeed>, key: u64, new_value: u64) -> ProgramResult {
        ctx.accounts.data.value = new_value;
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(key: u64)]
pub struct BumpSeed<'info> {
    // Note a subtle pattern that is not displayed here.
    //
    // Usually, the usage of PDAs is broken into two parts:
    //
    // 1) allocation via `#[account(init, seeds = [...], bump)]`
    // 2) using the account via `#[account(init, seeds = [...], bump = data.bump)]
    //
    // When using a PDA, it's usually recommend to store the bump seed in the
    // account data, so that you can use it as demonstrated in 2), which will
    // provide a more efficient check.
    #[account(seeds = [key.to_le_bytes().as_ref()], bump)]
    data: Account<'info, Data>,
}

#[account]
pub struct Data {
    value: u64,
}

```





# 8. pda sharing

insecure:

> #### 1. **PDA 生成种子过于简单**
>
> ```rust
> // 漏洞代码：仅用 mint 和 bump 生成 PDA
> let seeds = &[ctx.accounts.pool.mint.as_ref(), &[ctx.accounts.pool.bump]];
> ```
>
> - **问题**：`TokenPool` 的 PDA 仅基于 `mint` 和 `bump` 生成，若多个 `TokenPool` 账户共享相同的 `mint` 和 `bump`，则它们的 PDA 将**指向同一个地址**。
> - **后果**：攻击者可创建新 `TokenPool` 复用相同 `mint` 和 `bump`，从而控制同一 PDA 权限，盗取其他池的资金。
>
> #### 2. **缺乏唯一性约束**
>
> ```rust
> #[account]
> pub struct TokenPool {
>     vault: Pubkey,
>     mint: Pubkey,           // 可能重复
>     withdraw_destination: Pubkey,
>     bump: u8,               // 可能重复
> }
> ```
>
> - **风险**：`mint` 和 `bump` 的组合不具备唯一性，攻击者可伪造相同参数的 `TokenPool`。
>
> #### 3. **签名权限泛化**
>
> ```rust
> token::transfer(ctx.accounts.transfer_ctx().with_signer(&[seeds]))
> ```
>
> - **问题**：所有符合 `mint` 和 `bump` 条件的 PDA 均有权签署转账，导致越权操作。

```rust
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount};

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod pda_sharing_insecure {
    use super::*;

    pub fn withdraw_tokens(ctx: Context<WithdrawTokens>) -> ProgramResult {
        let amount = ctx.accounts.vault.amount;
        let seeds = &[ctx.accounts.pool.mint.as_ref(), &[ctx.accounts.pool.bump]];
        token::transfer(ctx.accounts.transfer_ctx().with_signer(&[seeds]), amount)
    }
}

#[derive(Accounts)]
pub struct WithdrawTokens<'info> {
    #[account(has_one = vault, has_one = withdraw_destination)]
    pool: Account<'info, TokenPool>,
    vault: Account<'info, TokenAccount>,
    withdraw_destination: Account<'info, TokenAccount>,
    authority: Signer<'info>,
    token_program: Program<'info, Token>,
}

impl<'info> WithdrawTokens<'info> {
    pub fn transfer_ctx(&self) -> CpiContext<'_, '_, '_, 'info, token::Transfer<'info>> {
        let program = self.token_program.to_account_info();
        let accounts = token::Transfer {
            from: self.vault.to_account_info(),
            to: self.withdraw_destination.to_account_info(),
            authority: self.authority.to_account_info(),
        };
        CpiContext::new(program, accounts)
    }
}

#[account]
pub struct TokenPool {
    vault: Pubkey,
    mint: Pubkey,
    withdraw_destination: Pubkey,
    bump: u8,
}

```





---

recommend:

```rust
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount};

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod pda_sharing_recommended {
    use super::*;

    pub fn withdraw_tokens(ctx: Context<WithdrawTokens>) -> ProgramResult {
        let amount = ctx.accounts.vault.amount;
        let seeds = &[
            ctx.accounts.pool.withdraw_destination.as_ref(),
            &[ctx.accounts.pool.bump],
        ];
        token::transfer(ctx.accounts.transfer_ctx().with_signer(&[seeds]), amount)
    }
}

#[derive(Accounts)]
pub struct WithdrawTokens<'info> {
    #[account(
				has_one = vault,
				has_one = withdraw_destination,
				seeds = [withdraw_destination.key().as_ref()], // <=== 唯一性约束
				bump = pool.bump,  // <=== 验证正确 bump
		)]
    pool: Account<'info, TokenPool>,
    vault: Account<'info, TokenAccount>,
    withdraw_destination: Account<'info, TokenAccount>,
    authority: Signer<'info>,
    token_program: Program<'info, Token>,
}

impl<'info> WithdrawTokens<'info> {
    pub fn transfer_ctx(&self) -> CpiContext<'_, '_, '_, 'info, token::Transfer<'info>> {
        let program = self.token_program.to_account_info();
        let accounts = token::Transfer {
            from: self.vault.to_account_info(),
            to: self.withdraw_destination.to_account_info(),
            authority: self.authority.to_account_info(),
        };
        CpiContext::new(program, accounts)
    }
}

#[account]
pub struct TokenPool {
    vault: Pubkey,
    mint: Pubkey,
    withdraw_destination: Pubkey,
    bump: u8,
}

```



# 9. closing accounts

insecure：

该代码存在 **账户关闭不完整** 和 **权限控制缺失** 的漏洞

> #### 1. **未清除账户数据**
>
> ```rust
> // 仅转移 lamports，未清空数据
> **ctx.accounts.account.to_account_info().lamports.borrow_mut() = 0;
> ```
>
> - **问题**：账户的 `data` 字段未被清空，攻击者可通过重放交易操作残留数据。
> - **风险**：账户在 lamports 归零后仍保留数据，可能被误认为有效状态。
>
> #### 2. **未验证关闭权限**
>
> ```rust
> #[derive(Accounts)]
> pub struct Close<'info> {
>     account: Account<'info, Data>, // 未验证关闭权限
>     destination: AccountInfo<'info>, // 未验证接收者身份
> }
> ```
>
> - **风险**：任何用户都可调用此指令关闭他人账户，导致资金窃取或数据丢失。
>
> #### 3. **未标记账户关闭状态**
>
> - **问题**：未调用 Solana 系统指令 `close_account`，账户未被标记为「已关闭」，可能被重复操作。

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod closing_accounts_insecure {
    use super::*;

    pub fn close(ctx: Context<Close>) -> ProgramResult {
        let dest_starting_lamports = ctx.accounts.destination.lamports();

        **ctx.accounts.destination.lamports.borrow_mut() = dest_starting_lamports
            .checked_add(ctx.accounts.account.to_account_info().lamports())
            .unwrap();
        **ctx.accounts.account.to_account_info().lamports.borrow_mut() = 0;

        Ok(())
    }
}

#[derive(Accounts)]
pub struct Close<'info> {
    account: Account<'info, Data>,
    destination: AccountInfo<'info>,
}

#[account]
pub struct Data {
    data: u64,
}

```



---

recommend:

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod closing_accounts_recommended {
    use super::*;

    pub fn close(ctx: Context<Close>) -> ProgramResult {
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Close<'info> {
    #[account(mut, close = destination)] // 自动转移 lamports 并标记关闭
    account: Account<'info, Data>,
    #[account(mut)]
    destination: Signer<'info>,
}

#[account]
pub struct Data {
    data: u64,
}

```





# 10. sysvar address check

insecure:

> #### 1. **未验证 Sysvar 账户地址**
>
> ```rust
> #[derive(Accounts)]
> pub struct CheckSysvarAddress<'info> {
>     rent: AccountInfo<'info>, // 未验证是否为合法的 Sysvar 账户
> }
> ```
>
> - **问题**：`rent` 账户未验证其地址是否为 Solana 官方 Rent Sysvar 地址（`SysvarRent111111111111111111111111111111111`）。
> - **风险**：攻击者可传入伪造账户，导致程序读取错误数据，破坏逻辑安全性。
>
> #### 2. **依赖不可信数据**
>
> ```rust
> msg!("Rent Key -> {}", ctx.accounts.rent.key().to_string());
> ```
>
> - **后果**：若 `rent` 账户被伪造，日志输出错误地址，误导调试或监控。

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod insecure {
    use super::*;

    pub fn check_sysvar_address(ctx: Context<CheckSysvarAddress>) -> Result<()> {
        msg!("Rent Key -> {}", ctx.accounts.rent.key().to_string());
        Ok(())
    }
}

#[derive(Accounts)]
pub struct CheckSysvarAddress<'info> {
    rent: AccountInfo<'info>,
}

```



---

recommend:

```rust
use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod recommended {
    use super::*;

    pub fn check_sysvar_address(ctx: Context<CheckSysvarAddress>) -> Result<()> {
        msg!("Rent Key -> {}", ctx.accounts.rent.key().to_string());
        Ok(())
    }
}

#[derive(Accounts)]
pub struct CheckSysvarAddress<'info> {
    rent: Sysvar<'info, Rent>, // <===
}

```



