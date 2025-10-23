;; Supply Chain Tracker Contract

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))

(define-data-var product-counter uint u0)
(define-data-var checkpoint-counter uint u0)

(define-map products
  { product-id: uint }
  {
    origin: principal,
    product-type: (string-ascii 50),
    created-at: uint,
    current-holder: principal,
    status: (string-ascii 20)
  }
)

(define-map checkpoints
  { checkpoint-id: uint }
  {
    product-id: uint,
    holder: principal,
    location: (string-ascii 100),
    timestamp: uint,
    checkpoint-type: (string-ascii 30)
  }
)

(define-map product-checkpoints
  { product-id: uint, sequence: uint }
  { checkpoint-id: uint }
)

(define-map product-checkpoint-count
  { product-id: uint }
  { count: uint }
)

;; Create product
(define-public (create-product (product-type (string-ascii 50)))
  (let ((new-id (+ (var-get product-counter) u1)))
    (var-set product-counter new-id)
    (map-set products
      { product-id: new-id }
      {
        origin: tx-sender,
        product-type: product-type,
        created-at: block-height,
        current-holder: tx-sender,
        status: "active"
      }
    )
    (ok new-id)
  )
)

;; Add checkpoint
(define-public (add-checkpoint
    (product-id uint)
    (location (string-ascii 100))
    (checkpoint-type (string-ascii 30))
  )
  (let
    (
      (product (unwrap! (map-get? products { product-id: product-id }) ERR-NOT-FOUND))
      (new-checkpoint-id (+ (var-get checkpoint-counter) u1))
      (count (default-to u0 (get count (map-get? product-checkpoint-count { product-id: product-id }))))
    )
    (asserts! (is-eq tx-sender (get current-holder product)) ERR-NOT-AUTHORIZED)
    (var-set checkpoint-counter new-checkpoint-id)
    (map-set checkpoints
      { checkpoint-id: new-checkpoint-id }
      {
        product-id: product-id,
        holder: tx-sender,
        location: location,
        timestamp: block-height,
        checkpoint-type: checkpoint-type
      }
    )
    (map-set product-checkpoints
      { product-id: product-id, sequence: (+ count u1) }
      { checkpoint-id: new-checkpoint-id }
    )
    (map-set product-checkpoint-count
      { product-id: product-id }
      { count: (+ count u1) }
    )
    (ok new-checkpoint-id)
  )
)

;; Transfer custody
(define-public (transfer-custody (product-id uint) (new-holder principal))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get current-holder product)) ERR-NOT-AUTHORIZED)
    (map-set products
      { product-id: product-id }
      (merge product { current-holder: new-holder })
    )
    (ok true)
  )
)

(define-read-only (get-product (product-id uint))
  (map-get? products { product-id: product-id })
)

(define-read-only (get-checkpoint (checkpoint-id uint))
  (map-get? checkpoints { checkpoint-id: checkpoint-id })
)

(define-read-only (get-product-checkpoint-count (product-id uint))
  (map-get? product-checkpoint-count { product-id: product-id })
)

(define-read-only (get-stats)
  (ok {
    total-products: (var-get product-counter),
    total-checkpoints: (var-get checkpoint-counter)
  })
)

;; Update product status
(define-public (update-product-status (product-id uint) (new-status (string-ascii 20)))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get current-holder product)) ERR-NOT-AUTHORIZED)
    (map-set products
      { product-id: product-id }
      (merge product { status: new-status })
    )
    (ok true)
  )
)

;; Get checkpoint by sequence
(define-read-only (get-checkpoint-by-sequence (product-id uint) (sequence uint))
  (match (map-get? product-checkpoints { product-id: product-id, sequence: sequence })
    entry (map-get? checkpoints { checkpoint-id: (get checkpoint-id entry) })
    none
  )
)

;; Verify product authenticity
(define-read-only (verify-product (product-id uint))
  (match (map-get? products { product-id: product-id })
    product (ok {
      exists: true,
      origin: (get origin product),
      current-holder: (get current-holder product),
      status: (get status product)
    })
    (ok { exists: false, origin: tx-sender, current-holder: tx-sender, status: "" })
  )
)

;; Get full product history count
(define-read-only (get-product-history-length (product-id uint))
  (default-to u0 (get count (map-get? product-checkpoint-count { product-id: product-id })))
)

;; Check if user is current holder
(define-read-only (is-current-holder (product-id uint) (user principal))
  (match (map-get? products { product-id: product-id })
    product (ok (is-eq user (get current-holder product)))
    (ok false)
  )
)
