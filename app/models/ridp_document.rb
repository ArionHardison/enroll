class RidpDocument < Document

  RIDP_DOCUMENTS_VERIF_STATUS = ['not submitted', 'downloaded', 'verified', 'rejected']

  # admin action list for verification process, dropdown for each ridp verification type
  ADMIN_VERIFICATION_ACTIONS = ["Verify", "Reject"]

  # reasons admin can provide when verifying type
  VERIFICATION_REASONS = EnrollRegistry[:verification_reasons].item
  VERIFICATION_REASONS += EnrollRegistry[:non_applicant_verification_reason].item if EnrollRegistry.feature_enabled?(:non_applicant_verification_reason)

  # reasons admin can provide when returning for deficiency verification type
  RETURNING_FOR_DEF_REASONS = ["Illegible Document", "Member Data Change", "Document Expired", "Additional Document Required", "Other"]
  RETURNING_FOR_DEF_REASONS += ["Out of Income Threshold"] if EnrollRegistry.feature_enabled?("out_of_income_threshold_reject_reason")

  RIDP_DOCUMENT_KINDS = ['Driver License']

  field :status, type: String, default: "not submitted"

  # ridp verification type this document can support: Driver's License
  field :ridp_verification_type, default: "Identity"

  field :comment, type: String

  field :uploaded_at, type: Date

  scope :uploaded, ->{ where(identifier: {:$exists => true}) }
end
