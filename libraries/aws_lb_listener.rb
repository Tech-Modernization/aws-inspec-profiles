class AwsLbListener < Inspec.resource(1)
  name 'aws_lb_listener'
  desc 'Verifies listener settings for AWS Elastic Load Balancer (V2). Supports ALBs and NLBs.'
  example "
    describe aws_lb_listener(lb_name: 'mynlb') do
      it { should exist }
    end
  "
  supports platform: 'aws'

  include AwsSingularResourceMixin
  attr_reader :listener_arn, :lb_arn, :protocol,
              :default_action_type, :default_action_target_group_arn,
              :lb_name, :listener_port

  def to_s
    "AWS Listener for Load Balancer: #{lb_name} (listener port: #{listener_port})"
  end

  private

  def validate_params(raw_params)
    validated_params = check_resource_param_names(
      raw_params: raw_params,
      allowed_params: [:lb_name, :listener_port],
      allowed_scalar_name: [:lb_name, :listener_port],
      allowed_scalar_type: Array
    )

    if validated_params.empty?
      raise ArgumentError, 'You must provide a lb_name to aws_lb_listener.'
    end

    validated_params
  end

  def fetch_from_api
    backend = BackendFactory.create(inspec_runner)
    begin
      lbs = backend.describe_load_balancers(names: [lb_name]).load_balancers
      
      first_lb = lbs.first
      lb_listeners = backend.describe_load_balancer_listeners(load_balancer_arn: first_lb.load_balancer_arn).listeners
      first_listener = lb_listeners.select {|listener| listener.port == @listener_port}.first
      
      if first_listener.nil?
        raise ArgumentError, "Listener with port #{listener_port} does not exist."
        @exists = false
      end
      unless first_listener.nil?
        @exists = true 
        # Load balancer names are unique; we will either have 0 or 1 result
        unpack_describe_lb_listener_response(first_listener)
      end

    rescue Aws::ElasticLoadBalancingV2::Errors::ServiceError
      @exists = false
      populate_as_missing
    end
  end

  def unpack_describe_lb_listener_response(lb_listener_struct)
    @listener_arn = lb_listener_struct.listener_arn
    @lb_arn = lb_listener_struct.load_balancer_arn
    @listener_port = lb_listener_struct.port
    @protocol = lb_listener_struct.protocol
    @default_action_type = lb_listener_struct.default_actions.map { |da| da.type }
    @default_action_target_group_arn = lb_listener_struct.default_actions.map { |da| da.target_group_arn }
  end

  def populate_as_missing
    @protocol = nil
    @default_action_type = nil
    @listener = nil
    @listener_port = nil
  end

  class Backend
    class AwsClientApi < AwsBackendBase
      BackendFactory.set_default_backend(self)
      self.aws_client_class = Aws::ElasticLoadBalancingV2::Client

      def describe_load_balancer_listeners(query = {})
        aws_service_client.describe_listeners(query)
      end

      def describe_load_balancers(query = {})
        aws_service_client.describe_load_balancers(query)
      end      
    end
  end
end
