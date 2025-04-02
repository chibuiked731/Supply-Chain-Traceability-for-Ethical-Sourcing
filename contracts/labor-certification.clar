;; Labor Certification Contract
;; This contract verifies fair labor practices

(define-data-var admin principal tx-sender)

;; Labor certification data structure
(define-map labor-certifications
  { entity-id: (string-ascii 64) }
  {
    name: (string-ascii 100),
    certification-type: (string-ascii 64),
    certified: bool,
    certification-date: uint,
    expiration-date: uint,
    certifier: principal
  }
)

;; Labor standards data structure
(define-map labor-standards
  { standard-id: (string-ascii 64) }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    minimum-wage: uint,
    max-hours-per-week: uint
  }
)

;; Entity compliance with labor standards
(define-map entity-compliance
  {
    entity-id: (string-ascii 64),
    standard-id: (string-ascii 64)
  }
  {
    compliant: bool,
    evidence-hash: (buff 32),
    verification-date: uint,
    next-audit-date: uint
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CERTIFICATION-EXISTS (err u101))
(define-constant ERR-CERTIFICATION-NOT-FOUND (err u102))
(define-constant ERR-STANDARD-EXISTS (err u103))
(define-constant ERR-STANDARD-NOT-FOUND (err u104))
(define-constant ERR-EXPIRED-CERTIFICATION (err u105))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new labor certification
(define-public (register-certification
  (entity-id (string-ascii 64))
  (name (string-ascii 100))
  (certification-type (string-ascii 64))
  (expiration-blocks uint)
)
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? labor-certifications {entity-id: entity-id})) ERR-CERTIFICATION-EXISTS)

    (map-set labor-certifications
      {entity-id: entity-id}
      {
        name: name,
        certification-type: certification-type,
        certified: false,
        certification-date: u0,
        expiration-date: u0,
        certifier: tx-sender
      }
    )
    (ok true)
  )
)

;; Certify an entity
(define-public (certify-entity (entity-id (string-ascii 64)) (expiration-blocks uint))
  (let (
    (certification (unwrap! (map-get? labor-certifications {entity-id: entity-id}) ERR-CERTIFICATION-NOT-FOUND))
  )
    (begin
      (asserts! (is-admin) ERR-NOT-AUTHORIZED)

      (map-set labor-certifications
        {entity-id: entity-id}
        (merge certification {
          certified: true,
          certification-date: block-height,
          expiration-date: (+ block-height expiration-blocks),
          certifier: tx-sender
        })
      )
      (ok true)
    )
  )
)

;; Add a new labor standard
(define-public (add-labor-standard
  (standard-id (string-ascii 64))
  (name (string-ascii 100))
  (description (string-utf8 500))
  (minimum-wage uint)
  (max-hours-per-week uint)
)
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? labor-standards {standard-id: standard-id})) ERR-STANDARD-EXISTS)

    (map-set labor-standards
      {standard-id: standard-id}
      {
        name: name,
        description: description,
        minimum-wage: minimum-wage,
        max-hours-per-week: max-hours-per-week
      }
    )
    (ok true)
  )
)

;; Record entity compliance with a labor standard
(define-public (record-compliance
  (entity-id (string-ascii 64))
  (standard-id (string-ascii 64))
  (compliant bool)
  (evidence-hash (buff 32))
  (next-audit-blocks uint)
)
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? labor-certifications {entity-id: entity-id})) ERR-CERTIFICATION-NOT-FOUND)
    (asserts! (is-some (map-get? labor-standards {standard-id: standard-id})) ERR-STANDARD-NOT-FOUND)

    (map-set entity-compliance
      {
        entity-id: entity-id,
        standard-id: standard-id
      }
      {
        compliant: compliant,
        evidence-hash: evidence-hash,
        verification-date: block-height,
        next-audit-date: (+ block-height next-audit-blocks)
      }
    )
    (ok true)
  )
)

;; Check if a certification is valid
(define-read-only (is-certification-valid (entity-id (string-ascii 64)))
  (let (
    (certification (unwrap! (map-get? labor-certifications {entity-id: entity-id}) false))
  )
    (and
      (get certified certification)
      (< block-height (get expiration-date certification))
    )
  )
)

;; Get certification details
(define-read-only (get-certification (entity-id (string-ascii 64)))
  (map-get? labor-certifications {entity-id: entity-id})
)

;; Get standard details
(define-read-only (get-labor-standard (standard-id (string-ascii 64)))
  (map-get? labor-standards {standard-id: standard-id})
)

;; Get compliance details
(define-read-only (get-compliance (entity-id (string-ascii 64)) (standard-id (string-ascii 64)))
  (map-get? entity-compliance {entity-id: entity-id, standard-id: standard-id})
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
