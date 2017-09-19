require 'spec_helper'

module Bosh::Director
  module DeploymentPlan::Steps
    describe UpdateCloudPropertiesStep do
      subject do
        deployment_assembler.bind_models
        described_class.new(base_job.logger, deployment_plan)
      end
      let(:base_job) { Bosh::Director::Jobs::BaseJob.new }

      let!(:variable_set) { Models::VariableSet.make(deployment: deployment_model) }
      let(:deployment_model) { Models::Deployment.make(name: 'fake-deployment', manifest: YAML.dump(deployment_manifest), cloud_config: cloud_config) }
      let(:deployment_plan) do
        planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(logger)
        deployment_plan = planner_factory.create_from_model(deployment_model)

        agent_client = instance_double('Bosh::Director::AgentClient')
        allow(BD::AgentClient).to receive(:with_agent_id).and_return(agent_client)
        allow(agent_client).to receive(:get_state).and_return({'agent-state' => 'yes'})

        deployment_plan
      end

      let (:deployment_assembler) { DeploymentPlan::Assembler.create(deployment_plan) }

      let!(:stemcell) { Models::Stemcell.make(name: 'ubuntu-stemcell', version: '1') }
      let!(:cloud_config) {
        raw_manifest = Bosh::Spec::Deployments.simple_cloud_config_with_multiple_azs.merge({
          'azs' => [
            {
              'name' => 'z1',
              'cpi' => 'cpi-name1',
            },
            {
              'name' => 'z2',
              'cpi' => 'cpi-name2',
            },
          ],
        })
        raw_manifest.delete('resource_pools')

        Models::CloudConfig.make(raw_manifest: raw_manifest)
      }
      let!(:cpi_config) { Models::CpiConfig.make }
      let(:deployment_manifest) do
        {
          'name' => 'fake-deployment',
          'releases' => [],
          'instance_groups' => [
            {
              'name' => 'fake-instance-group',
              'jobs' => [],
              'azs' => ['z1','z2'],
              'vm' => {
                'cpu' => 2,
                'ram' => 1024,
                'ephemeral_disk' => 2048
              },
              'instances' => 2,
              'networks' => [{'name' => 'a'}],
              'stemcell' => 'ubuntu-stemcell'
            }
          ],
          'update' => {
            'canaries' => 1,
            'max_in_flight' => 1,
            'canary_watch_time' => 1,
            'update_watch_time' => 1,
          },
          'stemcells' => [{
            'alias' => 'ubuntu-stemcell',
            'name' => 'ubuntu-stemcell',
            'version' => '1',
          }]
        }
      end

      before do
        Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))

        allow(base_job).to receive(:task_id).and_return(1)
        allow(Bosh::Director::Config).to receive(:current_job).and_return(base_job)
      end

      describe '#perform' do
        context 'with instances in the deployment' do
          let(:instance1) {
            Models::Instance.make(deployment: deployment_model, job: 'fake-instance-group', index: 0, availability_zone: 'z1', variable_set: variable_set)
          }
          let(:instance2) {
            Models::Instance.make(deployment: deployment_model, job: 'fake-instance-group', index: 1, availability_zone: 'z2', variable_set: variable_set)
          }

          it "calls the 'calculate_vm_cloud_properties' for every CPI exactly once" do

            expect_any_instance_of(Bosh::Clouds::ExternalCpi).to receive(:calculate_vm_cloud_properties)
            subject.perform

          end

          it "calls the 'calculate_vm_cloud_properties' for every CPI and vm block exactly once" do

            subject.perform

          end

          it 'sets the right flavor into the instance cloud properties' do
            subject.perform
            expect(Models::Instance.first.cloud_properties).to eq('cpi-new')
          end

        end
      end
    end
  end
end
