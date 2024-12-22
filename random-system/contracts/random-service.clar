;; Random Number Generator Contract

;; Constants for contract ownership and error handling
(define-constant contract-owner tx-sender)
(define-constant ERROR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERROR_INVALID_RANGE_BOUNDS (err u101))
(define-constant ERROR_ZERO_SEED_VALUE (err u102))
(define-constant ERROR_INVALID_GENERATION_PARAMS (err u103))
(define-constant ERROR_SEQUENCE_NUMBER_OVERFLOW (err u104))
(define-constant ERROR_SEQUENCE_LENGTH_EXCEEDED (err u105))
(define-constant ERROR_GENERATION_COOLDOWN_ACTIVE (err u106))
(define-constant ERROR_ADDRESS_BLACKLISTED (err u107))
(define-constant ERROR_INSUFFICIENT_ENTROPY_POOL (err u108))
(define-constant ERROR_CONTRACT_PAUSED (err u109))
(define-constant ERROR_METRICS_UPDATE_FAILED (err u110))
(define-constant ERROR_INVALID_PRINCIPAL_ADDRESS (err u111))
(define-constant ERROR_ENTROPY_VALUE_OUT_OF_BOUNDS (err u112))

;; Response type definitions
(define-constant OPERATION_SUCCESS (ok true))

;; Configuration constants
(define-constant MAX_RANDOM_SEQUENCE_LENGTH u100)
(define-constant MIN_REQUIRED_ENTROPY u10)
(define-constant GENERATION_COOLDOWN_PERIOD u10)
(define-constant MAX_RANDOM_RANGE_SIZE u1000000)
(define-constant MAX_ENTROPY_INPUT_VALUE u1000000)

;; Data variables for maintaining random number state
(define-data-var current-random-number uint u0)
(define-data-var generation-sequence-counter uint u0)
(define-data-var current-seed-value uint u1)
(define-data-var available-entropy uint u0)
(define-data-var contract-paused bool false)
(define-data-var last-generation-timestamp uint u0)
(define-data-var total-random-generations uint u0)
(define-data-var consecutive-generation-counter uint u0)

;; Maps for advanced features
(define-map blocked-addresses principal bool)
(define-map user-generation-stats principal uint)
(define-map historical-random-numbers uint uint)
(define-map generation-history-timestamps uint uint)

;; Read-only functions to access contract state
(define-read-only (get-current-random-number)
    (ok (var-get current-random-number))
)

(define-read-only (get-generation-sequence-counter)
    (ok (var-get generation-sequence-counter))
)

(define-read-only (get-contract-status)
    (ok {
        paused: (var-get contract-paused),
        total-generations: (var-get total-random-generations),
        current-entropy: (var-get available-entropy),
        last-generation: (var-get last-generation-timestamp)
    })
)

(define-read-only (get-user-total-generations (user-address principal))
    (ok (default-to u0 (map-get? user-generation-stats user-address)))
)

(define-read-only (is-user-blocked (user-address principal))
    (ok (default-to false (map-get? blocked-addresses user-address)))
)

;; Private administrative functions
(define-private (verify-owner-access)
    (if (is-eq tx-sender contract-owner)
        OPERATION_SUCCESS
        ERROR_UNAUTHORIZED_ACCESS)
)

(define-private (verify-generation-requirements)
    (begin
        (asserts! (not (var-get contract-paused)) ERROR_CONTRACT_PAUSED)
        (asserts! (not (default-to false (map-get? blocked-addresses tx-sender))) ERROR_ADDRESS_BLACKLISTED)
        (asserts! (>= (var-get available-entropy) MIN_REQUIRED_ENTROPY) ERROR_INSUFFICIENT_ENTROPY_POOL)
        (asserts! (> block-height (+ (var-get last-generation-timestamp) GENERATION_COOLDOWN_PERIOD)) ERROR_GENERATION_COOLDOWN_ACTIVE)
        OPERATION_SUCCESS
    )
)

(define-private (validate-principal (address principal))
    (match (principal-destruct? address)
        success true
        error false)
)

(define-private (calculate-random-hash (input-value uint))
    (let (
        (combined-input (concat 
            (unwrap-panic (to-consensus-buff? (var-get generation-sequence-counter)))
            (unwrap-panic (to-consensus-buff? (xor 
                (xor 
                    input-value
                    block-height
                )
                (var-get available-entropy)
            )))
        ))
        (hash-output (sha256 combined-input))
        (truncated-hash-result (match (slice? hash-output u0 u16)
                slice-output (ok (unwrap-panic (as-max-len? slice-output u16)))
                (err "Failed to slice buffer")))
    )
    (buff-to-uint-be (unwrap-panic truncated-hash-result))
    )
)

(define-private (update-generation-stats) 
    (begin
        (var-set total-random-generations (+ (var-get total-random-generations) u1))
        (var-set last-generation-timestamp block-height)
        (map-set generation-history-timestamps (var-get total-random-generations) block-height)
        (map-set historical-random-numbers (var-get total-random-generations) (var-get current-random-number))
        (map-set user-generation-stats tx-sender 
            (+ (default-to u0 (map-get? user-generation-stats tx-sender)) u1))
        OPERATION_SUCCESS
    )
)

;; Public administrative functions
(define-public (toggle-contract-pause)
    (begin
        (try! (verify-owner-access))
        (ok (var-set contract-paused (not (var-get contract-paused))))
    )
)

(define-public (block-address (target-address principal))
    (begin
        (try! (verify-owner-access))
        (asserts! (validate-principal target-address) ERROR_INVALID_PRINCIPAL_ADDRESS)
        (ok (map-set blocked-addresses target-address true))
    )
)

(define-public (unblock-address (target-address principal))
    (begin
        (try! (verify-owner-access))
        (asserts! (validate-principal target-address) ERROR_INVALID_PRINCIPAL_ADDRESS)
        (ok (map-delete blocked-addresses target-address))
    )
)

(define-public (add-entropy-to-pool (entropy-input uint))
    (begin
        (asserts! (<= entropy-input MAX_ENTROPY_INPUT_VALUE) ERROR_ENTROPY_VALUE_OUT_OF_BOUNDS)
        (var-set available-entropy (+ (var-get available-entropy) entropy-input))
        OPERATION_SUCCESS
    )
)

;; Random number generation functions
(define-public (generate-random-number)
    (let
        ((prerequisites-check (verify-generation-requirements)))
        (match prerequisites-check
            success-response 
                (let
                    ((random-output (calculate-random-hash (var-get current-seed-value))))
                    (begin
                        (var-set generation-sequence-counter 
                            (+ (var-get generation-sequence-counter) u1))
                        (var-set current-random-number random-output)
                        (var-set current-seed-value random-output)
                        (var-set available-entropy (- (var-get available-entropy) u1))
                        (ok random-output)))
            error-response (err error-response)
        )
    )
)

(define-public (generate-random-number-in-range (min-value uint) (max-value uint))
    (begin
        (asserts! (< min-value max-value) ERROR_INVALID_RANGE_BOUNDS)
        (asserts! (<= (- max-value min-value) MAX_RANDOM_RANGE_SIZE) ERROR_INVALID_RANGE_BOUNDS)
        (let ((random-output (try! (generate-random-number))))
            (ok (+ min-value (mod random-output (- max-value min-value))))
        )
    )
)

(define-public (generate-random-sequence (desired-length uint))
    (begin
        (asserts! (> desired-length u0) ERROR_INVALID_GENERATION_PARAMS)
        (asserts! (<= desired-length MAX_RANDOM_SEQUENCE_LENGTH) ERROR_SEQUENCE_LENGTH_EXCEEDED)
        (try! (verify-generation-requirements))
        (let 
            (
                (sequence-result (fold generate-sequence-numbers 
                    (list u1 u2 u3 u4 u5) 
                    {sequence: (list), current-length: u0, target-length: desired-length}))
            )
            (ok (get sequence sequence-result))
        )
    )
)

(define-public (generate-random-percentage-value)
    (let ((random-output (try! (generate-random-number))))
        (ok (mod random-output u101))
    )
)

(define-private (generate-sequence-numbers (position uint) (state {sequence: (list 100 uint), current-length: uint, target-length: uint}))
    (let 
        (
            (random-output (unwrap-panic (generate-random-number)))
            (updated-sequence (unwrap! (as-max-len? (append (get sequence state) random-output) u100) state))
            (new-length (+ (get current-length state) u1))
        )
        (if (< new-length (get target-length state))
            {sequence: updated-sequence, current-length: new-length, target-length: (get target-length state)}
            state
        )
    )
)

;; Contract initialization with default values
(begin
    (var-set current-random-number u1)
    (var-set generation-sequence-counter u0)
    (var-set current-seed-value u1)
    (var-set available-entropy MIN_REQUIRED_ENTROPY)
    (var-set contract-paused false)
)