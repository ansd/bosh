require_relative '../../spec_helper'

describe 'run release job errand', type: :integration, with_tmp_dir: true do
  let(:deployment_name) { manifest_hash['name'] }

  with_reset_sandbox_before_each

  context 'when running errands on service instances' do
    let(:manifest_hash) { Bosh::Spec::Deployments.manifest_with_errand_job_on_service_instance }

    it 'runs the errand referenced by the job name on a service lifecycle instance' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand errand1', deployment_name: deployment_name)

      expect(output).to match /fake-errand-stdout-service/
      expect(output).to match /Succeeded/
    end

    it 'runs the errand referenced by the job name on multiple service lifecycle instances' do
      manifest_hash['jobs'][0]['instances'] = 2

      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand errand1', deployment_name: deployment_name)

      expect(output).to match /job=service_with_errand index=0/
      expect(output).to match /job=service_with_errand index=1/
      expect(output.scan('fake-errand-stdout-service').size).to eq(2)
      expect(output.scan('stdout-from-errand1-package').size).to eq(2)

      expect(output).to match /Succeeded/
    end
  end

  context 'when there are multiple errand jobs on the instance group' do
    let(:manifest_hash) do
      hash = Bosh::Spec::Deployments.manifest_with_errand_job_on_service_instance
      hash['jobs'][0]['templates'] << emoji_errand_job
      hash
    end

    let(:emoji_errand_job) { {'release' => 'bosh-release', 'name' => 'emoji-errand'} }

    it 'is able to run the first errand' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand errand1', deployment_name: deployment_name)

      expect(output).to match /job=service_with_errand index=0/
      expect(output.scan(/fake-errand-stdout-service/).size).to eq(1)
    end

    it 'is able to run the second errand' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand emoji-errand', deployment_name: deployment_name)

      expect(output.scan(/errand is/).size).to eq(1)
    end
  end

  context 'when lifecycle service instance groups and lifecycle errand instance groups have the errand job' do
    let(:manifest_hash) do
      hash = Bosh::Spec::Deployments.manifest_with_errand
      hash['jobs'] << service_instance_group_with_errand
      hash['jobs'] << second_service_instance_group_with_errand
      hash
    end

    let(:service_instance_group_with_errand) do
      instance_group = Bosh::Spec::Deployments.service_job_with_errand
      instance_group['instances'] = 2
      instance_group
    end

    let(:second_service_instance_group_with_errand) do
      instance_group = Bosh::Spec::Deployments.service_job_with_errand
      instance_group['name'] = 'second_service_with_errand'
      instance_group
    end

    it 'runs the errand on all instances' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand errand1', deployment_name: deployment_name)

      expect(output).to match /job=service_with_errand index=0/
      expect(output).to match /job=service_with_errand index=1/
      expect(output).to match /job=second_service_with_errand index=0/
      expect(output).to match /job=fake-errand-name index=0/
      expect(output.scan(/fake-errand-stdout-service/).size).to eq(3)
      expect(output.scan(/fake-errand-stdout[^\-]/).size).to eq(1)

      expect(output).to match /Succeeded/
    end
  end

  context 'when starting a vm for an errand lifecycle group fails' do
    let(:manifest_hash) do
      hash = Bosh::Spec::Deployments.manifest_with_errand_job_on_service_instance
      hash['jobs'] << Bosh::Spec::Deployments.simple_errand_job
      hash
    end

    it 'does not run the errand on service instances' do
      deploy_from_scratch(manifest_hash: manifest_hash)
      current_sandbox.cpi.commands.make_create_vm_always_fail

      output = bosh_runner.run('run-errand errand1', deployment_name: deployment_name, failure_expected: true)
      expect(output).to_not match /Running errand: service_with_errand/
      expect(output).to match /Creating vm failed/
    end
  end

  context 'when filtering to a particular set of instances' do
    let(:manifest_hash) do
      hash = Bosh::Spec::Deployments.manifest_with_errand
      hash['jobs'] << service_instance_group_with_errand
      hash['jobs'] << second_service_instance_group_with_errand
      hash
    end

    let(:service_instance_group_with_errand) do
      instance_group = Bosh::Spec::Deployments.service_job_with_errand
      instance_group['instances'] = 2
      instance_group
    end

    let(:second_service_instance_group_with_errand) do
      instance_group = Bosh::Spec::Deployments.service_job_with_errand
      instance_group['instances'] = 2
      instance_group['name'] = 'second_service_with_errand'
      instance_group
    end

    it 'runs all in an instance group' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand errand1 --instance second_service_with_errand', deployment_name: deployment_name)

      expect(output).to match /job=second_service_with_errand index=0/
      expect(output).to match /job=second_service_with_errand index=1/

      expect(output).to_not match /job=service_with_errand/
      expect(output).to_not match /job=fake-errand-name/
    end

    it 'runs on specific instances' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand errand1 --instance second_service_with_errand/0 --instance service_with_errand/1', deployment_name: deployment_name)

      expect(output).to match /job=service_with_errand index=1/
      expect(output).to match /job=second_service_with_errand index=0/

      expect(output).to_not match /job=service_with_errand index=0/
      expect(output).to_not match /job=second_service_with_errand index=1/
      expect(output).to_not match /job=fake-errand-name/
    end
  end
end
