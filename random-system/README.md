# Random Number Generator Smart Contract

A secure and feature-rich random number generator smart contract implemented in Clarity. This contract provides various random number generation capabilities with built-in security measures, entropy management, and administrative controls.

## Features

- Single random number generation
- Range-based random number generation
- Random sequence generation
- Percentage value generation
- Entropy pool management
- User blacklisting capabilities
- System pause functionality
- Comprehensive error handling
- Usage statistics tracking
- Cooldown period enforcement

## Security Measures

- Entropy pool management to ensure randomness quality
- Cooldown periods between generations to prevent abuse
- User blacklisting for suspicious activities
- Contract pause functionality for emergency situations
- Owner-only administrative functions
- Maximum range and sequence length limitations
- Comprehensive input validation

## Configuration Constants

```clarity
MAX_RANDOM_SEQUENCE_LENGTH: u100
MIN_REQUIRED_ENTROPY: u10
GENERATION_COOLDOWN_PERIOD: u10 blocks
MAX_RANDOM_RANGE_SIZE: u1000000
MAX_ENTROPY_INPUT_VALUE: u1000000
```

## Public Functions

### Random Number Generation

1. `generate-random-number()`
   - Generates a single random number
   - Returns: (ok uint)

2. `generate-random-number-in-range(min-value uint, max-value uint)`
   - Generates a random number within specified bounds
   - Parameters:
     - min-value: Lower bound (inclusive)
     - max-value: Upper bound (exclusive)
   - Returns: (ok uint)

3. `generate-random-sequence(desired-length uint)`
   - Generates a sequence of random numbers
   - Parameter:
     - desired-length: Length of sequence (max 100)
   - Returns: (ok (list 100 uint))

4. `generate-random-percentage-value()`
   - Generates a random percentage (0-100)
   - Returns: (ok uint)

### Administrative Functions

1. `toggle-contract-pause()`
   - Toggles the contract's operational status
   - Owner only
   - Returns: (ok bool)

2. `block-address(target-address principal)`
   - Blocks an address from using the contract
   - Owner only
   - Returns: (ok bool)

3. `unblock-address(target-address principal)`
   - Removes an address from the blocklist
   - Owner only
   - Returns: (ok bool)

4. `add-entropy-to-pool(entropy-input uint)`
   - Adds entropy to the generation pool
   - Returns: (ok bool)

### Read-Only Functions

1. `get-current-random-number()`
   - Returns the last generated random number
   - Returns: (ok uint)

2. `get-generation-sequence-counter()`
   - Returns the current sequence number
   - Returns: (ok uint)

3. `get-contract-status()`
   - Returns contract operational status
   - Returns: (ok {paused: bool, total-generations: uint, current-entropy: uint, last-generation: uint})

4. `get-user-total-generations(user-address principal)`
   - Returns total generations by a user
   - Returns: (ok uint)

5. `is-user-blocked(user-address principal)`
   - Checks if an address is blocked
   - Returns: (ok bool)

## Error Codes

- u100: Unauthorized access
- u101: Invalid range bounds
- u102: Zero seed value
- u103: Invalid generation parameters
- u104: Sequence number overflow
- u105: Sequence length exceeded
- u106: Generation cooldown active
- u107: Address blacklisted
- u108: Insufficient entropy pool
- u109: Contract paused
- u110: Metrics update failed
- u111: Invalid principal address
- u112: Entropy value out of bounds

## Usage Examples

### Generate a Random Number
```clarity
(contract-call? .random-number-generator generate-random-number)
```

### Generate Number in Range
```clarity
(contract-call? .random-number-generator generate-random-number-in-range u1 u100)
```

### Generate Random Sequence
```clarity
(contract-call? .random-number-generator generate-random-sequence u10)
```

### Generate Percentage
```clarity
(contract-call? .random-number-generator generate-random-percentage-value)
```

## Security Considerations

1. **Entropy Management**
   - Maintain sufficient entropy in the pool
   - Regularly add new entropy through `add-entropy-to-pool`

2. **Cooldown Periods**
   - Respect the cooldown period between generations
   - Monitor for attempts to bypass cooldown

3. **Access Control**
   - Keep contract owner key secure
   - Regularly review blocked addresses

4. **Monitoring**
   - Track usage patterns through generation statistics
   - Monitor entropy pool levels

## Implementation Notes

- The contract uses block height and user-provided entropy for randomness
- Hash calculations use SHA-256
- Maximum sequence length is capped at 100 elements
- Entropy pool must maintain minimum required level
- Cooldown period enforced between generations

## Best Practices

1. **Entropy Management**
   - Regularly add entropy to maintain pool health
   - Monitor entropy levels to prevent depletion

2. **Error Handling**
   - Always check return values for errors
   - Handle all error conditions appropriately

3. **Rate Limiting**
   - Respect cooldown periods
   - Monitor for excessive usage patterns

4. **Security**
   - Regular security audits
   - Monitor for suspicious patterns
   - Keep administrative access secure