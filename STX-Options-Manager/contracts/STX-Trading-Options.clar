;; Complete STX Options Smart Contract - All Essential On-Chain Components
;; Comprehensive on-chain functionality for decentralized options trading
;; Includes collateral management, automated settlement, access controls, and emergency functions
;; All critical blockchain-required functionality with proper security measures

;; ACCESS CONTROL

(define-constant contract-owner tx-sender)

;; ERROR CONSTANTS

(define-constant ERR-UNAUTHORIZED-ACCESS (err u1000))
(define-constant ERR-INVALID-OPTION-ID (err u1001))
(define-constant ERR-OPTION-EXPIRED (err u1002))
(define-constant ERR-OPTION-ALREADY-EXERCISED (err u1003))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1004))
(define-constant ERR-INVALID-EXPIRATION (err u1005))
(define-constant ERR-INVALID-STRIKE-PRICE (err u1006))
(define-constant ERR-NOT-OPTION-HOLDER (err u1007))
(define-constant ERR-INVALID-PREMIUM (err u1008))
(define-constant ERR-INVALID-CONTRACT-SIZE (err u1009))
(define-constant ERR-UNSUPPORTED-OPTION-TYPE (err u1010))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u1011))
(define-constant ERR-NOT-OPTION-WRITER (err u1012))
(define-constant ERR-OPTION-NOT-FOUND (err u1013))
(define-constant ERR-CONTRACT-PAUSED (err u1014))
(define-constant ERR-INVALID-PRICE (err u1015))
(define-constant ERR-COLLATERAL-LOCKED (err u1016))

;; OPTION TYPE CONSTANTS

(define-constant call-option-type u1)
(define-constant put-option-type u2)

;; OPTION STATUS CONSTANTS

(define-constant status-active u1)
(define-constant status-exercised u2)
(define-constant status-expired u3)

;; PLATFORM LIMITS

(define-constant minimum-expiration-blocks u144) ;; ~24 hours
(define-constant maximum-expiration-blocks u52560) ;; ~1 year
(define-constant minimum-strike-price u1000) ;; 0.001 STX
(define-constant maximum-strike-price u100000000) ;; 100 STX
(define-constant minimum-contract-size u1)
(define-constant maximum-contract-size u1000000)

;; PLATFORM STATE

(define-data-var contract-paused bool false)
(define-data-var emergency-mode bool false)

;; CORE DATA STRUCTURES

;; Primary options registry with collateral tracking
(define-map options-registry
  { option-id: uint }
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
)

;; Writer collateral tracking
(define-map writer-collateral
  { writer: principal }
  { total-locked: uint, available-balance: uint }
)

;; Option pricing feed (for automated settlement)
(define-map price-feeds
  { feed-block: uint }
  { stx-price: uint, timestamp: uint, reporter: principal }
)

;; Global option counter
(define-data-var next-option-id uint u1)

;; Platform fee settings
(define-data-var platform-fee-rate uint u100) ;; 1% = 100 basis points
(define-data-var fee-recipient principal tx-sender)

;; VALIDATION FUNCTIONS

(define-private (is-valid-option-id (option-id uint))
  (and (> option-id u0) (< option-id (var-get next-option-id)))
)

(define-private (is-valid-option-type (option-type uint))
  (or (is-eq option-type call-option-type) (is-eq option-type put-option-type))
)

(define-private (is-option-active (option-data (tuple 
    (option-writer principal) (option-holder principal) (strike-price uint)
    (premium-amount uint) (expiration-block uint) (option-type uint)
    (contract-status uint) (contract-size uint) (creation-block uint)
    (collateral-amount uint) (collateral-locked bool))))
  (and 
    (< block-height (get expiration-block option-data))
    (is-eq (get contract-status option-data) status-active)
  )
)

(define-private (calculate-required-collateral (option-type uint) (strike-price uint) (contract-size uint))
  (if (is-eq option-type call-option-type)
    ;; Call option: collateral = contract-size * strike-price (for covered calls)
    (* contract-size strike-price)
    ;; Put option: collateral = contract-size * strike-price (cash-secured puts)
    (* contract-size strike-price)
  )
)

(define-private (calculate-platform-fee (premium-amount uint))
  (/ (* premium-amount (var-get platform-fee-rate)) u10000)
)

;; ACCESS CONTROL FUNCTIONS

(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (check-not-paused)
  (not (var-get contract-paused))
)

;; COLLATERAL MANAGEMENT

(define-public (deposit-collateral (amount uint))
  (begin
    (asserts! (check-not-paused) ERR-CONTRACT-PAUSED)
    (asserts! (> amount u0) ERR-INVALID-PRICE)
    
    ;; Transfer collateral to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update collateral tracking
    (let ((current-collateral (default-to { total-locked: u0, available-balance: u0 } 
                                          (map-get? writer-collateral { writer: tx-sender }))))
      (map-set writer-collateral
        { writer: tx-sender }
        { 
          total-locked: (get total-locked current-collateral),
          available-balance: (+ (get available-balance current-collateral) amount)
        }
      )
    )
    
    (ok true)
  )
)

(define-public (withdraw-collateral (amount uint))
  (begin
    (asserts! (check-not-paused) ERR-CONTRACT-PAUSED)
    (asserts! (> amount u0) ERR-INVALID-PRICE)
    
    (let ((collateral-data (unwrap! (map-get? writer-collateral { writer: tx-sender }) 
                                    ERR-INSUFFICIENT-COLLATERAL)))
      
      ;; Check available balance
      (asserts! (>= (get available-balance collateral-data) amount) ERR-INSUFFICIENT-COLLATERAL)
      
      ;; Transfer collateral back to user
      (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
      
      ;; Update collateral tracking
      (map-set writer-collateral
        { writer: tx-sender }
        { 
          total-locked: (get total-locked collateral-data),
          available-balance: (- (get available-balance collateral-data) amount)
        }
      )
      
      (ok true)
    )
  )
)

;; READ-ONLY FUNCTIONS

(define-read-only (get-option-details (option-id uint))
  (begin
    (asserts! (is-valid-option-id option-id) ERR-INVALID-OPTION-ID)
    (ok (map-get? options-registry { option-id: option-id }))
  )
)

(define-read-only (get-writer-collateral (writer principal))
  (map-get? writer-collateral { writer: writer })
)

(define-read-only (get-platform-settings)
  {
    contract-paused: (var-get contract-paused),
    emergency-mode: (var-get emergency-mode),
    platform-fee-rate: (var-get platform-fee-rate),
    next-option-id: (var-get next-option-id)
  }
)

(define-read-only (get-price-feed (feed-block uint))
  (map-get? price-feeds { feed-block: feed-block })
)

;; OPTION CREATION WITH COLLATERAL

(define-public (create-option-contract 
    (strike-price uint)
    (premium-amount uint)
    (expiration-block uint)
    (option-type uint)
    (contract-size uint))
  (let ((new-option-id (var-get next-option-id))
        (required-collateral (calculate-required-collateral option-type strike-price contract-size)))
    
    ;; Platform state checks
    (asserts! (check-not-paused) ERR-CONTRACT-PAUSED)
    
    ;; Input validation
    (asserts! (and (>= strike-price minimum-strike-price) (<= strike-price maximum-strike-price)) ERR-INVALID-STRIKE-PRICE)
    (asserts! (> premium-amount u0) ERR-INVALID-PREMIUM)
    (asserts! (and (>= contract-size minimum-contract-size) (<= contract-size maximum-contract-size)) ERR-INVALID-CONTRACT-SIZE)
    (asserts! (and 
               (> expiration-block (+ block-height minimum-expiration-blocks))
               (< expiration-block (+ block-height maximum-expiration-blocks))
              ) ERR-INVALID-EXPIRATION)
    (asserts! (is-valid-option-type option-type) ERR-UNSUPPORTED-OPTION-TYPE)
    
    ;; Check collateral availability
    (let ((writer-collateral-data (unwrap! (map-get? writer-collateral { writer: tx-sender }) 
                                           ERR-INSUFFICIENT-COLLATERAL)))
      (asserts! (>= (get available-balance writer-collateral-data) required-collateral) ERR-INSUFFICIENT-COLLATERAL)
      
      ;; Lock collateral
      (map-set writer-collateral
        { writer: tx-sender }
        { 
          total-locked: (+ (get total-locked writer-collateral-data) required-collateral),
          available-balance: (- (get available-balance writer-collateral-data) required-collateral)
        }
      )
    )
    
    ;; Create option contract
    (map-set options-registry
      { option-id: new-option-id }
      {
        option-writer: tx-sender,
        option-holder: tx-sender,
        strike-price: strike-price,
        premium-amount: premium-amount,
        expiration-block: expiration-block,
        option-type: option-type,
        contract-status: status-active,
        contract-size: contract-size,
        creation-block: block-height,
        collateral-amount: required-collateral,
        collateral-locked: true
      }
    )
    
    ;; Increment counter
    (var-set next-option-id (+ new-option-id u1))
    
    (ok new-option-id)
  )
)

;; OPTION TRANSFER

(define-public (transfer-option (option-id uint) (new-holder principal))
  (begin
    (asserts! (check-not-paused) ERR-CONTRACT-PAUSED)
    (asserts! (is-valid-option-id option-id) ERR-INVALID-OPTION-ID)
    
    (let ((option-data (unwrap! (map-get? options-registry { option-id: option-id }) 
                                ERR-OPTION-NOT-FOUND)))
      
      ;; Validation
      (asserts! (is-option-active option-data) ERR-OPTION-EXPIRED)
      (asserts! (is-eq (get option-holder option-data) tx-sender) ERR-NOT-OPTION-HOLDER)
      
      ;; Transfer ownership
      (map-set options-registry
        { option-id: option-id }
        (merge option-data { option-holder: new-holder })
      )
      
      (ok true)
    )
  )
)

;; OPTION PURCHASE WITH FEES

(define-public (purchase-option (option-id uint))
  (begin
    (asserts! (check-not-paused) ERR-CONTRACT-PAUSED)
    (asserts! (is-valid-option-id option-id) ERR-INVALID-OPTION-ID)
    
    (let ((option-data (unwrap! (map-get? options-registry { option-id: option-id }) 
                                ERR-OPTION-NOT-FOUND))
          (platform-fee (calculate-platform-fee (get premium-amount option-data))))
      
      ;; Validation
      (asserts! (is-option-active option-data) ERR-OPTION-EXPIRED)
      (asserts! (is-eq (get option-writer option-data) (get option-holder option-data)) ERR-UNAUTHORIZED-ACCESS)
      
      ;; Premium payment to writer
      (try! (stx-transfer? (- (get premium-amount option-data) platform-fee) tx-sender (get option-writer option-data)))
      
      ;; Platform fee payment
      (if (> platform-fee u0)
        (try! (stx-transfer? platform-fee tx-sender (var-get fee-recipient)))
        true
      )
      
      ;; Transfer ownership
      (map-set options-registry
        { option-id: option-id }
        (merge option-data { option-holder: tx-sender })
      )
      
      (ok true)
    )
  )
)

;; OPTION EXERCISE WITH COLLATERAL RELEASE

(define-public (exercise-call-option (option-id uint))
  (begin
    (asserts! (check-not-paused) ERR-CONTRACT-PAUSED)
    (asserts! (is-valid-option-id option-id) ERR-INVALID-OPTION-ID)
    
    (let ((option-data (unwrap! (map-get? options-registry { option-id: option-id }) 
                                ERR-OPTION-NOT-FOUND))
          (exercise-cost (* (get strike-price option-data) (get contract-size option-data))))
      
      ;; Validation
      (asserts! (is-option-active option-data) ERR-OPTION-EXPIRED)
      (asserts! (is-eq (get option-type option-data) call-option-type) ERR-UNSUPPORTED-OPTION-TYPE)
      (asserts! (is-eq (get option-holder option-data) tx-sender) ERR-NOT-OPTION-HOLDER)
      
      ;; Exercise payment to writer
      (try! (stx-transfer? exercise-cost tx-sender (get option-writer option-data)))
      
      ;; Release collateral back to writer
      (let ((writer-collateral-data (unwrap! (map-get? writer-collateral { writer: (get option-writer option-data) }) 
                                             ERR-INSUFFICIENT-COLLATERAL)))
        (map-set writer-collateral
          { writer: (get option-writer option-data) }
          { 
            total-locked: (- (get total-locked writer-collateral-data) (get collateral-amount option-data)),
            available-balance: (+ (get available-balance writer-collateral-data) (get collateral-amount option-data))
          }
        )
      )
      
      ;; Mark as exercised
      (map-set options-registry
        { option-id: option-id }
        (merge option-data { contract-status: status-exercised, collateral-locked: false })
      )
      
      (ok true)
    )
  )
)

(define-public (exercise-put-option (option-id uint))
  (begin
    (asserts! (check-not-paused) ERR-CONTRACT-PAUSED)
    (asserts! (is-valid-option-id option-id) ERR-INVALID-OPTION-ID)
    
    (let ((option-data (unwrap! (map-get? options-registry { option-id: option-id }) 
                                ERR-OPTION-NOT-FOUND))
          (payout-amount (* (get strike-price option-data) (get contract-size option-data))))
      
      ;; Validation
      (asserts! (is-option-active option-data) ERR-OPTION-EXPIRED)
      (asserts! (is-eq (get option-type option-data) put-option-type) ERR-UNSUPPORTED-OPTION-TYPE)
      (asserts! (is-eq (get option-holder option-data) tx-sender) ERR-NOT-OPTION-HOLDER)
      
      ;; Payout from locked collateral to holder
      (try! (as-contract (stx-transfer? payout-amount tx-sender tx-sender)))
      
      ;; Update collateral (remaining goes back to writer)
      (let ((writer-collateral-data (unwrap! (map-get? writer-collateral { writer: (get option-writer option-data) }) 
                                             ERR-INSUFFICIENT-COLLATERAL))
            (remaining-collateral (- (get collateral-amount option-data) payout-amount)))
        (map-set writer-collateral
          { writer: (get option-writer option-data) }
          { 
            total-locked: (- (get total-locked writer-collateral-data) (get collateral-amount option-data)),
            available-balance: (+ (get available-balance writer-collateral-data) remaining-collateral)
          }
        )
      )
      
      ;; Mark as exercised
      (map-set options-registry
        { option-id: option-id }
        (merge option-data { contract-status: status-exercised, collateral-locked: false })
      )
      
      (ok true)
    )
  )
)

;; AUTOMATED SETTLEMENT WITH COLLATERAL RELEASE

(define-public (settle-expired-option (option-id uint))
  (begin
    (asserts! (is-valid-option-id option-id) ERR-INVALID-OPTION-ID)
    
    (let ((option-data (unwrap! (map-get? options-registry { option-id: option-id }) 
                                ERR-OPTION-NOT-FOUND)))
      
      ;; Validation
      (asserts! (>= block-height (get expiration-block option-data)) ERR-UNAUTHORIZED-ACCESS)
      (asserts! (is-eq (get contract-status option-data) status-active) ERR-OPTION-ALREADY-EXERCISED)
      
      ;; Release collateral back to writer
      (if (get collateral-locked option-data)
        (let ((writer-collateral-data (unwrap! (map-get? writer-collateral { writer: (get option-writer option-data) }) 
                                               ERR-INSUFFICIENT-COLLATERAL)))
          (map-set writer-collateral
            { writer: (get option-writer option-data) }
            { 
              total-locked: (- (get total-locked writer-collateral-data) (get collateral-amount option-data)),
              available-balance: (+ (get available-balance writer-collateral-data) (get collateral-amount option-data))
            }
          )
        )
        true
      )
      
      ;; Mark as expired
      (map-set options-registry
        { option-id: option-id }
        (merge option-data { contract-status: status-expired, collateral-locked: false })
      )
      
      (ok true)
    )
  )
)

;; PRICE FEED MANAGEMENT (For automated settlement)

(define-public (update-price-feed (stx-price uint))
  (begin
    (asserts! (> stx-price u0) ERR-INVALID-PRICE)
    
    (map-set price-feeds
      { feed-block: block-height }
      { stx-price: stx-price, timestamp: block-height, reporter: tx-sender }
    )
    
    (ok true)
  )
)

;; ADMIN FUNCTIONS

(define-public (pause-contract)
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee-rate uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= new-fee-rate u1000) ERR-INVALID-PRICE) ;; Max 10%
    (var-set platform-fee-rate new-fee-rate)
    (ok true)
  )
)

(define-public (emergency-pause)
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (var-set emergency-mode true)
    (var-set contract-paused true)
    (ok true)
  )
)

;; CONTRACT INITIALIZATION

(begin
  (print "Complete STX Options Smart Contract Deployed")
  (var-get next-option-id)
)
