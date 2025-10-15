(define-constant ERR_DELEGATE_NOT_FOUND (err u400))
(define-constant ERR_DELEGATION_EXPIRED (err u401))
(define-constant ERR_DELEGATION_ALREADY_EXISTS (err u402))
(define-constant ERR_UNAUTHORIZED_DELEGATE (err u403))
(define-constant ERR_INVALID_DELEGATION_SCOPE (err u404))

(define-map delegations
  { patient-id: principal, delegate-id: principal }
  {
    delegate-name: (string-ascii 100),
    relationship: (string-ascii 50),
    granted-at: uint,
    expires-at: uint,
    scope: (list 5 (string-ascii 30)),
    active: bool,
    usage-count: uint,
    last-used: uint
  }
)

(define-map delegation-actions
  { action-id: uint }
  {
    patient-id: principal,
    delegate-id: principal,
    action-type: (string-ascii 30),
    provider-id: principal,
    purpose: (string-ascii 50),
    timestamp: uint,
    success: bool
  }
)

(define-data-var next-action-id uint u1)

(define-read-only (get-delegation (patient-id principal) (delegate-id principal))
  (map-get? delegations { patient-id: patient-id, delegate-id: delegate-id })
)

(define-read-only (is-delegation-valid (patient-id principal) (delegate-id principal))
  (match (get-delegation patient-id delegate-id)
    delegation-data
    (and 
      (get active delegation-data)
      (> (get expires-at delegation-data) stacks-block-height)
    )
    false
  )
)

(define-read-only (get-delegation-action (action-id uint))
  (map-get? delegation-actions { action-id: action-id })
)

(define-public (grant-delegation
  (delegate-id principal)
  (delegate-name (string-ascii 100))
  (relationship (string-ascii 50))
  (expires-at uint)
  (scope (list 5 (string-ascii 30)))
)
  (let ((patient-id tx-sender))
    (if (is-some (get-delegation patient-id delegate-id))
      ERR_DELEGATION_ALREADY_EXISTS
      (if (<= expires-at stacks-block-height)
        ERR_INVALID_DELEGATION_SCOPE
        (begin
          (map-set delegations
            { patient-id: patient-id, delegate-id: delegate-id }
            {
              delegate-name: delegate-name,
              relationship: relationship,
              granted-at: stacks-block-height,
              expires-at: expires-at,
              scope: scope,
              active: true,
              usage-count: u0,
              last-used: u0
            }
          )
          (ok delegate-id)
        )
      )
    )
  )
)

(define-public (revoke-delegation (delegate-id principal))
  (let ((patient-id tx-sender))
    (match (get-delegation patient-id delegate-id)
      delegation-data
      (begin
        (map-set delegations
          { patient-id: patient-id, delegate-id: delegate-id }
          (merge delegation-data { active: false })
        )
        (ok true)
      )
      ERR_DELEGATE_NOT_FOUND
    )
  )
)

(define-public (log-delegation-action
  (patient-id principal)
  (action-type (string-ascii 30))
  (provider-id principal)
  (purpose (string-ascii 50))
  (success bool)
)
  (let ((delegate-id tx-sender))
    (if (not (is-delegation-valid patient-id delegate-id))
      ERR_DELEGATION_EXPIRED
      (let ((action-id (var-get next-action-id)))
        (match (get-delegation patient-id delegate-id)
          delegation-data
          (begin
            (map-set delegations
              { patient-id: patient-id, delegate-id: delegate-id }
              (merge delegation-data 
                { 
                  usage-count: (+ (get usage-count delegation-data) u1),
                  last-used: stacks-block-height
                }
              )
            )
            (map-set delegation-actions
              { action-id: action-id }
              {
                patient-id: patient-id,
                delegate-id: delegate-id,
                action-type: action-type,
                provider-id: provider-id,
                purpose: purpose,
                timestamp: stacks-block-height,
                success: success
              }
            )
            (var-set next-action-id (+ action-id u1))
            (ok action-id)
          )
          ERR_DELEGATE_NOT_FOUND
        )
      )
    )
  )
)

(define-public (extend-delegation
  (delegate-id principal)
  (new-expires-at uint)
)
  (let ((patient-id tx-sender))
    (if (<= new-expires-at stacks-block-height)
      ERR_INVALID_DELEGATION_SCOPE
      (match (get-delegation patient-id delegate-id)
        delegation-data
        (begin
          (map-set delegations
            { patient-id: patient-id, delegate-id: delegate-id }
            (merge delegation-data { expires-at: new-expires-at })
          )
          (ok true)
        )
        ERR_DELEGATE_NOT_FOUND
      )
    )
  )
)
