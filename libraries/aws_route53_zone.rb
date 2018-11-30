class AwsRoute53Zone < Inspec.resource(1)
  name 'aws_route53_zone'
  desc 'Verifies settings for AWS Route53 Hosted Zone'
  example "
    describe aws_route53_zone('Z3M3LMPEXAMPLE') do
      it { should exist }
    end
  "
  supports platform: 'aws'

  include AwsSingularResourceMixin
  attr_reader :zone_id, :zone_name, :private_zone, :record_count

  def to_s
    "AWS Route53 Hosted Zone #{zone_id}"
  end

  private

  def validate_params(raw_params)
    validated_params = check_resource_param_names(
      raw_params: raw_params,
      allowed_params: [:zone_id],
      allowed_scalar_name: :zone_id,
      allowed_scalar_type: String,
    )

    if validated_params.empty?
      raise ArgumentError, 'You must provide a zone_id to aws_route53_zone.'
    end

    validated_params
  end

  def fetch_from_api
    backend = BackendFactory.create(inspec_runner)
    begin
      r53_zone = backend.get_hosted_zone(id: zone_id)
      @exists = true
      # Hosted Zone IDs are unique; we will either have 0 or 1 result
      unpack_get_r53_zone_response(r53_zone)
    rescue Aws::Route53::Errors::HostedZoneNotFound
      @exists = false
      populate_as_missing
    end
  end

  def unpack_get_r53_zone_response(r53_struct)
    @zone_id = r53_struct.hosted_zone.id
    @zone_name = r53_struct.hosted_zone.name
    @private_zone = r53_struct.hosted_zone.config.private_zone
    @record_count = r53_struct.hosted_zone.resource_record_set_count


    # @availability_zones = r53_struct.availability_zones.map { |az| az.zone_name }
    # @subnet_ids = r53_struct.availability_zones.map { |az| az.subnet_id }
    # @zone_id = r53_struct.canonical_hosted_zone_id
    # @record_count = r53_struct.hosted_zone.resource_record_set_count
  end

  def populate_as_missing
    # @availability_zones = []
    # @hosted_zone_id = []
    # @security_group_ids = []
    # @subnet_ids = []
  end

  class Backend
    class AwsClientApi < AwsBackendBase
      BackendFactory.set_default_backend(self)
      self.aws_client_class = Aws::Route53::Client

      def get_hosted_zone(query = {})
        aws_service_client.get_hosted_zone(query)
      end
    end
  end
end
