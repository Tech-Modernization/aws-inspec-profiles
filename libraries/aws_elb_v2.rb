class AwsElbV2 < Inspec.resource(1)
  name 'aws_elb_v2'
  desc 'Verifies settings for AWS Elastic Load Balancer (v2). This only supports ALBs and NLBs.'
  example "
    describe aws_elb_v2('mynlb') do
      it { should exist }
    end
  "
  supports platform: 'aws'

  include AwsSingularResourceMixin
  attr_reader :availability_zones, :hosted_zone_id, :created_time,
              :dns_name, :elb_v2_arn, :elb_v2_name, :scheme,
              :security_group_ids, :subnet_ids, :state, :type, :vpc_id, :ip_type

  def to_s
    "AWS Elastic Load Balancer (v2): #{elb_v2_name}"
  end

  private

  def validate_params(raw_params)
    validated_params = check_resource_param_names(
      raw_params: raw_params,
      allowed_params: [:elb_v2_name],
      allowed_scalar_name: :elb_v2_name,
      allowed_scalar_type: String,
    )

    if validated_params.empty?
      raise ArgumentError, 'You must provide a elb_v2_name to aws_elb_v2.'
    end

    validated_params
  end

  def fetch_from_api
    backend = BackendFactory.create(inspec_runner)
    begin
      lbs = backend.describe_load_balancers(names: [elb_v2_name]).load_balancers
      @exists = true
      # Load balancer names are unique; we will either have 0 or 1 result
      unpack_describe_nlbs_response(lbs.first)
    rescue Aws::ElasticLoadBalancingV2::Errors::LoadBalancerNotFound
      @exists = false
      populate_as_missing
    end
  end

  def unpack_describe_nlbs_response(lb_struct)
    @availability_zones = lb_struct.availability_zones.map { |az| az.zone_name }
    @subnet_ids = lb_struct.availability_zones.map { |az| az.subnet_id }
    @hosted_zone_id = lb_struct.canonical_hosted_zone_id
    @created_time = lb_struct.created_time
    @dns_name = lb_struct.dns_name
    @elb_v2_arn = lb_struct.load_balancer_arn
    @elb_v2_name = lb_struct.load_balancer_name
    @scheme = lb_struct.scheme
    @security_group_ids = lb_struct.security_groups
    @state = lb_struct.state.code
    @type = lb_struct.type
    @vpc_id = lb_struct.vpc_id
    @ip_type = lb_struct.ip_address_type
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

      def describe_load_balancers(query = {})
        aws_service_client.describe_load_balancers(query)
      end
    end
  end
end
