(define-constant ERR_RATE_LIMIT_EXCEEDED (err u500))
(define-constant ERR_COOLDOWN_ACTIVE (err u501))
(define-constant ERR_SUSPICIOUS_PATTERN (err u502))
(define-constant ERR_UNAUTHORIZED_RATE_ACCESS (err u503))

(define-constant DEFAULT_GRANT_LIMIT u5)
(define-constant DEFAULT_REVOKE_LIMIT u3)
(define-constant DEFAULT_COOLDOWN_BLOCKS u10)
(define-constant PATTERN_THRESHOLD u10)

(define-map rate-limit-config
  { config-key: (string-ascii 30) }
  { limit-value: uint, window-blocks: uint }
)

(define-map patient-activity-tracker
  { patient-id: principal }
  { 
    grant-count: uint,
    revoke-count: uint,
    last-grant-block: uint,
    last-revoke-block: uint,
    window-start: uint,
    flagged: bool
  }
)

(define-map provider-activity-tracker
  { provider-id: principal }
  {
    consent-received-count: uint,
    window-start: uint,
    unique-patients: uint,
    flagged: bool
  }
)

(define-map cooldown-registry
  { user-id: principal, operation-type: (string-ascii 20) }
  { cooldown-until: uint, reason: (string-ascii 100) }
)

(define-data-var rate-limit-window uint u144)

(define-read-only (get-patient-activity (patient-id principal))
  (map-get? patient-activity-tracker { patient-id: patient-id })
)

(define-read-only (get-provider-activity (provider-id principal))
  (map-get? provider-activity-tracker { provider-id: provider-id })
)

(define-read-only (check-cooldown (user-id principal) (operation-type (string-ascii 20)))
  (match (map-get? cooldown-registry { user-id: user-id, operation-type: operation-type })
    cooldown-data (> (get cooldown-until cooldown-data) stacks-block-height)
    false
  )
)

(define-public (track-consent-grant (patient-id principal) (provider-id principal))
  (let
    (
      (current-activity (default-to 
        { grant-count: u0, revoke-count: u0, last-grant-block: u0, 
          last-revoke-block: u0, window-start: stacks-block-height, flagged: false }
        (get-patient-activity patient-id)))
      (window-expired (> (- stacks-block-height (get window-start current-activity)) (var-get rate-limit-window)))
      (reset-activity (if window-expired
        { grant-count: u1, revoke-count: u0, last-grant-block: stacks-block-height,
          last-revoke-block: u0, window-start: stacks-block-height, flagged: false }
        (merge current-activity { 
          grant-count: (+ (get grant-count current-activity) u1),
          last-grant-block: stacks-block-height 
        })))
    )
    (if (check-cooldown patient-id "grant")
      ERR_COOLDOWN_ACTIVE
      (if (and (not window-expired) (>= (get grant-count reset-activity) DEFAULT_GRANT_LIMIT))
        (begin
          (map-set cooldown-registry
            { user-id: patient-id, operation-type: "grant" }
            { cooldown-until: (+ stacks-block-height DEFAULT_COOLDOWN_BLOCKS), 
              reason: "Grant rate limit exceeded" })
          ERR_RATE_LIMIT_EXCEEDED
        )
        (begin
          (map-set patient-activity-tracker { patient-id: patient-id } reset-activity)
          (ok true)
        )
      )
    )
  )
)

(define-public (track-consent-revoke (patient-id principal) (provider-id principal))
  (let
    (
      (current-activity (default-to 
        { grant-count: u0, revoke-count: u0, last-grant-block: u0, 
          last-revoke-block: u0, window-start: stacks-block-height, flagged: false }
        (get-patient-activity patient-id)))
      (window-expired (> (- stacks-block-height (get window-start current-activity)) (var-get rate-limit-window)))
      (reset-activity (if window-expired
        { grant-count: u0, revoke-count: u1, last-grant-block: u0,
          last-revoke-block: stacks-block-height, window-start: stacks-block-height, flagged: false }
        (merge current-activity { 
          revoke-count: (+ (get revoke-count current-activity) u1),
          last-revoke-block: stacks-block-height 
        })))
    )
    (if (check-cooldown patient-id "revoke")
      ERR_COOLDOWN_ACTIVE
      (if (and (not window-expired) (>= (get revoke-count reset-activity) DEFAULT_REVOKE_LIMIT))
        (begin
          (map-set cooldown-registry
            { user-id: patient-id, operation-type: "revoke" }
            { cooldown-until: (+ stacks-block-height DEFAULT_COOLDOWN_BLOCKS), 
              reason: "Revoke rate limit exceeded" })
          ERR_RATE_LIMIT_EXCEEDED
        )
        (begin
          (map-set patient-activity-tracker { patient-id: patient-id } reset-activity)
          (ok true)
        )
      )
    )
  )
)
