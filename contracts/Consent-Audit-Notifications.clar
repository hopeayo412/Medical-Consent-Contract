(define-constant ERR_NOTIFICATION_NOT_FOUND (err u300))
(define-constant ERR_AUDIT_LOG_NOT_FOUND (err u301))
(define-constant ERR_UNAUTHORIZED_AUDIT_ACCESS (err u302))

(define-map audit-events
  { event-id: uint }
  {
    event-type: (string-ascii 30),
    patient-id: principal,
    provider-id: (optional principal),
    purpose: (optional (string-ascii 50)),
    timestamp: uint,
    block-height: uint,
    details: (string-ascii 200)
  }
)

(define-map notification-preferences
  { user-id: principal }
  {
    consent-granted: bool,
    consent-revoked: bool,
    consent-expired: bool,
    data-accessed: bool,
    active: bool
  }
)

(define-map pending-notifications
  { notification-id: uint }
  {
    recipient-id: principal,
    message-type: (string-ascii 30),
    message-content: (string-ascii 200),
    created-at: uint,
    processed: bool
  }
)

(define-data-var next-event-id uint u1)
(define-data-var next-notification-id uint u1)

(define-read-only (get-audit-event (event-id uint))
  (map-get? audit-events { event-id: event-id })
)

(define-read-only (get-notification-preferences (user-id principal))
  (map-get? notification-preferences { user-id: user-id })
)

(define-read-only (get-pending-notification (notification-id uint))
  (map-get? pending-notifications { notification-id: notification-id })
)

(define-public (set-notification-preferences
  (consent-granted bool)
  (consent-revoked bool) 
  (consent-expired bool)
  (data-accessed bool)
)
  (let ((user-id tx-sender))
    (begin
      (map-set notification-preferences
        { user-id: user-id }
        {
          consent-granted: consent-granted,
          consent-revoked: consent-revoked,
          consent-expired: consent-expired,
          data-accessed: data-accessed,
          active: true
        }
      )
      (ok true)
    )
  )
)

(define-public (log-audit-event
  (event-type (string-ascii 30))
  (patient-id principal)
  (provider-id (optional principal))
  (purpose (optional (string-ascii 50)))
  (details (string-ascii 200))
)
  (let ((event-id (var-get next-event-id)))
    (begin
      (map-set audit-events
        { event-id: event-id }
        {
          event-type: event-type,
          patient-id: patient-id,
          provider-id: provider-id,
          purpose: purpose,
          timestamp: stacks-block-height,
          block-height: stacks-block-height,
          details: details
        }
      )
      (var-set next-event-id (+ event-id u1))
      (ok event-id)
    )
  )
)

(define-public (create-notification
  (recipient-id principal)
  (message-type (string-ascii 30))
  (message-content (string-ascii 200))
)
  (let ((notification-id (var-get next-notification-id)))
    (begin
      (map-set pending-notifications
        { notification-id: notification-id }
        {
          recipient-id: recipient-id,
          message-type: message-type,
          message-content: message-content,
          created-at: stacks-block-height,
          processed: false
        }
      )
      (var-set next-notification-id (+ notification-id u1))
      (ok notification-id)
    )
  )
)

(define-public (mark-notification-processed (notification-id uint))
  (match (get-pending-notification notification-id)
    notification-data
    (begin
      (map-set pending-notifications
        { notification-id: notification-id }
        (merge notification-data { processed: true })
      )
      (ok true)
    )
    ERR_NOTIFICATION_NOT_FOUND
  )
)

(define-public (notify-consent-granted
  (patient-id principal)
  (provider-id principal)
  (purpose (string-ascii 50))
)
  (begin
    (unwrap-panic (log-audit-event "consent-granted" patient-id (some provider-id) (some purpose) "Consent granted successfully"))
    (unwrap-panic (create-notification patient-id "consent-granted" "Your consent has been recorded"))
    (ok true)
  )
)

(define-public (notify-data-accessed
  (patient-id principal)
  (provider-id principal)
  (purpose (string-ascii 50))
)
  (begin
    (unwrap-panic (log-audit-event "data-accessed" patient-id (some provider-id) (some purpose) "Patient data accessed by provider"))
    (unwrap-panic (create-notification patient-id "data-accessed" "Your medical data was accessed"))
    (ok true)
  )
)

(define-read-only (get-audit-count-for-patient (patient-id principal))
  (let ((current-event-id (var-get next-event-id)))
    (ok current-event-id)
  )
)
