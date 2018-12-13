class AwsDirectoryService< Inspec.resource(1)
  name 'aws_directory_service'
  desc 'Verifies settings for AWS Directory Service'
  example "
    describe aws_directory_service(name: 'ad.randomdomain.net', short_name: 'AD') do
      it { should exist }
      its('type') { should eq 'MicrosoftAD' }
    end
  "
  supports platform: 'aws'

  include AwsSingularResourceMixin
  attr_reader :directory_id, :name, :short_name, :size,
              :edition, :type, :stage, :description,
              :availability_zones, :desired_controller_count

  def to_s
    "AWS Directory Service: #{name}"
  end

  private

  def validate_params(raw_params)
    validated_params = check_resource_param_names(
      raw_params: raw_params,
      allowed_params: [:name, :short_name],
      allowed_scalar_name: [:name, :short_name],
      allowed_scalar_type: Array
    )

    if validated_params.empty?
      raise ArgumentError, 'You must provide a name to aws_directory_service.'
    end

    validated_params
  end

  def fetch_from_api
    backend = BackendFactory.create(inspec_runner)
    begin
      # return all directories from the api
      describe_all = backend.describe_directories.directory_descriptions

      # ensure the values for `name` and `short_name` match and exist
      init_lookup = describe_all.select { |dsvc| dsvc.name == @name && dsvc.short_name == @short_name }.first

      # if `name` and `short_name` can't be matched, throw an error
      if init_lookup.nil?
        raise ArgumentError, "Directory Service #{name} does not exist."
        @exists = false
      end

      # at this point, we can safely assume that the array we're targeting,
      # is the one we want.
      id_lookup = backend.describe_directories(directory_ids: [init_lookup.directory_id]).directory_descriptions.first

      unless id_lookup.nil?
        @exists = true 
        unpack_describe_directories_response(id_lookup)
      end

    rescue Aws::DirectoryService::Errors::ServiceError
      @exists = false
      populate_as_missing
    end
  end

  def unpack_describe_directories_response(ds_struct)
    @directory_id = ds_struct.directory_id
    @name = ds_struct.name
    @short_name = ds_struct.short_name
    @size = ds_struct.size
    @edition = ds_struct.edition
    @stage = ds_struct.stage
    @type = ds_struct.type
    @description = ds_struct.description
    @availability_zones = ds_struct.vpc_settings.availability_zones
    @desired_controller_count = ds_struct.desired_number_of_domain_controllers
  end

  def populate_as_missing
    @directory_id = nil
    @name = nil
    @short_name = nil
    @size = nil
    @edition = nil
    @stage = nil
    @type = nil
    @description = nil
    @availability_zones = nil
    @desired_controller_count = nil
  end

  class Backend
    class AwsClientApi < AwsBackendBase
      BackendFactory.set_default_backend(self)
      self.aws_client_class = Aws::DirectoryService::Client
 
      def describe_directories(query = {})
        aws_service_client.describe_directories(query)
      end
    end
  end
end
