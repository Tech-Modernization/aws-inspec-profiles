class AwsVpcEndpoint< Inspec.resource(1)
  name 'aws_vpc_endpoint'
  desc 'Verifies settings for an AWS VPC Endpoint.'
  example "
    describe aws_vpc_endpoint(service_name: 'com.amazonaws.vpce.eu-west-2.vpce-svc-123456789', state: 'pending') do
      it { should exist }
    end
  "
  supports platform: 'aws'

  include AwsSingularResourceMixin
  attr_reader :vpc_endpoint_id, :vpc_endpoint_type, :vpc_id, :service_name, :state, :route_table_ids, :subnet_ids,                    :security_group_id, :security_group_name, :private_dns_enabled

  def to_s
    "AWS VPC Endpoint: #{service_name}"
  end

  private

  def validate_params(raw_params)
    validated_params = check_resource_param_names(
      raw_params: raw_params,
      allowed_params: [:service_name, :state],
      allowed_scalar_name: [:service_name, :state],
      allowed_scalar_type: Array
    )

    if validated_params.empty?
      raise ArgumentError, 'You must provide service_name and state to aws_vpc_endpoint.'
    end

    validated_params
  end

  def fetch_from_api
    backend = BackendFactory.create(inspec_runner)
    begin
      # return all vpc endpoints from the api
      describe_all = backend.describe_vpc_endpoints.vpc_endpoints

      # ensure the values for `service_name` and `state` match and exist
      init_lookup = describe_all.select { |vpce| vpce.service_name == @service_name && vpce.state == @state }.first

      # if `service_name` and `state` can't be matched, throw an error
      if init_lookup.nil?
        raise ArgumentError, "VPC Endpoint #{service_name} does not exist."
        @exists = false
      end

      # at this point, we can safely assume that the array we're targeting,
      # is the one we want.
      id_lookup = backend.describe_vpc_endpoints(vpc_endpoint_ids: [init_lookup.vpc_endpoint_id]).vpc_endpoints.first

      unless id_lookup.nil?
        @exists = true 
        unpack_describe_vpc_endpoints_response(id_lookup)
      end

    rescue Aws::EC2::Errors::ServiceError
      @exists = false
      populate_as_missing
    end
  end

  def unpack_describe_vpc_endpoints_response(vpce_struct)
    @vpc_endpoint_id = vpce_struct.vpc_endpoint_id
    @vpc_endpoint_type = vpce_struct.vpc_endpoint_type
    @vpc_id = vpce_struct.vpc_id
    @service_name = vpce_struct.service_name
    @state = vpce_struct.state
    @route_table_ids = vpce_struct.route_table_ids
    @subnet_ids = vpce_struct.subnet_ids
    @security_group_id = vpce_struct.groups.map { |group| group.group_id }
    @security_group_name = vpce_struct.groups.map { |group| group.group_name }
    @private_dns_enabled = vpce_struct.private_dns_enabled
  end

  def populate_as_missing
    @vpc_endpoint_id = nil
    @vpc_endpoint_type = nil
    @vpc_id = nil
    @service_name = nil
    @state = nil
    @route_table_ids = nil
    @subnet_ids = nil
    @group_id = nil
    @group_name = nil
    @private_dns_enabled = nil
  end

  class Backend
    class AwsClientApi < AwsBackendBase
      BackendFactory.set_default_backend(self)
      self.aws_client_class = Aws::EC2::Client
 
      def describe_vpc_endpoints(query = {})
        aws_service_client.describe_vpc_endpoints(query)
      end
    end
  end
end
