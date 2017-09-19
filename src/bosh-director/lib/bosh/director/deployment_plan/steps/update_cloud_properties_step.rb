module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateCloudPropertiesStep
        def initialize(logger, deployment_plan)
          @logger = logger
          @deployment_plan = deployment_plan
        end

        def perform
          cloud_factory = CloudFactory.create_with_latest_configs(@deployment_plan.model)

          cpi_and_vm_block_to_cloud_properties = {}
          @deployment_plan.instance_groups_starting_on_deploy.each do |instance_group|
            next if instance_group.instances.nil?
            instance_group.instances.each do |instance|
              cpi_name = cloud_factory.get_name_for_az(instance.availability_zone)
              vm_block = instance.spec['vm']
              if cpi_and_vm_block_to_cloud_properties[{cpi_name => vm_block}].nil?
                desired_instance_size = {'desired_instance_size' => vm_block}
                vm_cloud_properties = factory.get(cpi_name).calculate_vm_cloud_properties(desired_instance_size)
                cpi_and_vm_block_to_cloud_properties[{cpi_name => vm_block}] = vm_cloud_properties
                instance.cloud_properties = vm_cloud_properties
              end
            end
          end



          az_to_vm_blocks = {}

          # cloud_config = @deployment_plan.model.cloud_config
          # cloud_config['azs'].each do |az|
          #   if az['cpi']
          #     cpi_to_vm_blocks[{az['name'] => az['cpi']}] =
          #   end
          # end

          @deployment_plan.instance_groups_starting_on_deploy.each do |instance_group|
            next if instance_group.instances.nil?
            instance_group.instances.each do |instance|
              vm_block = instance.spec['vm']
              if vm_block
                if az_to_vm_blocks[instance.availability_zone].nil?
                  az_to_vm_blocks[instance.availability_zone] = Set.new
                end
                az_to_vm_blocks[instance.availability_zone].add(vm_block)
              end
            end
          end

          cpi_to_cloud_mappings = {}
          az_to_vm_blocks.each do |az, vm_blocks|
            cpi_name = cloud_factory.get_name_for_az(az)
            if cpi_to_cloud_mappings[cpi_name]
              cpi_to_cloud_mappings[cpi_name].add(vm_blocks)
            else
              cpi_to_cloud_mappings[cpi_name] = Set.new(vm_blocks)
            end
          end

          cpi_to_cloud_mappings.each do |cpi, vm_blocks|
            vm_blocks.each do |vm_block|
              desired_instance_size = {'desired_instance_size' => vm_block['vm']}
              vm_cloud_properties = factory.get(cpi).calculate_vm_cloud_properties(desired_instance_size)
              cpi_to_cloud_mappings
            end
          end

        end
      end
    end
  end
end
