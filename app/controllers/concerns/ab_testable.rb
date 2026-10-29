module AbTestable
  extend ActiveSupport::Concern

  # Usage in a controller:
  #   @variant = ab_test("pricing_v2", :control, :new_layout)
  #
  # Returns one of the variant names (a Symbol).
  # Assignment is sticky per user (or session if logged out).
  # Reports the assignment to analytics automatically.
  def ab_test(experiment, *variants)
    variants = [ :control, :treatment ] if variants.empty?

    # Sticky assignment: hash user/session + experiment name
    seed = Digest::SHA256.hexdigest("#{experiment}-#{current_user&.id || session.id}")
    variant = variants[seed.hex % variants.size]

    # Only report assignment once per session per experiment
    session_key = "ab_#{experiment}"
    unless session[session_key]
      session[session_key] = variant.to_s
      track("ab_assignment", experiment: experiment, variant: variant)
    end

    variant
  end

  # Call this when the user completes the goal for an experiment:
  #   ab_convert("pricing_v2")
  def ab_convert(experiment)
    variant = session["ab_#{experiment}"]
    return unless variant

    track("ab_conversion", experiment: experiment, variant: variant)
  end
end
