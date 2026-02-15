module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end

    def require_unauthenticated_access(**options)
      before_action :redirect_authenticated_user, **options
    end
  end

  private

  def authenticated?
    resume_session
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    Current.session = find_session_by_cookie
  end

  def find_session_by_cookie
    if session_id = cookies.signed[:session_id]
      Session.find_by(id: session_id)
    end
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to new_session_path(email: params[:email])
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || default_authenticated_path
  end

  def default_authenticated_path
    root_path
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      track_sign_in(user)
    end
  end

  def track_sign_in(user)
    user.update!(
      sign_in_count: user.sign_in_count + 1,
      current_sign_in_at: Time.current,
      current_sign_in_ip: request.remote_ip,
      last_sign_in_at: user.current_sign_in_at,
      last_sign_in_ip: user.current_sign_in_ip
    )
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_id)
    Current.session = nil
  end

  def redirect_authenticated_user
    if resume_session
      redirect_to default_authenticated_path
    end
  end

  def redirect_to_session_magic_link(magic_link)
    set_pending_authentication_token(magic_link.user.email)
    
    if Rails.env.development?
      flash[:magic_link_code] = magic_link.code
      response.set_header("X-Magic-Link-Code", magic_link.code)
    end
    
    redirect_to session_magic_link_path
  end

  def redirect_to_fake_session_magic_link(email)
    set_pending_authentication_token(email)
    redirect_to session_magic_link_path
  end

  def set_pending_authentication_token(email)
    token = Rails.application.message_verifier(:pending_authentication).generate(email, expires_in: 15.minutes)
    cookies.signed[:pending_authentication] = { value: token, httponly: true, same_site: :lax }
  end

  def email_address_pending_authentication
    if token = cookies.signed[:pending_authentication]
      Rails.application.message_verifier(:pending_authentication).verify(token, purpose: nil)
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageExpired
    nil
  end

  def clear_pending_authentication_token
    cookies.delete(:pending_authentication)
  end
end
