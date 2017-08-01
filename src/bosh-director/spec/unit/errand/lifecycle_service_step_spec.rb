require 'spec_helper'

module Bosh::Director
  describe Errand::LifecycleServiceStep do
    subject(:errand_step) do
      Errand::LifecycleServiceStep.new(
        runner,
        errand_name,
        instance,
        logger
      )
    end

    let(:runner) { instance_double(Errand::Runner) }
    let(:errand_name) { 'errand_name' }
    let(:errand_result) { Errand::Result.new(exit_code, nil, nil, nil) }
    let(:instance) { instance_double(DeploymentPlan::Instance) }
    let(:exit_code) { 0 }

    describe '#prepare' do
      it 'does nothing' do
        expect(errand_step.prepare).to eq(nil)
      end
    end

    describe '#ignore_cancellation?' do
      it 'returns false' do
        expect(errand_step.ignore_cancellation?).to eq(false)
      end
    end

    describe '#run' do
      let(:checkpoint_block) { Proc.new {} }

      it 'returns the result string' do
        expect(runner).to receive(:run).with(instance, &checkpoint_block).
          and_return(errand_result)
        result = errand_step.run(&checkpoint_block)
        expect(result).to eq("Errand 'errand_name' completed successfully (exit code 0)")
      end
    end
  end
end
