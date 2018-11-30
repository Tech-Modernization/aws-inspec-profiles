class AwsNlbListener < Inspec.resource(1)
  name 'aws_nlb_listener'
  desc 'Verifies listener settings for AWS Network Load Balancer'
  example "
    describe aws_nlb_listener(lb_arn: 'mynlb') do
      it { should exist }
    end
  "
  supports platform: 'aws'

  include AwsSingularResourceMixin
  attr_reader :listener_arn, :lb_arn, :port, :protocol,
              :default_action_type, :default_action_target_group_arn

  def to_s
    "AWS NLB Listener #{lb_arn}"
  end

  private

  def validate_params(raw_params)
    validated_params = check_resource_param_names(
      raw_params: raw_params,
      allowed_params: [:lb_arn],
      allowed_scalar_name: :lb_arn,
      allowed_scalar_type: String,
    )

    if validated_params.empty?
      raise ArgumentError, 'You must provide a lb_arn to aws_nlb_listener.'
    end

    validated_params
  end

  def fetch_from_api
    backend = BackendFactory.create(inspec_runner)
    begin
      lb_listeners = backend.describe_load_balancer_listeners(load_balancer_arn: lb_arn).listeners
      @exists = true
      # Load balancer names are unique; we will either have 0 or 1 result
      unpack_describe_lb_listeners_response(lb_listeners.first)
    rescue Aws::ElasticLoadBalancingV2::Errors::LoadBalancerNotFound
      @exists = false
      populate_as_missing
    end
  end

  def unpack_describe_lb_listeners_response(lb_listener_struct)
    @listener_arn = lb_listener_struct.listener_arn
    @lb_arn = lb_listener_struct.load_balancer_arn
    @port = lb_listener_struct.port
    @protocol = lb_listener_struct.protocol
    @default_action_type = lb_listener_struct.default_actions.map { |da| da.type }
    @default_action_target_group_arn = lb_listener_struct.default_actions.map { |da| da.target_group_arn }
  end

  def populate_as_missing
    @availability_zones = []
    @hosted_zone_id = []
    @security_group_ids = []
    @subnet_ids = []
  end

  class Backend
    class AwsClientApi < AwsBackendBase
      BackendFactory.set_default_backend(self)
      self.aws_client_class = Aws::ElasticLoadBalancingV2::Client

      def describe_load_balancer_listeners(query = {})
        aws_service_client.describe_listeners(query)
      end
    end
  end
end
