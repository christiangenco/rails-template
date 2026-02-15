module ApplicationHelper
  include Pagy::Frontend
  include ButtonHelper
  include CopyHelper
  include UiHelper
  include TimeHelper
  
  def tailwind_form_for(record, **options, &block)
    options[:builder] = TailwindFormBuilder
    form_for(record, **options, &block)
  end
  
  def tailwind_form_with(**options, &block)
    options[:builder] = TailwindFormBuilder
    form_with(**options, &block)
  end
  
  def gravatar_url(email, size: 80)
    return nil if email.blank?
    
    hash = Digest::MD5.hexdigest(email.downcase.strip)
    "https://www.gravatar.com/avatar/#{hash}?s=#{size}&d=mp"
  end
  
  alias_method :gravatar_url_for, :gravatar_url
  
  def current_or_default_team
    # Will be implemented in Phase 6 with authentication
    Current.team || current_user&.default_team
  end
  
  def team_switch_path(team)
    # Will be implemented in Phase 6 with team switching
    switch_team_path(team)
  end
  
  def admin?
    # Will be implemented in Phase 13 with admin impersonation
    current_user&.admin?
  end
end
