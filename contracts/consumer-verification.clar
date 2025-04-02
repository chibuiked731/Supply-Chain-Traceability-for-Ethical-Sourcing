;; Consumer Verification Contract
;; This contract allows end users to confirm ethical claims

(define-data-var admin principal tx-sender)

;; Product verification data structure
(define-map product-verifications
  { product-id: (string-ascii 64) }
  {
    ethical-score: uint,
    labor-certified: bool,
    materials-certified: bool,
    verification-date: uint,
    verifier: principal,
    verification-hash: (buff 32)
  }
)

;; Consumer verification requests
(define-map verification-requests
  { request-id: (string-ascii 64) }
  {
    product-id: (string-ascii 64),
    consumer: principal,
    request-date: uint,
    status: (string-ascii 20),
    response-hash: (buff 32)
  }
)

;; Product reviews by consumers
(define-map product-reviews
  {
    product-id: (string-ascii 64),
    reviewer: principal
  }
  {
    rating: uint,
    review-text: (string-utf8 500),
    review-date: uint,
    verified-purchase: bool
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-VERIFICATION-EXISTS (err u101))
(define-constant ERR-VERIFICATION-NOT-FOUND (err u102))
(define-constant ERR-REQUEST-EXISTS (err u103))
(define-constant ERR-REQUEST-NOT-FOUND (err u104))
(define-constant ERR-REVIEW-EXISTS (err u105))
(define-constant ERR-INVALID-RATING (err u106))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a product verification
(define-public (register-verification
  (product-id (string-ascii 64))
  (ethical-score uint)
  (labor-certified bool)
  (materials-certified bool)
  (verification-hash (buff 32))
)
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)

    (map-set product-verifications
      {product-id: product-id}
      {
        ethical-score: ethical-score,
        labor-certified: labor-certified,
        materials-certified: materials-certified,
        verification-date: block-height,
        verifier: tx-sender,
        verification-hash: verification-hash
      }
    )
    (ok true)
  )
)

;; Consumer requests verification of a product
(define-public (request-verification (request-id (string-ascii 64)) (product-id (string-ascii 64)))
  (begin
    (asserts! (is-none (map-get? verification-requests {request-id: request-id})) ERR-REQUEST-EXISTS)

    (map-set verification-requests
      {request-id: request-id}
      {
        product-id: product-id,
        consumer: tx-sender,
        request-date: block-height,
        status: "pending",
        response-hash: 0x0000000000000000000000000000000000000000000000000000000000000000
      }
    )
    (ok true)
  )
)

;; Admin responds to verification request
(define-public (respond-to-request (request-id (string-ascii 64)) (status (string-ascii 20)) (response-hash (buff 32)))
  (let (
    (request (unwrap! (map-get? verification-requests {request-id: request-id}) ERR-REQUEST-NOT-FOUND))
  )
    (begin
      (asserts! (is-admin) ERR-NOT-AUTHORIZED)

      (map-set verification-requests
        {request-id: request-id}
        (merge request {
          status: status,
          response-hash: response-hash
        })
      )
      (ok true)
    )
  )
)

;; Consumer submits a review for a product
(define-public (submit-review
  (product-id (string-ascii 64))
  (rating uint)
  (review-text (string-utf8 500))
  (verified-purchase bool)
)
  (begin
    (asserts! (is-none (map-get? product-reviews {product-id: product-id, reviewer: tx-sender})) ERR-REVIEW-EXISTS)
    (asserts! (<= rating u5) ERR-INVALID-RATING)

    (map-set product-reviews
      {
        product-id: product-id,
        reviewer: tx-sender
      }
      {
        rating: rating,
        review-text: review-text,
        review-date: block-height,
        verified-purchase: verified-purchase
      }
    )
    (ok true)
  )
)

;; Get product verification details
(define-read-only (get-product-verification (product-id (string-ascii 64)))
  (map-get? product-verifications {product-id: product-id})
)

;; Get verification request details
(define-read-only (get-verification-request (request-id (string-ascii 64)))
  (map-get? verification-requests {request-id: request-id})
)

;; Get product review
(define-read-only (get-product-review (product-id (string-ascii 64)) (reviewer principal))
  (map-get? product-reviews {product-id: product-id, reviewer: reviewer})
)

;; Check if a product is ethically verified
(define-read-only (is-product-ethical (product-id (string-ascii 64)))
  (let (
    (verification (unwrap! (map-get? product-verifications {product-id: product-id}) false))
  )
    (and
      (>= (get ethical-score verification) u3)
      (get labor-certified verification)
      (get materials-certified verification)
    )
  )
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
