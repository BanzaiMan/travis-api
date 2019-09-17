require 'uri'
require 'closeio'

module Travis::API::V3
  class Services::Lead::Create < Service
    result_type :lead
    params :name, :email, :team_size, :phone, :message, :utm_source

    def run!
      # Get params
      name, email, team_size, phone, message, utm_source = params.values_at('name', 'email', 'team_size', 'phone', 'message', 'utm_source')
      team_size = team_size.to_i unless team_size.nil?
      name = name.strip unless name.nil?
      message = message.strip unless message.nil?

      # Validation
      raise WrongParams, 'missing name' unless name && name.length > 0
      raise WrongParams, 'invalid email' unless email && email.length > 0 && email.match(URI::MailTo::EMAIL_REGEXP).present?
      raise WrongParams, 'missing message' unless message && message.length > 0
      raise WrongParams, 'invalid team size' if team_size && team_size <= 0

      # Prep data for request
      api_client = Closeio::Client.new(Travis.config.closeio.key)
      custom_fields = api_client.list_custom_fields
      team_size_field = custom_fields['data'].find { |field| field['name'] == 'team_size' }
      utm_source_field = custom_fields['data'].find { |field| field['name'] == 'utm_source' }

      phones = []
      phones.push({ type: "office", phone: phone }) unless phone.nil?

      lead_data = {
        name: name,
        "custom.#{utm_source_field['id']}": utm_source || 'Travis API',
        contacts: [{
          name: name,
          emails: [{ type: "office", email: email }],
          phones: phones
        }]
      }

      lead_data["custom.#{team_size_field['id']}"] = team_size if team_size

      # Send request
      lead = api_client.create_lead(lead_data)
      note = api_client.create_note({ lead_id: lead['id'], note: message })

      # Return result
      model = Travis::API::V3::Models::Lead.new(lead)
      result model
    end
  end
end