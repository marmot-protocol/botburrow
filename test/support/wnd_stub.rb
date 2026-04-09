class WndStubInstance
  attr_reader :calls

  def initialize(config)
    @config = config
    @calls = config[:calls]
  end

  def create_identity
    record_call(:create_identity)
    maybe_raise(:create_identity)
    @config[:responses][:create_identity] || { "pubkey" => SecureRandom.hex(32) }
  end

  def keys_publish(account:)
    record_call(:keys_publish, account: account)
    maybe_raise(:keys_publish)
    @config[:responses][:keys_publish] || "ok"
  end

  def accounts_list
    record_call(:accounts_list)
    maybe_raise(:accounts_list)
    @config[:responses][:accounts_list] || []
  end

  def profile_update(account:, name: nil, display_name: nil, about: nil, picture: nil)
    record_call(:profile_update, account: account, name: name, about: about, picture: picture)
    maybe_raise(:profile_update)
    "ok"
  end

  def profile_show(account:)
    record_call(:profile_show, account: account)
    maybe_raise(:profile_show)
    @config[:responses][:profile_show] || { "name" => nil, "picture" => nil }
  end

  def daemon_status
    record_call(:daemon_status)
    maybe_raise(:daemon_status)
    @config[:responses][:daemon_status] || { "status" => "running" }
  end

  def users_show(pubkey:)
    record_call(:users_show, pubkey: pubkey)
    maybe_raise(:users_show)
    @config[:responses][:"users_show:#{pubkey}"] || @config[:responses][:users_show] || {}
  end

  def send_message(account:, group_id:, message:)
    record_call(:send_message, account: account, group_id: group_id, message: message)
    maybe_raise(:send_message)
    "ok"
  end

  def groups_list(account:)
    record_call(:groups_list, account: account)
    maybe_raise(:groups_list)
    @config[:responses][:groups_list] || []
  end

  def groups_invites(account:)
    record_call(:groups_invites, account: account)
    maybe_raise(:groups_invites)
    @config[:responses][:groups_invites] || []
  end

  def groups_accept(account:, group_id:)
    record_call(:groups_accept, account: account, group_id: group_id)
    maybe_raise(:groups_accept)
    "ok"
  end

  def groups_decline(account:, group_id:)
    record_call(:groups_decline, account: account, group_id: group_id)
    maybe_raise(:groups_decline)
    "ok"
  end

  private

  def record_call(method, **args)
    @calls << { method: method, args: args }
  end

  def maybe_raise(method)
    raise Wnd::ConnectionError, @config[:errors][method] if @config[:errors].key?(method)
  end
end

class WndStubFactory
  attr_reader :calls

  def initialize
    @calls = []
    @responses = {}
    @errors = {}
  end

  def stub_response(method, response)
    @responses[method] = response
    self
  end

  def stub_error(method, message)
    @errors[method] = message
    self
  end

  def new(**_kwargs)
    WndStubInstance.new(calls: @calls, responses: @responses, errors: @errors)
  end

  def called?(method)
    @calls.any? { |c| c[:method] == method }
  end

  def call_args(method)
    @calls.select { |c| c[:method] == method }.map { |c| c[:args] }
  end
end
