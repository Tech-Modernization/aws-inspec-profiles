# inspec-resources

> NOTE: This repo is still under heavy development. If things don't work as expected, or you'd like to request a resource, please create an issue and tag @joshuatalb in it.

Inspec is fairly limited in its current capacity and can only test against a subset of AWS services. This repo aims to extend Inspec to support additional AWS services.

# File Structure

- `libraries` - This is where the custom resources are stored.
  - `libraries/aws_directory_service.rb` - AWS Directory Service
  - `libraries/aws_elb_v2.rb` - AWS Elastic Load Balancing (v2)
  - `libraries/aws_lb_listener.rb` - Listener support for ELBs
  - `libraries/aws_route53_zone.rb` - Route53 Zone
  - `libraries/aws_vpc_endpoint.rb` - VPC Endpoint

# Resources

The resources simply extend the [Ruby SDK for AWS](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/). It's a fairly trivial task to extend the resources as the AWS Documentation includes request and response examples. Resources in this repo should be considered `stable`, however have only been tested against certain scenarios (e.g testing for a single AD instance from Directory Service).

## aws_directory_service
**[API Reference: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DirectoryService.html](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DirectoryService.html)**

The AWS API doesn't support passing the name of the Directory Service instance, and forces you to pass the `directory_id` which we won't neccesarily know if we're running this in a pipeline as part of automated tests.

To get around this, this resource makes 2 API calls to AWS. First to "list" all directories attached to the target account, and the second which takes the values from the first call and returns the correct API object based on `name` and `short_name`. If the API can't match an instance to the `name` and `short_name` values, it will throw an error informing you that the Directory Service instance does not exist.

The following attributes are supported for testing:

- `name`
- `short_name`
- `size`
- `edition`
- `type`
- `stage`
- `description`
- `availability_zones`
- `desired_controller_count`

**Inspec Test Example:**

```
title 'Ensure Active Directory (Directory Service) exists'

describe aws_directory_service(name: 'ad.inspec.local', short_name: 'AD') do
  it { should exist }
  its('name') { should eq 'ad.inspec.local' }
  its('short_name') { should eq 'AD' }
  its('size') { should eq 'Small' }
  its('edition') { should eq 'Standard' }
  its('type') { should eq 'MicrosoftAD' }
  its('stage') { should eq 'Active' }
  its('description') { should eq 'Active Directory used for DEN.' }
  its('availability_zones') { should include 'eu-west-2a' }
  its('availability_zones') { should include 'eu-west-2b' }
  its('desired_controller_count') { should eq 2 }
end
```

## aws_elb_v2
**[API Reference: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/ElasticLoadBalancingV2.html](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/ElasticLoadBalancingV2.html)**

Testing for a load balancer is a trivial task, as the AWS API already supports looking up Load Balancers based on the `elb_v2_name`.

The following attributes are supported for testing:

- `availability_zones`
- `subnet_ids`
- `hosted_zone_id`
- `created_time`
- `dns_name`
- `elb_v2_arn`
- `elb_v2_name`
- `scheme`
- `security_group_ids`
- `state`
- `type`
- `vpc_id`
- `ip_type`

**Inspec Test Example:**

```
title 'Ensure Network Load Balancer (NLB) exists'

describe aws_elb_v2(elb_v2_name: 'ad-lb-tf') do
  it { should exist }
  its('scheme') { should eq 'internal' }
  its('type') { should eq 'network' }
  its('vpc_id') { should eq 'vpc-STRING-ID-HERE' }
  its('state') { should eq 'active' }
  its('availability_zones') { should include 'eu-west-2a' }
  its('availability_zones') { should include 'eu-west-2b' }
  its('ip_type') { should eq 'ipv4' }
end
```

## aws_lb_listener
**[API Reference: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/ElasticLoadBalancingV2.html](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/ElasticLoadBalancingV2.html)**

The AWS API doesn't support passing the name of the Load Balancer to discover the listeners, and forces you to pass the `load_balancer_arn` which we won't neccesarily know if we're running this in a pipeline as part of automated tests.

To get around this, this resource makes 2 API calls to AWS. First the resource takes the load balancer name that it's trying to target and makes an API call to AWS which results in an array for the targeted load balancer. We then take the ARN from that response, and pass it into another API call which "describes" the listeners for said load balancer. We're then able to take this array to pass back to Inspec to test against.

If the API can't match the load balancer name (`lb_name`) and a listener port (`listener_port`) to the AWS API response, it will throw an error informing you that the load balancer does not exist.

The following attributes are supported for testing:

- `listener_arn`
- `lb_arn`
- `listener_port`
- `protocol`
- `default_action_type`
- `default_action_target_group_arn`

**Inspec Test Example:**

```
title 'Ensure ELB is listening correctly'

describe aws_lb_listener(lb_name: 'ad-lb-tf', listener_port: 636) do
  it { should exist }
  its('protocol') { should eq 'TCP' }
  its('listener_port') { should eq 636 }
  its('default_action_type') { should include 'forward' }
end
```

## aws_route53_zone
**[API Reference: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Route53.html](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Route53.html)**

The AWS API doesn't support passing the name of the hosted zone to the API call, therefore you must pass it the Hosted Zone ID. This should be updated to use the name, similar to other AWS resources in this repo.

The following attributes are supported for testing:

- `zone_id`
- `zone_name`
- `private_zone`
- `record_count`

**Inspec Test Example**

```
title 'Ensure Route53 Hosted Zone exists'

describe aws_route53_zone(zone_id: 'Z1DEXAMPLEZONE') do
  it { should exist }
  its('zone_id') { should include 'Z1DEXAMPLEZONE' }
  its('zone_name') { should eq 'inspec.local.' }
  its('private_zone') { should eq true }
  its('record_count') { should eq 3 }
end
```
