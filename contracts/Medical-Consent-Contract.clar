(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PATIENT_NOT_FOUND (err u101))
(define-constant ERR_CONSENT_NOT_FOUND (err u102))
(define-constant ERR_CONSENT_EXPIRED (err u103))
(define-constant ERR_CONSENT_ALREADY_EXISTS (err u104))
(define-constant ERR_INVALID_EXPIRY (err u105))
(define-constant ERR_PATIENT_ALREADY_REGISTERED (err u106))
(define-constant ERR_INVALID_PURPOSE (err u107))

(define-constant ERR_EMERGENCY_CONTACT_NOT_FOUND (err u108))
(define-constant ERR_EMERGENCY_CONTACT_ALREADY_EXISTS (err u109))
(define-constant ERR_NOT_EMERGENCY_CONTACT (err u110))

(define-map patients
  { patient-id: principal }
  {
    name: (string-ascii 100),
    email: (string-ascii 100),
    phone: (string-ascii 20),
    registered-at: uint,
    active: bool
  }
)

(define-map consents
  { patient-id: principal, provider-id: principal, purpose: (string-ascii 50) }
  {
    granted-at: uint,
    expires-at: uint,
    data-types: (list 10 (string-ascii 30)),
    active: bool,
    access-count: uint,
    last-accessed: uint
  }
)

(define-map providers
  { provider-id: principal }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    specialty: (string-ascii 50),
    verified: bool,
    registered-at: uint
  }
)

(define-map access-logs
  { log-id: uint }
  {
    patient-id: principal,
    provider-id: principal,
    purpose: (string-ascii 50),
    accessed-at: uint,
    data-accessed: (string-ascii 200)
  }
)

(define-data-var next-log-id uint u1)

(define-read-only (get-patient (patient-id principal))
  (map-get? patients { patient-id: patient-id })
)

(define-read-only (get-provider (provider-id principal))
  (map-get? providers { provider-id: provider-id })
)

(define-read-only (get-consent (patient-id principal) (provider-id principal) (purpose (string-ascii 50)))
  (map-get? consents { patient-id: patient-id, provider-id: provider-id, purpose: purpose })
)

(define-read-only (is-consent-valid (patient-id principal) (provider-id principal) (purpose (string-ascii 50)))
  (let ((consent (get-consent patient-id provider-id purpose)))
    (match consent
      consent-data
      (and 
        (get active consent-data)
        (> (get expires-at consent-data) stacks-block-height)
      )
      false
    )
  )
)

(define-read-only (get-access-log (log-id uint))
  (map-get? access-logs { log-id: log-id })
)

(define-read-only (get-patient-consents (patient-id principal))
  (ok (map-get? patients { patient-id: patient-id }))
)

(define-public (register-patient (name (string-ascii 100)) (email (string-ascii 100)) (phone (string-ascii 20)))
  (let ((patient-id tx-sender))
    (if (is-some (get-patient patient-id))
      ERR_PATIENT_ALREADY_REGISTERED
      (begin
        (map-set patients
          { patient-id: patient-id }
          {
            name: name,
            email: email,
            phone: phone,
            registered-at: stacks-block-height,
            active: true
          }
        )
        (ok patient-id)
      )
    )
  )
)

(define-public (register-provider (name (string-ascii 100)) (license-number (string-ascii 50)) (specialty (string-ascii 50)))
  (let ((provider-id tx-sender))
    (begin
      (map-set providers
        { provider-id: provider-id }
        {
          name: name,
          license-number: license-number,
          specialty: specialty,
          verified: false,
          registered-at: stacks-block-height
        }
      )
      (ok provider-id)
    )
  )
)

(define-public (verify-provider (provider-id principal))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (match (get-provider provider-id)
      provider-data
      (begin
        (map-set providers
          { provider-id: provider-id }
          (merge provider-data { verified: true })
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_UNAUTHORIZED
  )
)

(define-public (grant-consent 
  (provider-id principal) 
  (purpose (string-ascii 50)) 
  (expires-at uint) 
  (data-types (list 10 (string-ascii 30)))
)
  (let ((patient-id tx-sender))
    (if (is-none (get-patient patient-id))
      ERR_PATIENT_NOT_FOUND
      (if (is-none (get-provider provider-id))
        ERR_UNAUTHORIZED
        (if (<= expires-at stacks-block-height)
          ERR_INVALID_EXPIRY
          (if (is-some (get-consent patient-id provider-id purpose))
            ERR_CONSENT_ALREADY_EXISTS
            (begin
              (map-set consents
                { patient-id: patient-id, provider-id: provider-id, purpose: purpose }
                {
                  granted-at: stacks-block-height,
                  expires-at: expires-at,
                  data-types: data-types,
                  active: true,
                  access-count: u0,
                  last-accessed: u0
                }
              )
              (ok true)
            )
          )
        )
      )
    )
  )
)

(define-public (revoke-consent (provider-id principal) (purpose (string-ascii 50)))
  (let ((patient-id tx-sender))
    (match (get-consent patient-id provider-id purpose)
      consent-data
      (begin
        (map-set consents
          { patient-id: patient-id, provider-id: provider-id, purpose: purpose }
          (merge consent-data { active: false })
        )
        (ok true)
      )
      ERR_CONSENT_NOT_FOUND
    )
  )
)

(define-public (access-data 
  (patient-id principal) 
  (purpose (string-ascii 50)) 
  (data-accessed (string-ascii 200))
)
  (let ((provider-id tx-sender))
    (if (is-consent-valid patient-id provider-id purpose)
      (match (get-consent patient-id provider-id purpose)
        consent-data
        (let ((log-id (var-get next-log-id)))
          (begin
            (map-set consents
              { patient-id: patient-id, provider-id: provider-id, purpose: purpose }
              (merge consent-data 
                { 
                  access-count: (+ (get access-count consent-data) u1),
                  last-accessed: stacks-block-height
                }
              )
            )
            (map-set access-logs
              { log-id: log-id }
              {
                patient-id: patient-id,
                provider-id: provider-id,
                purpose: purpose,
                accessed-at: stacks-block-height,
                data-accessed: data-accessed
              }
            )
            (var-set next-log-id (+ log-id u1))
            (ok log-id)
          )
        )
        ERR_CONSENT_NOT_FOUND
      )
      ERR_CONSENT_EXPIRED
    )
  )
)

(define-public (extend-consent 
  (provider-id principal) 
  (purpose (string-ascii 50)) 
  (new-expires-at uint)
)
  (let ((patient-id tx-sender))
    (if (<= new-expires-at stacks-block-height)
      ERR_INVALID_EXPIRY
      (match (get-consent patient-id provider-id purpose)
        consent-data
        (if (get active consent-data)
          (begin
            (map-set consents
              { patient-id: patient-id, provider-id: provider-id, purpose: purpose }
              (merge consent-data { expires-at: new-expires-at })
            )
            (ok true)
          )
          ERR_CONSENT_EXPIRED
        )
        ERR_CONSENT_NOT_FOUND
      )
    )
  )
)

(define-public (update-patient-info 
  (name (string-ascii 100)) 
  (email (string-ascii 100)) 
  (phone (string-ascii 20))
)
  (let ((patient-id tx-sender))
    (match (get-patient patient-id)
      patient-data
      (begin
        (map-set patients
          { patient-id: patient-id }
          (merge patient-data 
            {
              name: name,
              email: email,
              phone: phone
            }
          )
        )
        (ok true)
      )
      ERR_PATIENT_NOT_FOUND
    )
  )
)

(define-public (deactivate-patient)
  (let ((patient-id tx-sender))
    (match (get-patient patient-id)
      patient-data
      (begin
        (map-set patients
          { patient-id: patient-id }
          (merge patient-data { active: false })
        )
        (ok true)
      )
      ERR_PATIENT_NOT_FOUND
    )
  )
)



(define-map emergency-contacts
  { patient-id: principal, contact-id: principal }
  {
    contact-name: (string-ascii 100),
    relationship: (string-ascii 50),
    phone: (string-ascii 20),
    email: (string-ascii 100),
    priority: uint,
    active: bool,
    designated-at: uint
  }
)

(define-map emergency-consents
  { patient-id: principal, provider-id: principal, purpose: (string-ascii 50), contact-id: principal }
  {
    granted-at: uint,
    expires-at: uint,
    data-types: (list 10 (string-ascii 30)),
    emergency-reason: (string-ascii 200),
    active: bool
  }
)

(define-read-only (get-emergency-contact (patient-id principal) (contact-id principal))
  (map-get? emergency-contacts { patient-id: patient-id, contact-id: contact-id })
)

(define-read-only (is-emergency-contact (patient-id principal) (contact-id principal))
  (match (get-emergency-contact patient-id contact-id)
    contact-data (get active contact-data)
    false
  )
)

(define-public (designate-emergency-contact
  (contact-id principal)
  (contact-name (string-ascii 100))
  (relationship (string-ascii 50))
  (phone (string-ascii 20))
  (email (string-ascii 100))
  (priority uint)
)
  (let ((patient-id tx-sender))
    (if (is-some (get-emergency-contact patient-id contact-id))
      ERR_EMERGENCY_CONTACT_ALREADY_EXISTS
      (begin
        (map-set emergency-contacts
          { patient-id: patient-id, contact-id: contact-id }
          {
            contact-name: contact-name,
            relationship: relationship,
            phone: phone,
            email: email,
            priority: priority,
            active: true,
            designated-at: stacks-block-height
          }
        )
        (ok true)
      )
    )
  )
)

(define-public (emergency-grant-consent
  (patient-id principal)
  (provider-id principal)
  (purpose (string-ascii 50))
  (expires-at uint)
  (data-types (list 10 (string-ascii 30)))
  (emergency-reason (string-ascii 200))
)
  (let ((contact-id tx-sender))
    (if (not (is-emergency-contact patient-id contact-id))
      ERR_NOT_EMERGENCY_CONTACT
      (if (is-none (get-provider provider-id))
        ERR_UNAUTHORIZED
        (if (<= expires-at stacks-block-height)
          ERR_INVALID_EXPIRY
          (begin
            (map-set emergency-consents
              { patient-id: patient-id, provider-id: provider-id, purpose: purpose, contact-id: contact-id }
              {
                granted-at: stacks-block-height,
                expires-at: expires-at,
                data-types: data-types,
                emergency-reason: emergency-reason,
                active: true
              }
            )
            (ok true)
          )
        )
      )
    )
  )
)
