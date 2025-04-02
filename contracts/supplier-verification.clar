;; Supplier Verification Contract
;; This contract validates compliance with ethical standards

(define-data-var admin principal tx-sender)

;; Supplier data structure
(define-map suppliers
  { supplier-id: (string-ascii 64) }
  {
    name: (string-ascii 100),
    verified: bool,
    ethical-score: uint,
    verification-date: uint,
    verifier: principal
  }
)

;; Standards data structure
(define-map ethical-standards
  { standard-id: (string-ascii 64) }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    required-score: uint
  }
)

;; Supplier compliance with standards
(define-map supplier-compliance
  {
    supplier-id: (string-ascii 64),
    standard-id: (string-ascii 64)
  }
  {
    compliant: bool,
    evidence-hash: (buff 32),
    verification-date: uint
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SUPPLIER-EXISTS (err u101))
(define-constant ERR-SUPPLIER-NOT-FOUND (err u102))
(define-constant ERR-STANDARD-EXISTS (err u103))
(define-constant ERR-STANDARD-NOT-FOUND (err u104))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new supplier
(define-public (register-supplier (supplier-id (string-ascii 64)) (name (string-ascii 100)))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? suppliers {supplier-id: supplier-id})) ERR-SUPPLIER-EXISTS)

    (map-set suppliers
      {supplier-id: supplier-id}
      {
        name: name,
        verified: false,
        ethical-score: u0,
        verification-date: u0,
        verifier: tx-sender
      }
    )
    (ok true)
  )
)

;; Verify a supplier
(define-public (verify-supplier (supplier-id (string-ascii 64)) (ethical-score uint))
  (let (
    (supplier (unwrap! (map-get? suppliers {supplier-id: supplier-id}) ERR-SUPPLIER-NOT-FOUND))
  )
    (begin
      (asserts! (is-admin) ERR-NOT-AUTHORIZED)

      (map-set suppliers
        {supplier-id: supplier-id}
        (merge supplier {
          verified: true,
          ethical-score: ethical-score,
          verification-date: block-height,
          verifier: tx-sender
        })
      )
      (ok true)
    )
  )
)

;; Add a new ethical standard
(define-public (add-ethical-standard (standard-id (string-ascii 64)) (name (string-ascii 100)) (description (string-utf8 500)) (required-score uint))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? ethical-standards {standard-id: standard-id})) ERR-STANDARD-EXISTS)

    (map-set ethical-standards
      {standard-id: standard-id}
      {
        name: name,
        description: description,
        required-score: required-score
      }
    )
    (ok true)
  )
)

;; Record supplier compliance with a standard
(define-public (record-compliance (supplier-id (string-ascii 64)) (standard-id (string-ascii 64)) (compliant bool) (evidence-hash (buff 32)))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? suppliers {supplier-id: supplier-id})) ERR-SUPPLIER-NOT-FOUND)
    (asserts! (is-some (map-get? ethical-standards {standard-id: standard-id})) ERR-STANDARD-NOT-FOUND)

    (map-set supplier-compliance
      {
        supplier-id: supplier-id,
        standard-id: standard-id
      }
      {
        compliant: compliant,
        evidence-hash: evidence-hash,
        verification-date: block-height
      }
    )
    (ok true)
  )
)

;; Check if a supplier is compliant with a standard
(define-read-only (check-compliance (supplier-id (string-ascii 64)) (standard-id (string-ascii 64)))
  (default-to
    {
      compliant: false,
      evidence-hash: 0x0000000000000000000000000000000000000000000000000000000000000000,
      verification-date: u0
    }
    (map-get? supplier-compliance {supplier-id: supplier-id, standard-id: standard-id})
  )
)

;; Get supplier details
(define-read-only (get-supplier (supplier-id (string-ascii 64)))
  (map-get? suppliers {supplier-id: supplier-id})
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
