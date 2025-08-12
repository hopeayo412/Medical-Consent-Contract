(define-constant ERR_TEMPLATE_NOT_FOUND (err u200))
(define-constant ERR_TEMPLATE_INACTIVE (err u201))
(define-constant ERR_TEMPLATE_ALREADY_EXISTS (err u202))
(define-constant ERR_UNAUTHORIZED_TEMPLATE_ACCESS (err u203))

(define-map consent-templates
  { template-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    description: (string-ascii 200),
    purpose: (string-ascii 50),
    data-types: (list 10 (string-ascii 30)),
    default-duration: uint,
    created-by: principal,
    created-at: uint,
    active: bool,
    usage-count: uint
  }
)

(define-map organization-templates
  { organization-id: principal, template-id: (string-ascii 50) }
  { approved: bool, approved-at: uint }
)

(define-data-var template-usage-counter uint u0)

(define-read-only (get-consent-template (template-id (string-ascii 50)))
  (map-get? consent-templates { template-id: template-id })
)

(define-read-only (is-template-active (template-id (string-ascii 50)))
  (match (get-consent-template template-id)
    template-data (get active template-data)
    false
  )
)

(define-read-only (get-organization-template-approval (organization-id principal) (template-id (string-ascii 50)))
  (map-get? organization-templates { organization-id: organization-id, template-id: template-id })
)

(define-public (create-consent-template
  (template-id (string-ascii 50))
  (name (string-ascii 100))
  (description (string-ascii 200))
  (purpose (string-ascii 50))
  (data-types (list 10 (string-ascii 30)))
  (default-duration uint)
)
  (let ((creator tx-sender))
    (if (is-some (get-consent-template template-id))
      ERR_TEMPLATE_ALREADY_EXISTS
      (begin
        (map-set consent-templates
          { template-id: template-id }
          {
            name: name,
            description: description,
            purpose: purpose,
            data-types: data-types,
            default-duration: default-duration,
            created-by: creator,
            created-at: stacks-block-height,
            active: true,
            usage-count: u0
          }
        )
        (ok template-id)
      )
    )
  )
)

(define-public (approve-template-for-organization (template-id (string-ascii 50)))
  (let ((organization-id tx-sender))
    (if (not (is-template-active template-id))
      ERR_TEMPLATE_NOT_FOUND
      (begin
        (map-set organization-templates
          { organization-id: organization-id, template-id: template-id }
          { approved: true, approved-at: stacks-block-height }
        )
        (ok true)
      )
    )
  )
)

(define-public (deactivate-template (template-id (string-ascii 50)))
  (match (get-consent-template template-id)
    template-data
    (if (is-eq tx-sender (get created-by template-data))
      (begin
        (map-set consent-templates
          { template-id: template-id }
          (merge template-data { active: false })
        )
        (ok true)
      )
      ERR_UNAUTHORIZED_TEMPLATE_ACCESS
    )
    ERR_TEMPLATE_NOT_FOUND
  )
)

(define-private (increment-template-usage (template-id (string-ascii 50)))
  (match (get-consent-template template-id)
    template-data
    (begin
      (map-set consent-templates
        { template-id: template-id }
        (merge template-data { usage-count: (+ (get usage-count template-data) u1) })
      )
      true
    )
    false
  )
)

(define-public (grant-consent-from-template
  (template-id (string-ascii 50))
  (provider-id principal)
  (custom-expires-at (optional uint))
)
  (let ((patient-id tx-sender))
    (match (get-consent-template template-id)
      template-data
      (if (not (get active template-data))
        ERR_TEMPLATE_INACTIVE
        (let ((expires-at (default-to (+ stacks-block-height (get default-duration template-data)) custom-expires-at)))
          (begin
            (increment-template-usage template-id)
            (var-set template-usage-counter (+ (var-get template-usage-counter) u1))
            (ok {
              purpose: (get purpose template-data),
              data-types: (get data-types template-data),
              expires-at: expires-at,
              template-used: template-id
            })
          )
        )
      )
      ERR_TEMPLATE_NOT_FOUND
    )
  )
)