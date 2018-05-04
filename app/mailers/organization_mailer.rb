class OrganizationMailer < ActionMailer::Base
  default from: Cartodb.get_config(:mailer, 'from')
  layout 'mail'

  def quota_limit_reached(organization)
    @organization = organization
    @subject = "Tu organización #{@organization.name} ha alcanzado el límite de cuota"
    @link = "mailto:support@agroviz.com"

    mail to: @organization.owner.email,
         subject: @subject
  end

  def invitation(invitation, email)
    @invitation = invitation

    @subject = "Te han invitado a formar parte de la organización #{@invitation.organization.name} en Agroviz"

    base_url = CartoDB.base_url(@invitation.organization.name)
    token = invitation.token(email)
    @invitation_signup_link = "#{base_url}#{CartoDB.path(self, 'signup', invitation_token: token, email: email)}"

    mail to: email, subject: @subject
  end

  def seat_limit_reached(organization)
    @organization = organization
    @subject = "Tu organización #{@organization.name} ha alcanzado el límite de usuarios"
    @link = "mailto:support@agroviz.com"

    mail to: @organization.owner.email,
         subject: @subject
  end

end
