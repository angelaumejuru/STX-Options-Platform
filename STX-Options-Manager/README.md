# STX Options Smart Contract

A comprehensive decentralized options trading platform built on the Stacks blockchain, enabling users to create, trade, and exercise call and put options with automated collateral management and settlement.

## Overview

The STX Options Smart Contract provides a complete on-chain infrastructure for decentralized options trading. It handles all aspects of options trading including:

- Option contract creation and management
- Automated collateral locking and release
- Premium payments with platform fees
- Option exercise and automated settlement
- Emergency controls and access management

## Features

### Core Trading Features
- **Call and Put Options**: Support for both option types with proper collateral requirements
- **Automated Settlement**: Expired options are automatically settled with collateral release
- **Premium Trading**: Built-in premium payment system with platform fee collection
- **Option Transfers**: Transfer option ownership between users
- **Collateral Management**: Automatic locking/unlocking of collateral based on option status

### Security Features
- **Access Controls**: Role-based permissions for critical functions
- **Emergency Pause**: Contract-wide pause functionality for emergency situations
- **Input Validation**: Comprehensive validation of all user inputs
- **Collateral Safety**: Prevents withdrawal of locked collateral
- **Expiration Handling**: Automatic cleanup of expired options

### Platform Management
- **Fee Configuration**: Adjustable platform fees (max 10%)
- **Price Feeds**: On-chain price reporting system
- **Platform Limits**: Configurable limits for strike prices, contract sizes, and expiration times
- **Emergency Mode**: Enhanced security controls for crisis situations

## Contract Architecture

### Data Structures

#### Options Registry
```clarity
{
  option-writer: principal,
  option-holder: principal,
  strike-price: uint,
  premium-amount: uint,
  expiration-block: uint,
  option-type: uint,
  contract-status: uint,
  contract-size: uint,
  creation-block: uint,
  collateral-amount: uint,
  collateral-locked: bool
}
```

#### Writer Collateral
```clarity
{
  total-locked: uint,
  available-balance: uint
}
```

#### Price Feeds
```clarity
{
  stx-price: uint,
  timestamp: uint,
  reporter: principal
}
```

## Getting Started

### Prerequisites
- Stacks wallet with STX tokens
- Understanding of options trading concepts
- Basic knowledge of Clarity smart contracts

### Initial Setup

1. **Deploy the Contract**: Deploy to Stacks testnet or mainnet
2. **Deposit Collateral**: Writers must deposit collateral before creating options
3. **Create Options**: Use the `create-option-contract` function
4. **Trade Options**: Purchase options using `purchase-option`

## Core Functions

### For Option Writers

#### Deposit Collateral
```clarity
(deposit-collateral (amount uint))
```
Deposit STX tokens as collateral for writing options.

#### Create Option Contract
```clarity
(create-option-contract 
  (strike-price uint)
  (premium-amount uint)
  (expiration-block uint)
  (option-type uint)
  (contract-size uint))
```
Create a new option contract with specified parameters.

#### Withdraw Collateral
```clarity
(withdraw-collateral (amount uint))
```
Withdraw available (unlocked) collateral.

### For Option Buyers

#### Purchase Option
```clarity
(purchase-option (option-id uint))
```
Purchase an existing option by paying the premium.

#### Exercise Call Option
```clarity
(exercise-call-option (option-id uint))
```
Exercise a call option by paying the strike price.

#### Exercise Put Option
```clarity
(exercise-put-option (option-id uint))
```
Exercise a put option to receive the strike price payout.

#### Transfer Option
```clarity
(transfer-option (option-id uint) (new-holder principal))
```
Transfer option ownership to another user.

### For All Users

#### Settle Expired Option
```clarity
(settle-expired-option (option-id uint))
```
Settle an expired option and release collateral.

## Collateral Management

### Collateral Requirements

#### Call Options
- **Covered Calls**: Collateral = contract-size × strike-price
- **Purpose**: Ensures writer can deliver the underlying asset

#### Put Options
- **Cash-Secured Puts**: Collateral = contract-size × strike-price
- **Purpose**: Ensures writer can purchase at strike price

### Collateral States
- **Available**: Can be withdrawn or used for new options
- **Locked**: Tied to active options, cannot be withdrawn
- **Released**: Automatically unlocked when options expire or are exercised

## Option Types

### Call Options (`call-option-type = u1`)
- Right to buy STX at strike price
- Writer provides STX as collateral
- Profitable when STX price > strike price

### Put Options (`put-option-type = u2`)
- Right to sell STX at strike price
- Writer provides STX cash collateral
- Profitable when STX price < strike price

## Security Features

### Access Control
- Contract owner has administrative privileges
- Users can only modify their own options
- Collateral withdrawal restricted to available balance

### Emergency Controls
- `pause-contract`: Temporarily halt all operations
- `emergency-pause`: Enhanced emergency mode
- `unpause-contract`: Resume normal operations

### Input Validation
- Strike price limits: 0.001 STX to 100 STX
- Contract size limits: 1 to 1,000,000 units
- Expiration limits: 24 hours to 1 year
- Premium must be positive

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u1000 | ERR-UNAUTHORIZED-ACCESS | Unauthorized access attempt |
| u1001 | ERR-INVALID-OPTION-ID | Invalid option ID |
| u1002 | ERR-OPTION-EXPIRED | Option has expired |
| u1003 | ERR-OPTION-ALREADY-EXERCISED | Option already exercised |
| u1004 | ERR-INSUFFICIENT-BALANCE | Insufficient balance |
| u1005 | ERR-INVALID-EXPIRATION | Invalid expiration time |
| u1006 | ERR-INVALID-STRIKE-PRICE | Strike price out of range |
| u1007 | ERR-NOT-OPTION-HOLDER | Not the option holder |
| u1008 | ERR-INVALID-PREMIUM | Invalid premium amount |
| u1009 | ERR-INVALID-CONTRACT-SIZE | Contract size out of range |
| u1010 | ERR-UNSUPPORTED-OPTION-TYPE | Unsupported option type |
| u1011 | ERR-INSUFFICIENT-COLLATERAL | Insufficient collateral |
| u1012 | ERR-NOT-OPTION-WRITER | Not the option writer |
| u1013 | ERR-OPTION-NOT-FOUND | Option not found |
| u1014 | ERR-CONTRACT-PAUSED | Contract is paused |
| u1015 | ERR-INVALID-PRICE | Invalid price |
| u1016 | ERR-COLLATERAL-LOCKED | Collateral is locked |

## Platform Limits

```clarity
minimum-expiration-blocks: u144        ;; ~24 hours
maximum-expiration-blocks: u52560       ;; ~1 year
minimum-strike-price: u1000             ;; 0.001 STX
maximum-strike-price: u100000000        ;; 100 STX
minimum-contract-size: u1
maximum-contract-size: u1000000
```

## Admin Functions

### Fee Management
```clarity
(set-platform-fee (new-fee-rate uint))
```
Set platform fee rate (max 10%, in basis points).

### Contract Control
```clarity
(pause-contract)
(unpause-contract)
(emergency-pause)
```

### Price Feed Updates
```clarity
(update-price-feed (stx-price uint))
```

## Usage Examples

### Creating a Call Option
```clarity
;; 1. First, deposit collateral
(contract-call? .stx-options deposit-collateral u10000000) ;; 10 STX

;; 2. Create call option
(contract-call? .stx-options create-option-contract
  u5000000   ;; Strike price: 5 STX
  u500000    ;; Premium: 0.5 STX
  u1000      ;; Expires in ~1000 blocks
  u1         ;; Call option
  u1         ;; Contract size: 1
)
```

### Purchasing and Exercising an Option
```clarity
;; Purchase option
(contract-call? .stx-options purchase-option u1)

;; Exercise call option (if profitable)
(contract-call? .stx-options exercise-call-option u1)
```

### Reading Contract State
```clarity
;; Get option details
(contract-call? .stx-options get-option-details u1)

;; Check collateral balance
(contract-call? .stx-options get-writer-collateral tx-sender)

;; Get platform settings
(contract-call? .stx-options get-platform-settings)
```

## Testing

### Test Scenarios
1. **Option Creation**: Test all parameter combinations
2. **Collateral Management**: Verify locking/unlocking logic
3. **Exercise Scenarios**: Test both call and put exercises
4. **Settlement**: Test automated expiration handling
5. **Edge Cases**: Test boundary conditions and error cases

### Test Network
Deploy to Stacks testnet for comprehensive testing before mainnet deployment.

## Deployment

### Prerequisites
- Stacks CLI installed
- Testnet/Mainnet STX for deployment fees
- Contract verification setup

### Deployment Steps
1. Compile contract: `clarinet check`
2. Test locally: `clarinet test`
3. Deploy to testnet: `stx deploy_contract`
4. Verify contract functionality
5. Deploy to mainnet (if applicable)

### Post-Deployment
1. Initialize platform settings
2. Set up price feed reporters
3. Configure fee recipients
4. Test all major functions