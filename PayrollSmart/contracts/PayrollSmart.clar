;; Automated Employee Payroll and Contractor Payments Smart Contract
;; This contract manages automated payroll for employees and contractor payments
;; with role-based access control, payment scheduling, and secure fund management

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))
(define-constant ERR-PAYMENT-NOT-DUE (err u106))
(define-constant ERR-ALREADY-PAID (err u107))

;; Employee types
(define-constant EMPLOYEE-TYPE-FULL-TIME u1)
(define-constant EMPLOYEE-TYPE-PART-TIME u2)
(define-constant EMPLOYEE-TYPE-CONTRACTOR u3)

;; Payment frequencies (in blocks)
(define-constant WEEKLY-BLOCKS u1008)    ;; ~1 week in blocks
(define-constant BIWEEKLY-BLOCKS u2016)  ;; ~2 weeks in blocks
(define-constant MONTHLY-BLOCKS u4320)   ;; ~1 month in blocks

;; data maps and vars

;; Employee registry with comprehensive details
(define-map employees
  { employee-id: uint }
  {
    wallet-address: principal,
    employee-type: uint,
    salary-amount: uint,
    payment-frequency: uint,
    last-payment-block: uint,
    total-paid: uint,
    is-active: bool,
    start-date: uint
  }
)

;; Payment history for audit trail
(define-map payment-history
  { payment-id: uint }
  {
    employee-id: uint,
    amount: uint,
    payment-block: uint,
    payment-type: (string-ascii 20)
  }
)

;; Contract balance and administrative data
(define-data-var contract-balance uint u0)
(define-data-var next-employee-id uint u1)
(define-data-var next-payment-id uint u1)
(define-data-var total-employees uint u0)
(define-data-var monthly-payroll-budget uint u0)

;; Emergency pause mechanism
(define-data-var contract-paused bool false)

;; Authorized administrators (besides owner)
(define-map authorized-admins principal bool)

;; private functions

;; Check if caller is owner or authorized admin
(define-private (is-authorized (caller principal))
  (or 
    (is-eq caller CONTRACT-OWNER)
    (default-to false (map-get? authorized-admins caller))
  )
)

;; Calculate next payment due block
(define-private (calculate-next-payment-block (last-payment uint) (frequency uint))
  (+ last-payment frequency)
)

;; Validate employee type
(define-private (is-valid-employee-type (emp-type uint))
  (or 
    (is-eq emp-type EMPLOYEE-TYPE-FULL-TIME)
    (or 
      (is-eq emp-type EMPLOYEE-TYPE-PART-TIME)
      (is-eq emp-type EMPLOYEE-TYPE-CONTRACTOR)
    )
  )
)

;; Check if payment is due for an employee
(define-private (is-payment-due (employee-id uint))
  (match (map-get? employees { employee-id: employee-id })
    employee-data 
    (let ((next-payment-block (calculate-next-payment-block 
                               (get last-payment-block employee-data)
                               (get payment-frequency employee-data))))
      (>= block-height next-payment-block))
    false
  )
)

;; public functions

;; Add funds to the contract (only owner/admin)
(define-public (add-funds (amount uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set contract-balance (+ (var-get contract-balance) amount))
    (ok amount)
  )
)

;; Register a new employee
(define-public (register-employee 
                (wallet-address principal)
                (employee-type uint)
                (salary-amount uint)
                (payment-frequency uint))
  (let ((employee-id (var-get next-employee-id)))
    (begin
      (asserts! (is-authorized tx-sender) ERR-UNAUTHORIZED)
      (asserts! (> salary-amount u0) ERR-INVALID-AMOUNT)
      (asserts! (is-valid-employee-type employee-type) ERR-INVALID-AMOUNT)
      (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
      
      ;; Ensure employee doesn't already exist
      (asserts! (is-none (map-get? employees { employee-id: employee-id })) ERR-ALREADY-EXISTS)
      
      ;; Register employee
      (map-set employees
        { employee-id: employee-id }
        {
          wallet-address: wallet-address,
          employee-type: employee-type,
          salary-amount: salary-amount,
          payment-frequency: payment-frequency,
          last-payment-block: block-height,
          total-paid: u0,
          is-active: true,
          start-date: block-height
        }
      )
      
      ;; Update counters
      (var-set next-employee-id (+ employee-id u1))
      (var-set total-employees (+ (var-get total-employees) u1))
      
      (ok employee-id)
    )
  )
)

;; Process payment for a specific employee
(define-public (process-payment (employee-id uint))
  (match (map-get? employees { employee-id: employee-id })
    employee-data
    (let ((payment-amount (get salary-amount employee-data))
          (employee-wallet (get wallet-address employee-data))
          (payment-id (var-get next-payment-id)))
      (begin
        (asserts! (is-authorized tx-sender) ERR-UNAUTHORIZED)
        (asserts! (get is-active employee-data) ERR-NOT-FOUND)
        (asserts! (>= (var-get contract-balance) payment-amount) ERR-INSUFFICIENT-FUNDS)
        (asserts! (is-payment-due employee-id) ERR-PAYMENT-NOT-DUE)
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        
        ;; Transfer payment
        (try! (as-contract (stx-transfer? payment-amount tx-sender employee-wallet)))
        
        ;; Update employee record
        (map-set employees
          { employee-id: employee-id }
          (merge employee-data {
            last-payment-block: block-height,
            total-paid: (+ (get total-paid employee-data) payment-amount)
          })
        )
        
        ;; Record payment history
        (map-set payment-history
          { payment-id: payment-id }
          {
            employee-id: employee-id,
            amount: payment-amount,
            payment-block: block-height,
            payment-type: "regular-salary"
          }
        )
        
        ;; Update contract state
        (var-set contract-balance (- (var-get contract-balance) payment-amount))
        (var-set next-payment-id (+ payment-id u1))
        
        (ok payment-amount)
      )
    )
    ERR-NOT-FOUND
  )
)

;; Deactivate an employee
(define-public (deactivate-employee (employee-id uint))
  (match (map-get? employees { employee-id: employee-id })
    employee-data
    (begin
      (asserts! (is-authorized tx-sender) ERR-UNAUTHORIZED)
      (asserts! (get is-active employee-data) ERR-NOT-FOUND)
      
      (map-set employees
        { employee-id: employee-id }
        (merge employee-data { is-active: false })
      )
      
      (var-set total-employees (- (var-get total-employees) u1))
      (ok true)
    )
    ERR-NOT-FOUND
  )
)

;; Emergency pause/unpause contract
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

;; Batch process payments for multiple employees with enhanced validation and reporting
(define-public (batch-process-payments (employee-ids (list 50 uint)))
  (let ((current-balance (var-get contract-balance))
        (total-payment-amount (fold calculate-total-payment-amount employee-ids u0)))
    (begin
      (asserts! (is-authorized tx-sender) ERR-UNAUTHORIZED)
      (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
      (asserts! (>= current-balance total-payment-amount) ERR-INSUFFICIENT-FUNDS)
      
      ;; Process each payment and collect results
      (let ((payment-results (map process-single-payment employee-ids))
            (successful-payments (len (filter is-payment-successful payment-results)))
            (total-paid (fold sum-successful-payments payment-results u0)))
        
        ;; Update monthly budget tracking
        (var-set monthly-payroll-budget (+ (var-get monthly-payroll-budget) total-paid))
        
        ;; Return comprehensive batch processing results
        (ok {
          total-employees-processed: (len employee-ids),
          successful-payments: successful-payments,
          total-amount-paid: total-paid,
          remaining-balance: (- (var-get contract-balance) total-paid),
          processing-block: block-height
        })
      )
    )
  )
)

;; Helper function to calculate total payment amount for batch processing
(define-private (calculate-total-payment-amount (employee-id uint) (acc uint))
  (match (map-get? employees { employee-id: employee-id })
    employee-data
    (if (and (get is-active employee-data) (is-payment-due employee-id))
        (+ acc (get salary-amount employee-data))
        acc)
    acc
  )
)

;; Helper function to process a single payment in batch
(define-private (process-single-payment (employee-id uint))
  (if (is-payment-due employee-id)
      (match (process-payment employee-id)
        success-amount (some success-amount)
        error-code none)
      none)
)

;; Helper function to check if payment was successful
(define-private (is-payment-successful (payment-result (optional uint)))
  (is-some payment-result)
)

;; Helper function to sum successful payments
(define-private (sum-successful-payments (payment-result (optional uint)) (acc uint))
  (match payment-result
    amount (+ acc amount)
    acc
  )
)


